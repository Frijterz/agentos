# agentos-screenshot [window|screen]: capture the active window (default) or the focused
# monitor for Claude, and print the PNG's path. Used by the panel's camera button and,
# via an approval card, by Claude itself. Packaged by modules/nixos/agent.nix.
#
# Shots go to $XDG_RUNTIME_DIR/agentos-shots (RAM, gone at logout; newest 10 kept),
# which agentos-ask lets Claude read without another card.

what="${1:-window}"
dir="${XDG_RUNTIME_DIR:?}/agentos-shots"
mkdir -p "$dir"
chmod 700 "$dir"
out="$dir/$(date +%Y%m%d-%H%M%S)-$what.png"

# Hide the Claude panel so it isn't in the picture, and wait for its fade-out.
panel_was_open=0
if [ "$(qs ipc call claude isOpen 2>/dev/null || true)" = true ]; then
  panel_was_open=1
  qs ipc call claude close
  sleep 0.4
fi

geometry=""
if [ "$what" = window ]; then
  geometry="$(hyprctl activewindow -j | jq -r 'select(.size != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
fi

if [ -n "$geometry" ]; then
  grim -g "$geometry" "$out"
else
  grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$out"
fi

if [ "$panel_was_open" = 1 ]; then
  qs ipc call claude open
fi

find "$dir" -maxdepth 1 -name '*.png' -printf '%f\n' | sort | head -n -10 |
  while read -r old; do rm -f "$dir/$old"; done

echo "$out"
