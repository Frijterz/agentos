# agentos-approve: Claude Code PermissionRequest hook for the Claude panel.
# Packaged by modules/nixos/agent.nix; agentos-ask installs it via --settings.
#
# Reads the permission request (JSON) on stdin, sends it to the Quickshell panel over
# a Unix socket and waits for your click. Anything but an explicit "allow" (no panel,
# timeout, Deny) is a deny. Deny rules are checked by Claude Code before and after
# this hook, so it can never approve sudo, switch or push.

sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agentos-approve.sock"

decide() {
  if [ "$1" = allow ]; then
    jq -nc '{hookSpecificOutput: {hookEventName: "PermissionRequest", decision: {behavior: "allow"}}}'
  else
    jq -nc --arg m "$2" '{hookSpecificOutput: {hookEventName: "PermissionRequest", decision: {behavior: "deny", message: $m}}}'
  fi
  exit 0
}

[ -S "$sock" ] || decide deny "The agentos panel is not running, so nobody could approve this."

request="$(jq -c .)"
# ignoreeof: don't half-close after sending, or the panel sees the connection drop.
# The panel closes it after answering. 290s < the hook timeout (300s) in agentos-ask.
reply="$(printf '%s\n' "$request" | socat -t 290 -T 290 STDIO,ignoreeof UNIX-CONNECT:"$sock" 2>/dev/null | head -n 1 || true)"

case "$reply" in
  allow) decide allow ;;
  deny) decide deny "The user denied this in the agentos panel. Do not retry it; ask what they want instead." ;;
  *) decide deny "No answer from the agentos panel (timed out or closed)." ;;
esac
