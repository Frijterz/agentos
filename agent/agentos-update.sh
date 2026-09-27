# agentos-update [run [--force] | adopt]: weekly system updates, prepared in the
# background. Packaged by modules/nixos/agent.nix; run daily by agentos-update.timer.
#
# run:   at most weekly (or --force, or when the prepared update is outdated): in a
#        separate git worktree, `nix flake update`, build the system, commit flake.lock
#        on the agentos-update branch, have Claude (no tools) summarise the package
#        diff, write update.json for the panel and send a notification. Your own
#        working tree is never touched. Held back (with a notification) if it brings
#        Hyprland 0.57+ while config/hypr is still hyprland.conf.
# adopt: after the panel applied the update, fast-forward the repo to that commit.

repo="${AGENTOS_FLAKE:-$HOME/agentos}"
# The service sets AGENTOS_HOST; by hand, the hostname is the flake's host name.
host="${AGENTOS_HOST:-$(uname -n)}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/agentos"
tree="${XDG_CACHE_HOME:-$HOME/.cache}/agentos/update-tree"
info="$state/update.json"
branch=agentos-update
mkdir -p "$state" "$(dirname "$tree")"

adopt() {
  base="$(jq -r .base "$info")"
  [ "$(git -C "$repo" rev-parse HEAD)" = "$base" ] ||
    { echo "The repo moved on since this update was built; not merging flake.lock." >&2; exit 1; }
  git -C "$repo" merge --ff-only "$branch"
  echo "flake.lock updated and committed on main (not pushed)."
}

run() {
  force="${1:-}"
  head="$(git -C "$repo" rev-parse HEAD)"

  # Weekly: skip if checked in the last 6 days, unless a prepared update is outdated
  # (built on an older repo commit, so applying it would undo your newer changes).
  stamp="$state/update-checked"
  if [ "$force" != --force ] && [ -n "$(find "$stamp" -mtime -6 2>/dev/null)" ] &&
    { [ ! -f "$info" ] || [ "$(jq -r .base "$info")" = "$head" ]; }; then
    echo "agentos-update: checked recently and nothing is outdated; skipping."
    exit 0
  fi

  git -C "$repo" worktree remove --force "$tree" 2>/dev/null || true
  git -C "$repo" worktree prune
  git -C "$repo" worktree add --force -B "$branch" "$tree" "$head"

  nix flake update --flake "$tree"
  if git -C "$tree" diff --quiet -- flake.lock; then
    echo "agentos-update: all inputs already up to date."
    rm -f "$info"
    touch "$stamp"
    exit 0
  fi
  git -C "$tree" commit -q -m "flake.lock: weekly update" -- flake.lock

  # Hyprland 0.57 drops the .conf config format. While the repo still has
  # config/hypr/hyprland.conf (not yet moved to Lua), hold the whole update back:
  # applying it would leave Hyprland without your settings and key bindings.
  hypr="$(nix eval --raw "$tree#nixosConfigurations.$host.config.programs.hyprland.package.version")"
  if [ -f "$tree/config/hypr/hyprland.conf" ] &&
    [ "$(printf '%s\n0.57\n' "$hypr" | sort -V | head -n 1)" = 0.57 ]; then
    echo "agentos-update: held back: Hyprland $hypr needs the Lua config first."
    rm -f "$info"
    touch "$stamp"
    notify-send -a agentos "System update held back" \
      "It brings Hyprland $hypr, which no longer reads hyprland.conf. Move the config to Lua first (ask Claude)." || true
    agentos-log note update "Weekly update held back: Hyprland $hypr needs the Lua config first" || true
    exit 0
  fi

  nix build "$tree#nixosConfigurations.$host.config.system.build.toplevel" --out-link "$tree/result"
  path="$(readlink -f "$tree/result")"
  # New inputs can still give the very same system (nothing that we use changed).
  if [ "$path" = "$(readlink -f /run/current-system)" ]; then
    echo "agentos-update: inputs moved, but the system is identical; nothing to apply."
    rm -f "$info"
    touch "$stamp"
    exit 0
  fi
  diff="$(nvd diff /run/current-system "$path" | tail -n +3)"

  # Tool-less Claude: it only sees the package list (stdin). The prompt must come
  # before --disallowedTools, which takes a list and would swallow it. Run outside the
  # repo so it doesn't load CLAUDE.md. Optional: the update works without a summary.
  summary="$(cd "$state" && printf '%s\n' "$diff" | timeout 180 claude -p \
    "Stdin is the nvd package diff of a weekly NixOS update for a Zenbook running Hyprland and Quickshell. Summarise it for the owner in at most 5 short bullets: notable version bumps (kernel, Hyprland, Quickshell, Mesa, firmware, Claude Code), anything that might need attention after the switch. Plain text, no preamble." \
    --disallowedTools '*' || true)"

  jq -n --arg path "$path" --arg hash "$(basename "$path" | cut -c 1-32)" --arg base "$head" \
    --arg diff "$diff" --arg summary "$summary" --arg date "$(date -I)" \
    '{path: $path, hash: $hash, base: $base, diff: $diff, summary: $summary, date: $date}' >"$info.tmp"
  mv "$info.tmp" "$info"
  touch "$stamp"

  notify-send -a agentos "System update ready" "Open the Claude panel (Super+A) to review and apply it." || true
  agentos-log note update "Weekly update prepared ($(printf '%s\n' "$diff" | grep -c '^\[' || true) package changes), waiting to be applied" || true
}

case "${1:-run}" in
  run) run "${2:-}" ;;
  adopt) adopt ;;
  *)
    echo "usage: agentos-update [run [--force] | adopt]" >&2
    exit 2
    ;;
esac
