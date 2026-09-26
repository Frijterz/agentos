# agentos-ask "<question>": ask Claude from the desktop (used by the Claude panel).
# Packaged by modules/nixos/agent.nix (writeShellApplication adds the shebang and
# `set -euo pipefail`).
#
# Phase 1 is read-only: Claude runs inside the agentos repo (so it follows CLAUDE.md)
# with tools that can look but not change anything. Tools not listed are denied.

prompt="${1:?usage: agentos-ask \"<question>\"}"
repo="${AGENTOS_FLAKE:-$HOME/agentos}"

context="$(
  printf 'Desktop context (from agentos-ask):\n'
  printf -- '- Active window: %s\n' "$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.class) - \(.title)"' || echo unknown)"
  printf -- '- Active workspace: %s\n' "$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo unknown)"
  printf -- '- Current system generation: %s\n' "$(readlink /nix/var/nix/profiles/system || echo unknown)"
  printf 'You are answering in a small desktop side panel: be concise, use short Markdown.\n'
  printf 'You cannot change the system from here. To change something, show the edit to this repo\n'
  printf 'and tell the user to open a terminal and run claude in ~/agentos to apply it.\n'
)"

cd "$repo" || exit 1

exec claude -p "$prompt" \
  --append-system-prompt "$context" \
  --allowedTools "Read,Glob,Grep,Bash(hyprctl:*),Bash(systemctl status:*),Bash(journalctl:*),Bash(git log:*),Bash(git diff:*),Bash(git status:*),Bash(nixos-version:*)"
