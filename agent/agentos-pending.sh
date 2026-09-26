# agentos-pending: built but not yet applied systems, for the Claude panel's Apply
# cards. Prints one JSON object per line (or nothing):
#   kind "build":  ~/agentos/result, from `nh os build` (you or Claude)
#   kind "update": the weekly update prepared by agentos-update; "stale" when the repo
#                  has moved on since, so applying it would undo newer changes.
# Packaged by modules/nixos/agent.nix.

repo="${AGENTOS_FLAKE:-$HOME/agentos}"
info="${XDG_STATE_HOME:-$HOME/.local/state}/agentos/update.json"
current="$(readlink -f /run/current-system)"

# nvd's first two lines repeat the paths.
pkgdiff() { nvd diff "$current" "$1" 2>&1 | tail -n +3 | head -n 40; }

result="$(readlink -f "$repo/result" 2>/dev/null || true)"
case "$result" in
  "$current" | "") ;;
  /nix/store/*-nixos-system-*)
    changes="$(git -C "$repo" status --short 2>&1 | head -n 20)"
    unpushed="$(git -C "$repo" log --oneline '@{upstream}..HEAD' 2>/dev/null | head -n 10 || true)"
    jq -nc --arg path "$result" --arg hash "$(basename "$result" | cut -c 1-32)" \
      --arg diff "$(pkgdiff "$result")" --arg changes "$changes" --arg unpushed "$unpushed" \
      '{kind: "build", path: $path, hash: $hash, diff: $diff, changes: $changes, unpushed: $unpushed}'
    ;;
esac

if [ -f "$info" ]; then
  path="$(jq -r .path "$info")"
  if [ "$path" != "$current" ] && [ -e "$path" ]; then
    head="$(git -C "$repo" rev-parse HEAD)"
    jq -c --arg diff "$(pkgdiff "$path")" --argjson stale "$([ "$(jq -r .base "$info")" = "$head" ] && echo false || echo true)" \
      '{kind: "update", path, hash, date, summary, diff: $diff, stale: $stale}' "$info"
  fi
fi
