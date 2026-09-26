# agentos-pending: is there a built but not yet applied system? Used by the Claude
# panel to offer "Apply". Prints one JSON object, or nothing if there is no such build.
# Packaged by modules/nixos/agent.nix.

repo="${AGENTOS_FLAKE:-$HOME/agentos}"

result="$(readlink -f "$repo/result" 2>/dev/null)" || exit 0
current="$(readlink -f /run/current-system)"
[ "$result" != "$current" ] || exit 0
case "$result" in
  /nix/store/*-nixos-system-*) ;;
  *) exit 0 ;;
esac

hash="$(basename "$result" | cut -c 1-32)"
# nvd's first two lines repeat the paths.
diff="$(nvd diff "$current" "$result" 2>&1 | tail -n +3 | head -n 40)"
changes="$(git -C "$repo" status --short 2>&1 | head -n 20)"
unpushed="$(git -C "$repo" log --oneline '@{upstream}..HEAD' 2>/dev/null | head -n 10 || true)"

jq -nc --arg path "$result" --arg hash "$hash" --arg diff "$diff" \
  --arg changes "$changes" --arg unpushed "$unpushed" \
  '{path: $path, hash: $hash, diff: $diff, changes: $changes, unpushed: $unpushed}'
