# agentos-ask [--resume <session-id>] "<question>": ask Claude from the desktop.
# Used by the Claude panel; prints Claude Code's stream-json events, one per line.
# Packaged by modules/nixos/agent.nix (writeShellApplication adds the shebang and
# `set -euo pipefail`).
#
# Claude runs inside the agentos repo (so it follows CLAUDE.md) and may edit files
# there, build, and commit. Other actions go to agentos-approve, which asks you in the
# panel. sudo, switch, push and hyprctl dispatch/keyword are denied outright.
# Note: Claude Code also runs commands it recognises as read-only (uname, grep, ...).

resume=()
if [ "${1:-}" = "--resume" ]; then
  resume=(--resume "${2:?--resume needs a session id}")
  shift 2
fi
prompt="${1:?usage: agentos-ask [--resume <session-id>] \"<question>\"}"
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
)"

cd "$repo" || exit 1

# Anything not allowed below (and not denied) becomes an Approve/Deny card in the panel.
hooks='{"hooks":{"PermissionRequest":[{"matcher":"*","hooks":[{"type":"command","command":"agentos-approve","timeout":300}]}]}}'

# No bare tool names: "Read" alone would approve reads of any path. Reads and edits
# inside the repo need no rule (working directory + acceptEdits); elsewhere they ask.
exec claude -p "$prompt" "${resume[@]}" \
  --output-format stream-json --verbose --include-partial-messages \
  --append-system-prompt "$context" \
  --settings "$hooks" \
  --permission-mode acceptEdits \
  --allowedTools \
  "Bash(nh os build:*),Bash(nix fmt:*),Bash(nix flake check:*)" \
  "Bash(git add:*),Bash(git commit:*),Bash(git log:*),Bash(git diff:*),Bash(git status:*),Bash(git show:*)" \
  "Bash(hyprctl activewindow:*),Bash(hyprctl activeworkspace:*),Bash(hyprctl clients:*),Bash(hyprctl monitors:*),Bash(hyprctl workspaces:*),Bash(hyprctl binds:*),Bash(hyprctl devices:*),Bash(hyprctl version:*),Bash(hyprctl configerrors:*),Bash(hyprctl reload:*)" \
  "Bash(systemctl status:*),Bash(systemctl --user status:*),Bash(journalctl:*),Bash(nixos-version:*)" \
  --disallowedTools \
  "Bash(sudo:*),Bash(nh os switch:*),Bash(nh os boot:*),Bash(nixos-rebuild:*),Bash(git push:*),Bash(hyprctl dispatch:*),Bash(hyprctl keyword:*)"
