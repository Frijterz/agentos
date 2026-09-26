#!/usr/bin/env bash
# Snap the active window to a screen half: snap.sh left|right|up|down (Super+Alt+arrows).
# LIVE: called from hyprland.conf, edits apply immediately. Hyprland has no built-in
# "half screen", and tiled windows share the screen, so the window is made floating and
# placed inside the usable area (monitor minus the bar's reserved space and gaps_out).
# Super+T puts it back into the tiling.
set -euo pipefail

side="${1:?usage: snap.sh left|right|up|down}"
win="$(hyprctl activewindow -j)"
addr="$(jq -r '.address // empty' <<<"$win")"
[ -n "$addr" ] || exit 0

mon="$(hyprctl monitors -j | jq --argjson id "$(jq '.monitor' <<<"$win")" '.[] | select(.id == $id)')"
gap="$(hyprctl getoption general:gaps_out -j | jq -r '.custom // (.int | tostring)' | awk '{print $1}')"

# Usable area in layout coordinates (logical pixels: monitor pixels / scale).
read -r x0 y0 w h < <(jq -r --argjson g "$gap" '
  [ .x + .reserved[0] + $g,
    .y + .reserved[1] + $g,
    .width / .scale - .reserved[0] - .reserved[2] - 2 * $g,
    .height / .scale - .reserved[1] - .reserved[3] - 2 * $g ] | map(floor) | @tsv' <<<"$mon")

# Two halves with one gap between them.
hw=$(((w - gap) / 2))
hh=$(((h - gap) / 2))
case "$side" in
  left) set -- "$x0" "$y0" "$hw" "$h" ;;
  right) set -- "$((x0 + w - hw))" "$y0" "$hw" "$h" ;;
  up) set -- "$x0" "$y0" "$w" "$hh" ;;
  down) set -- "$x0" "$((y0 + h - hh))" "$w" "$hh" ;;
  *)
    echo "usage: snap.sh left|right|up|down" >&2
    exit 2
    ;;
esac

hyprctl --batch "dispatch setfloating address:$addr ; dispatch resizewindowpixel exact $3 $4,address:$addr ; dispatch movewindowpixel exact $1 $2,address:$addr" >/dev/null
