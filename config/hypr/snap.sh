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
# gaps_out from Hyprland; 12 (hyprland.lua's value) if it can't be read.
# (Lua configs answer {"css": "12 12 12 12"}, hyprlang ones {"custom": "12 12 12 12"}.)
gap="$(hyprctl getoption general:gaps_out -j 2>/dev/null | jq -r '.css // .custom // (.int | tostring)' 2>/dev/null | awk '{print $1}' || true)"
[[ "$gap" =~ ^[0-9]+$ ]] || gap=12

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

# Hyprland's Lua config takes Lua; the old hyprlang config takes the old commands.
# TRANSITION: once every session is Lua, only the first branch remains.
if [ "$(hyprctl dispatch 'hl.dsp.no_op()')" = ok ]; then
  w="window = \"address:$addr\""
  hyprctl eval "hl.dispatch(hl.dsp.window.float({ action = \"enable\", $w }))
    hl.dispatch(hl.dsp.window.resize({ x = $3, y = $4, $w }))
    hl.dispatch(hl.dsp.window.move({ x = $1, y = $2, $w }))" >/dev/null
else
  hyprctl --batch "dispatch setfloating address:$addr ; dispatch resizewindowpixel exact $3 $4,address:$addr ; dispatch movewindowpixel exact $1 $2,address:$addr" >/dev/null
fi
