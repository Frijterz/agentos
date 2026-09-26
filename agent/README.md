# The Claude layer

The goal: Claude is a first-class part of the desktop that can see, explain and
change the system. The rule that makes it safe: **Claude never changes the system
directly. It changes this repo, and a human-approved switch applies it.**

## Phases

### Phase 1: ask & propose (done)
- `agentos-ask` (Super+A panel): headless Claude Code in `~/agentos`. It may edit the
  repo, `nh os build` and commit; no sudo, switch or push (see agent/agentos-ask.sh).
- `claude` in a terminal in `~/agentos`: full pair-programming on the OS. Claude edits
  files and runs `nh os build`; **you** run `nh os switch`.
- Live files (`config/hypr`, `config/quickshell`) apply on save without a rebuild,
  so Claude can iterate on the look with you in real time.

### Phase 2: streaming panel + approvals + desktop context
Built on the `claude` CLI rather than the Agent SDK, so it runs on the Claude
subscription login (the SDK docs direct you to an API key instead).
- Done: `claude -p --output-format stream-json` streams into the panel, with tool
  calls shown as lines; `--resume` gives conversation memory until "New chat".
- Done: approval cards. A `PermissionRequest` hook (`agentos-approve`) sends anything
  not on the allow list to the panel over `$XDG_RUNTIME_DIR/agentos-approve.sock`
  and waits for Deny / Allow once.
- Todo: context tools: active window, workspace layout (`hyprctl -j`), screenshot of
  the focused window (`grim`) on request, clipboard, notifications.

### Phase 3: apply with approval (done)
- `agentos-switch@<hash>.service` (root, oneshot) does exactly one thing: switch to the
  existing `nixos-system-<host>` build with that store hash, or `@rollback` to the
  previous generation. It takes no path from outside and validates the build.
- polkit lets only you start it, with your password every time (no "remember me").
- The panel runs `agentos-pending` after each reply and on open; a new build shows up
  as a card with the `nvd` package diff and git state, and Apply / Undo buttons.
- A read-only `/home` Btrfs snapshot is taken before every apply (newest 5 in
  `/home/.snapshots`). Rollback = Undo on the card, or the boot menu.

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
