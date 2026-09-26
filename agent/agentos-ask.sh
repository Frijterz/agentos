# agentos-ask "<question>": ask Claude from the desktop (used by the Claude panel).
# Packaged by modules/nixos/agent.nix (writeShellApplication adds the shebang and
# `set -euo pipefail`).
#
# Phase 1b: Claude runs inside the agentos repo (so it follows CLAUDE.md) and may edit
# files there, build, and commit. acceptEdits only covers the repo; edits elsewhere
# need a permission prompt, which headless mode can't show, so they're refused.
# Applying (sudo), pushing and arbitrary hyprctl dispatches stay with the user.
# Note: Claude Code also runs commands it recognises as read-only (uname, grep, ...).

prompt="${1:?usage: agentos-ask \"<question>\"}"
repo="${AGENTOS_FLAKE:-$HOME/agentos}"

context="$(
  printf 'Desktop context (from agentos-ask):\n'
  printf -- '- Active window: %s\n' "$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.class) - \(.title)"' || echo unknown)"
  printf -- '- Active workspace: %s\n' "$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' || echo unknown)"
  printf -- '- Current system generation: %s\n' "$(readlink /nix/var/nix/profiles/system || echo unknown)"
  printf 'You are answering in a small desktop side panel: be concise, use short Markdown.\n'
  printf 'You may edit this repo, run nh os build and commit, following CLAUDE.md. Edits to\n'
  printf 'config/hypr and config/quickshell apply live immediately. You cannot apply system\n'
  printf 'changes: after a successful build, tell the user to run nh os switch in a terminal.\n'
  printf 'Each question starts a fresh session: do the whole task in one go.\n'
)"

cd "$repo" || exit 1

exec claude -p "$prompt" \
  --append-system-prompt "$context" \
  --permission-mode acceptEdits \
  --allowedTools \
  "Read,Glob,Grep,Edit,Write" \
  "Bash(nh os build:*),Bash(nix fmt:*),Bash(nix flake check:*)" \
  "Bash(git add:*),Bash(git commit:*),Bash(git log:*),Bash(git diff:*),Bash(git status:*),Bash(git show:*)" \
  "Bash(hyprctl activewindow:*),Bash(hyprctl activeworkspace:*),Bash(hyprctl clients:*),Bash(hyprctl monitors:*),Bash(hyprctl workspaces:*),Bash(hyprctl binds:*),Bash(hyprctl devices:*),Bash(hyprctl version:*),Bash(hyprctl configerrors:*),Bash(hyprctl reload:*)" \
  "Bash(systemctl status:*),Bash(systemctl --user status:*),Bash(journalctl:*),Bash(nixos-version:*)" \
  --disallowedTools \
  "Bash(sudo:*),Bash(nh os switch:*),Bash(nh os boot:*),Bash(nixos-rebuild:*),Bash(git push:*),Bash(hyprctl dispatch:*),Bash(hyprctl keyword:*)"
