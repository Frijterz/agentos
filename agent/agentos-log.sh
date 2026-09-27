# agentos-log: the mission log, a private daily record of what changed on this laptop
# and why. Kept in ~/.local/state/agentos/mission-log (never in the public repo).
# Packaged by modules/nixos/agent.nix.
#
#   note <kind> <text>   add an event to today (ask, health, update); used by agentos-ask,
#                        agentos-watch and agentos-update
#   show [today|DATE]    print a day as Markdown: today is compiled live, earlier days
#                        from their finished file (with Claude's summary)
#   list                 days with entries, newest first, as JSON lines for the card
#   compile              finish past days: facts + a short summary by a tool-less Claude
#                        (daily timer; catches up after the laptop was off)
#
# Applied builds, undos and commits aren't noted as they happen: they're read from the
# generation links, the Apply button's journal and git when a day is compiled, so
# builds applied with `nh os switch` in a terminal count too.

log="${XDG_STATE_HOME:-$HOME/.local/state}/agentos/mission-log"
repo="${AGENTOS_FLAKE:-$HOME/agentos}"
mkdir -p "$log/events"
chmod 700 "$log"

# One line per event: HH:MM <tab> kind <tab> text.
note() {
  local kind="${1:?usage: agentos-log note <kind> <text>}" text="${2:-}"
  text="$(printf '%s' "$text" | tr '\n\t' '  ' | cut -c 1-160)"
  printf '%s\t%s\t%s\n' "$(date +%H:%M)" "$kind" "$text" >>"$log/events/$(date -I).tsv"
}

# The facts of one day, as Markdown sections (nothing if the day was quiet).
facts() {
  local day="$1" next
  next="$(date -I -d "$day + 1 day")"

  # Applied builds: generation links made that day. The Apply button (agentos-switch@)
  # logs the builds it applied and undos to the journal; the rest came from a terminal.
  local panel applied undos commits events
  panel="$(journalctl -u 'agentos-switch@*' --since "$day" --until "$next" -o json --no-pager 2>/dev/null |
    jq -r 'select(.MESSAGE | test("^agentos-switch: applying")) | "\(._SYSTEMD_UNIT)\t\(.MESSAGE | sub("^agentos-switch: applying "; ""))"' || true)"
  applied="$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' \
    -newermt "$day" ! -newermt "$next" -printf '%TH:%TM\t%f\t%l\n' 2>/dev/null | sort |
    while IFS=$'\t' read -r time link target; do
      n="${link#system-}"
      n="${n%-link}"
      how="terminal"
      printf '%s\n' "$panel" | grep -qF "$target" && how="Claude panel"
      printf -- '- %s · generation %s (%s)\n' "$time" "$n" "$how"
    done)"
  undos="$(journalctl -u 'agentos-switch@rollback' --since "$day" --until "$next" -o short-iso --no-pager 2>/dev/null |
    grep -F 'agentos-switch: applying' | sed -E 's/^[0-9-]+T([0-9]{2}:[0-9]{2}).*/- \1 · undo: back to the previous generation/' || true)"
  commits="$(git -C "$repo" log main --since="$day 00:00" --until="$next 00:00" --reverse \
    --date=format:%H:%M --format='- %ad · %s' 2>/dev/null || true)"
  events="$(awk -F'\t' '{
      label = $2 == "ask" ? "asked Claude: " : $2 == "health" ? "health: " : $2 == "update" ? "update: " : $2 ": "
      printf "- %s · %s%s\n", $1, label, $3
    }' "$log/events/$day.tsv" 2>/dev/null || true)"

  # A busy day: one line instead of dozens (the commits below say what changed).
  if [ "$(printf '%s\n' "$applied" | grep -c .)" -gt 6 ]; then
    applied="$(printf '%s\n' "$applied" | awk '
      { split($0, f, " · "); time[NR] = substr(f[1], 3); sub(/^generation /, "", f[2]); split(f[2], g, " ");
        gen[NR] = g[1]; if ($0 ~ /Claude panel/) panel++ }
      END { printf "- %s · %d builds applied until %s: generations %s to %s (%d from the Claude panel, %d from a terminal)\n",
              time[1], NR, time[NR], gen[1], gen[NR], panel, NR - panel }')"
  fi

  if [ -n "$applied$undos" ]; then
    printf '## Applied\n%s\n\n' "$(printf '%s\n%s\n' "$applied" "$undos" | grep -v '^$' | sort)"
  fi
  [ -z "$commits" ] || printf '## Changes\n%s\n\n' "$commits"
  [ -z "$events" ] || printf '## Events\n%s\n\n' "$events"
}

title() {
  printf '# %s\n\n' "$(date -d "$1" '+%A %-d %B %Y')"
}

show() {
  local day="${1:-today}"
  [ "$day" = today ] && day="$(date -I)"
  [[ "$day" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
    echo "agentos-log: not a date: $day" >&2
    exit 1
  }
  if [ -f "$log/$day.md" ]; then
    cat "$log/$day.md"
  else
    local f
    f="$(facts "$day")"
    title "$day"
    if [ -n "$f" ]; then printf '%s\n' "$f"; else printf 'A quiet day: nothing changed.\n'; fi
  fi
}

# Finish past days (the last two weeks) that have facts but no file yet. Without a
# summary (offline, or Claude unavailable) a day is retried, and written plain once
# it's three days old.
compile() {
  local i day f summary
  for i in $(seq 14 -1 1); do
    day="$(date -I -d "-$i day")"
    [ -f "$log/$day.md" ] && continue
    f="$(facts "$day")"
    [ -n "$f" ] || continue
    # Tool-less, outside the repo (no CLAUDE.md); it only sees the day's facts.
    summary="$(cd "$log" && printf '%s\n' "$f" | timeout 180 claude -p \
      "Stdin is one day of the mission log of the owner's agentOS laptop (NixOS, Hyprland, Quickshell): builds applied, commits (what changed and why), events and what they asked Claude. Write a 2-3 sentence summary of the day for the owner, in plain language: what changed and why it matters. No preamble, no headings, no lists." \
      --disallowedTools '*' 2>/dev/null || true)"
    if [ -z "$summary" ] && [ "$i" -lt 3 ]; then continue; fi
    {
      title "$day"
      [ -z "$summary" ] || printf '## Summary\n%s\n\n' "$summary"
      printf '%s\n' "$f"
    } >"$log/$day.md.tmp"
    mv "$log/$day.md.tmp" "$log/$day.md"
  done
  # Events older than two weeks are in their day's file by now.
  find "$log/events" -name '*.tsv' -mtime +15 -delete
}

# For the card: {"date", "label", "summary"} per day, today first.
list() {
  local today day
  today="$(date -I)"
  jq -cn --arg date "$today" '{date: $date, label: "Today", summary: ""}'
  find "$log" -maxdepth 1 -name '????-??-??.md' -printf '%f\n' | sort -r | head -n 60 |
    while read -r f; do
      day="${f%.md}"
      [ "$day" = "$today" ] && continue
      jq -cn --arg date "$day" --arg label "$(date -d "$day" '+%a %-d %b')" \
        --arg summary "$(sed -n '/^## Summary$/{n;p;q}' "$log/$f")" \
        '{date: $date, label: $label, summary: $summary}'
    done
}

case "${1:-}" in
  note) note "${2:-}" "${3:-}" ;;
  show) show "${2:-today}" ;;
  list) list ;;
  compile) compile ;;
  *)
    echo "usage: agentos-log note <kind> <text> | show [today|YYYY-MM-DD] | list | compile" >&2
    exit 1
    ;;
esac
