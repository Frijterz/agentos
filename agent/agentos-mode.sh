# agentos-mode [normal | battery | presentation | focus | next | status]
# Switch the desktop mode. Packaged by modules/nixos/agent.nix; used by the system menu,
# Super+M and the panel's Claude. Modes last for the session: login resets to normal.
#
#   normal        balanced power, eye candy on, notifications on
#   battery       power-saver, no blur/shadows/animations/moving background
#   presentation  performance, notifications silenced, no screensaver/lock/suspend
#   focus         balanced, notifications silenced
#
# Silenced notifications aren't lost: they're in the system menu's history.

state="${XDG_STATE_HOME:-$HOME/.local/state}/agentos/mode"
mkdir -p "$(dirname "$state")"
current="$(cat "$state" 2>/dev/null || echo normal)"
modes=(normal battery presentation focus)

mode="${1:-status}"
case "$mode" in
  status)
    echo "$current"
    exit 0
    ;;
  next)
    for i in "${!modes[@]}"; do
      if [ "${modes[$i]}" = "$current" ]; then
        mode="${modes[$(((i + 1) % ${#modes[@]}))]}"
      fi
    done
    [ "$mode" != next ] || mode=normal
    ;;
  normal | battery | presentation | focus) ;;
  *)
    echo "usage: agentos-mode [normal|battery|presentation|focus|next|status]" >&2
    exit 2
    ;;
esac

# Power profile (power-profiles-daemon; no password needed in your own session).
case "$mode" in
  battery) powerprofilesctl set power-saver ;;
  presentation) powerprofilesctl set performance ;;
  *) powerprofilesctl set balanced ;;
esac

# Hyprland eye candy: switched off at runtime; a reload restores hyprland.conf.
if [ "$mode" = battery ]; then
  hyprctl --batch "keyword animations:enabled 0 ; keyword decoration:blur:enabled 0 ; keyword decoration:shadow:enabled 0" >/dev/null
elif [ "$current" = battery ]; then
  hyprctl reload >/dev/null
fi

# Notifications need nothing here: Quickshell's daemon (Notifs.qml) reads the mode file
# below and holds pop-ups back in presentation and focus.

# Presentation: an idle inhibitor, which hypridle respects (no screensaver, lock, suspend).
systemctl --user stop agentos-presentation.service 2>/dev/null || true
if [ "$mode" = presentation ]; then
  systemd-run --user --quiet --collect --unit=agentos-presentation \
    systemd-inhibit --what=idle --who=agentos --why="presentation mode" sleep infinity
fi

# Write in place (not mv): Quickshell's FileView watches this file for the bar chip.
printf '%s\n' "$mode" >"$state"
echo "mode: $mode"
