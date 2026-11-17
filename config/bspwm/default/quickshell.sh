#!/bin/sh
# mewline-qs autostart module for bspwm.
# Source from ~/.config/bspwm/bspwmrc (rules must be registered before the
# shell windows appear).
#
# Every Quickshell window shares the WM_CLASS "quickshell" (PanelWindow has
# no per-window title on X11). One class rule covers them all: dock windows
# are never tiled, stay on every desktop and sit above normal windows. The
# windows that must not take focus set accept_focus=false themselves
# (PanelWindow.focusable), so bspwm only ever focuses the menu hosts.

QS_DIR="${MEWLINE_QS_DIR:-$HOME/.config/quickshell}"

bspc rule -a quickshell state=floating sticky=on layer=above border=off

# Launch the shell once (an already running instance wins).
if ! pgrep -x quickshell >/dev/null 2>&1; then
  quickshell -p "$QS_DIR" >/dev/null 2>&1 &
fi
