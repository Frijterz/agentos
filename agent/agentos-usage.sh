# agentos-usage: current plan limits for the Claude panel's meters, as JSON in the same
# shape as stream-json's rate_limit_event:
#   {"five_hour": {"utilization": 0.76, "resetsAt": <unix>}, "seven_day": {...}}
# Uses Claude Code's `/usage`, which needs no model turn (costs nothing, ~3 s).
# It's text meant for people, so parse defensively: print nothing if it doesn't match.
# Packaged by modules/nixos/agent.nix.

# Outside the repo: /usage doesn't need project context.
cd "${XDG_STATE_HOME:-$HOME/.local/state}"
text="$(timeout 30 claude -p "/usage" --output-format json </dev/null | jq -r '.result // empty')"

# "<label>: 76% used · resets Sep 27, 2am (Europe/Amsterdam)" -> {"utilization":0.76,"resetsAt":…}
window() {
  line="$(printf '%s\n' "$text" | grep -m1 "^$1" || true)"
  pct="$(printf '%s' "$line" | sed -n 's/.*: \([0-9]\+\)% used.*/\1/p')"
  when="$(printf '%s' "$line" | sed -n 's/.*resets \(.*\) (.*/\1/p' | tr -d ',')"
  [ -n "$pct" ] && [ -n "$when" ] || return 0
  at="$(date -d "$when" +%s 2>/dev/null)" || return 0
  # No year in the text: a date that looks months ago is next year's.
  if [ "$at" -lt "$(($(date +%s) - 86400))" ]; then at="$(date -d "$when next year" +%s)"; fi
  jq -nc --argjson p "$pct" --argjson at "$at" '{utilization: ($p / 100), resetsAt: $at}'
}

five="$(window "Current session")"
week="$(window "Current week")"
[ -n "$five" ] || [ -n "$week" ] || exit 0
jq -nc --argjson f "${five:-null}" --argjson w "${week:-null}" \
  '{five_hour: $f, seven_day: $w} | with_entries(select(.value != null))'
