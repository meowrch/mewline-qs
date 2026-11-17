#!/bin/sh
# mewline-qs autostart module for bspwm.
# Source from ~/.config/bspwm/bspwmrc.
#
# Shell windows are _NET_WM_WINDOW_TYPE_DOCK: bspwm does not manage them
# (no rules needed — they never enter the tiled tree). They carry no
# WM_CLASS either, so for X11 keyboard handover (xdotool SetInputFocus —
# nobody answers ICCCM activation requests for unmanaged dock windows) the
# fullscreen surfaces are tagged with unique names below, keyed by
# creation order (X ids grow with creation; shell.qml maps the fullscreen
# surfaces in order: BarOverlayWindow, ConvexDesktop, GamingOverlay).

QS_DIR="${MEWLINE_QS_DIR:-$HOME/.config/quickshell}"
SCREEN=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2}')
SCREEN_W=${SCREEN%x*}
SCREEN_H=${SCREEN#*x}

# Shell surfaces carry an empty WM_NAME (Qt writes only _NET_WM_NAME),
# and xdotool search --name reads WM_NAME — so enumeration goes through
# xprop and tagging sets both atoms (searchable + keeps the visible name).
tag_shell_windows() {
  ids=""
  for id in $(xdotool search --name '' 2>/dev/null); do
    nm=$(xprop -id "$id" _NET_WM_NAME 2>/dev/null)
    case "$nm" in
      *'"quickshell"'*) ;;
      *) continue ;;
    esac
    w=$(xdotool getwindowgeometry --shell "$id" 2>/dev/null | awk -F= '/WIDTH/ {print $2}')
    h=$(xdotool getwindowgeometry --shell "$id" 2>/dev/null | awk -F= '/HEIGHT/ {print $2}')
    [ "$w" = "$SCREEN_W" ] && [ "$h" = "$SCREEN_H" ] && ids="$ids $id"
  done
  set -- $ids
  [ $# -eq 3 ] || return 1
  xdotool set_window --name mewline-bar-overlay "$1"
  xdotool set_window --name mewline-drawers "$2"
  xdotool set_window --name mewline-gaming "$3"
  return 0
}

# Launch the shell once (an already running instance wins).
if ! pgrep -x quickshell >/dev/null 2>&1; then
  quickshell -p "$QS_DIR" >/dev/null 2>&1 &
fi

# Wait for the three fullscreen surfaces to map, then tag them.
n=0
while [ $n -lt 40 ]; do
  if tag_shell_windows; then
    break
  fi
  sleep 0.5
  n=$((n + 1))
done
