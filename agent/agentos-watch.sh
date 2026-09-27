# agentos-watch [check | ack]: look for problems and show them in the Claude panel.
# Packaged by modules/nixos/agent.nix; run hourly by agentos-watch.timer.
#
# check: failed units (system + user), new journal errors since the last check (minus
#        agent/watch-ignore.txt), battery health and charge limit, disk space. Writes
#        health.json for the panel (agentos-pending) and notifies about new findings.
#        It never fixes anything itself: the panel's "Ask Claude" does that, with you.
# ack:   Dismiss in the panel: hide the current findings until they change.

repo="${AGENTOS_FLAKE:-$HOME/agentos}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/agentos"
out="$state/health.json"
acked="$state/health-acked"
notified="$state/health-notified"
since_file="$state/watch-since"
mkdir -p "$state"
touch "$acked" "$notified"

ack() {
  [ -f "$out" ] && jq -r '.findings[].id' "$out" >>"$acked"
  rm -f "$out"
}

check() {
  new="$(mktemp)"
  trap 'rm -f "$new"' EXIT

  # id changes when the problem changes, so a dismissed finding comes back if it does.
  add() { jq -nc --arg id "$1" --arg title "$2" --arg detail "$3" '{id: $id, title: $title, detail: $detail}' >>"$new"; }

  # Failed units. The state-change time is in the id: a new failure is a new finding.
  for scope in system user; do
    flag=()
    if [ "$scope" = user ]; then flag=(--user); fi
    for unit in $(systemctl "${flag[@]}" --failed --plain --no-legend | awk '{print $1}'); do
      since="$(systemctl "${flag[@]}" show -p StateChangeTimestampMonotonic --value "$unit")"
      add "unit:$scope:$unit:$since" "Failed $scope service: $unit" \
        "$(systemctl "${flag[@]}" status "$unit" --no-pager -n 6 2>&1 | tail -n 8 || true)"
    done
  done

  # Journal errors since the last check (this boot on the first run), grouped by source.
  since="$(cat "$since_file" 2>/dev/null || true)"
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  range=(-b)
  [ -n "$since" ] && range=(--since "$since")
  ignore="$repo/agent/watch-ignore.txt"
  [ -f "$ignore" ] || ignore=/dev/null
  # grep exits 1 when every line is filtered out; that's fine here.
  journalctl "${range[@]}" -p err -o json --no-pager 2>/dev/null |
    jq -r '[(._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER // "kernel"), (.MESSAGE | tostring)] | @tsv' |
    { grep -v -E -f <(grep -v -E '^\s*(#|$)' "$ignore" || true) || true; } |
    sort | uniq -c | sort -rn | head -n 8 |
    while read -r count src msg; do
      key="$(printf '%s' "$msg" | tr -d '0-9' | cut -c 1-80)"
      add "log:$src:$key" "$count× error from $src" "$msg"
    done
  echo "$now" >"$since_file"

  # Battery: health, and the 80% charge limit from zenbook-um3406.nix.
  bat=/sys/class/power_supply/BAT0
  if [ -r "$bat/energy_full" ] && [ -r "$bat/energy_full_design" ]; then
    health=$(($(cat "$bat/energy_full") * 100 / $(cat "$bat/energy_full_design")))
    if [ "$health" -lt 80 ]; then
      add "battery-health:$((health / 5 * 5))" "Battery health is $health%" \
        "Full charge now holds $health% of the design capacity."
    fi
  fi
  if [ -r "$bat/charge_control_end_threshold" ]; then
    limit="$(cat "$bat/charge_control_end_threshold")"
    if [ "$limit" != 80 ]; then
      add "charge-limit:$limit" "Charge limit is $limit%, expected 80%" \
        "The udev rule in modules/nixos/zenbook-um3406.nix should keep it at 80%."
    fi
  fi

  # Off-laptop backup (modules/nixos/backup.nix): stale after 3 days. No file yet means
  # backups aren't set up (or never succeeded), which docs/BACKUP.md covers.
  last_ok=/var/lib/agentos/backup-last-ok
  if [ -f "$last_ok" ]; then
    age=$((($(date +%s) - $(stat -c %Y "$last_ok")) / 86400))
    if [ "$age" -ge 3 ]; then
      add "backup-stale:$age" "Last backup was $age days ago" \
        "$(systemctl status restic-backups-home.service --no-pager -n 6 2>&1 | tail -n 8 || true)"
    fi
  fi

  # Disk space.
  df --output=target,pcent / /home | tail -n +2 | while read -r mnt pct; do
    pct="${pct%\%}"
    if [ "$pct" -ge 90 ]; then
      add "disk:$mnt:$((pct / 5 * 5))" "$mnt is $pct% full" \
        "Old generations: nh clean all. Big folders: du -xh --max-depth=1 $mnt | sort -h"
    fi
  done

  # Current findings = new ones plus earlier log errors not yet dismissed (they happened
  # before this check's window); failed units etc. are re-checked every time.
  {
    cat "$new"
    if [ -f "$out" ]; then jq -c '.findings[] | select(.id | startswith("log:"))' "$out"; fi
  } | jq -sc --rawfile acked "$acked" --arg date "$now" \
    '($acked | split("\n")) as $a | {date: $date, findings: (unique_by(.id) | map(select(.id as $i | $a | index($i) | not)))}' >"$out.tmp"
  mv "$out.tmp" "$out"

  fresh="$(jq -r '.findings[].id' "$out" | grep -v -x -F -f "$notified" || true)"
  if [ -n "$fresh" ]; then
    printf '%s\n' "$fresh" >>"$notified"
    notify-send -a agentos "agentos noticed $(printf '%s\n' "$fresh" | wc -l) new problem(s)" \
      "Open the Claude panel (Super+A) to review them." || true
    # Into the mission log too.
    jq -r --rawfile fresh <(printf '%s\n' "$fresh") \
      '($fresh | split("\n")) as $f | .findings[] | select(.id as $i | $f | index($i)) | .title' "$out" |
      while read -r title; do agentos-log note health "$title" || true; done
  fi
  [ "$(jq '.findings | length' "$out")" -gt 0 ] || rm -f "$out"
}

case "${1:-check}" in
  check) check ;;
  ack) ack ;;
  *)
    echo "usage: agentos-watch [check | ack]" >&2
    exit 2
    ;;
esac
