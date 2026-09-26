# The Claude layer

The goal: Claude is a first-class part of the desktop that can see, explain and
change the system. The rule that makes it safe: **Claude never changes the system
directly. It changes this repo, and a human-approved switch applies it.**

## Phases

### Phase 1: ask & propose (now)
- `agentos-ask` (Super+A panel): headless Claude Code in `~/agentos`, read-only tools.
- `claude` in a terminal in `~/agentos`: full pair-programming on the OS. Claude edits
  files and runs `nh os build`; **you** run `nh os switch`.
- Live files (`config/hypr`, `config/quickshell`) apply on save without a rebuild,
  so Claude can iterate on the look with you in real time.

### Phase 2: streaming panel + desktop context
- Replace `claude -p` with a small daemon on the **Claude Agent SDK** (TypeScript or
  Python), talking to the panel over a Unix socket: streaming tokens, conversation
  memory, tool-call cards in the UI.
- Context tools: active window, workspace layout (`hyprctl -j`), screenshot of the
  focused window (`grim`) on request, clipboard, notifications.

### Phase 3: apply with approval
- A tiny privileged helper (systemd service) exposes exactly one action:
  "switch to the already-built generation at /nix/store/…-nixos-system-…".
- The daemon builds unprivileged, shows the `nvd` package diff + git diff in the
  panel, and the helper only runs after you click Approve (polkit prompt).
- `/home` snapshot before, commit after. Rollback = one button (or the boot menu).

### Phase 4: proactive
- Watch the journal, battery, updates, and failed units; suggest fixes as ready-built
  changes waiting for approval.
- Modes: "focus", "presentation", "battery saver", switched by Claude on request.
- Weekly `nix flake update` built in the background, with a summary of what changed.

## Security rules (all phases)
- Text Claude *reads* (web pages, mail, files, screenshots) never authorises an action.
  Only clicks/typing by you in the panel or terminal do.
- No secrets in this repo. API keys live in the keyring / environment.
- The agent runs as your user; the only privileged path is the Phase 3 helper.
