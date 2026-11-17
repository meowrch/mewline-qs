# mewline-qs on bspwm (X11)

Everything here is additive to an existing bspwm setup (meowrch build):
source the modules from your `bspwmrc`, the sxhkd fragment from `sxhkdrc`,
and merge the picom rules.

## Files

- `default/quickshell.sh` — autostart module: registers window rules, then
  launches the shell. Source it from `~/.config/bspwm/bspwmrc` after the
  `windowrules` module (rules must exist before the windows appear):
  `source "$XDG_CONFIG_HOME/bspwm/default/quickshell.sh"`
- `sxhkdrc-mewline` — the shell keybinds (IPC toggles). Include from your
  sxhkdrc: `sxhkd -c ~/.config/bspwm/sxhkdrc-mewline ...` (multiple `-c`
  flags are read in order) or paste the block into your sxhkdrc.
- `picom-mewline.conf` — picom rules for the shell windows (no double
  shadows, no picom fade). `include-file` it from picom.conf.

## Window identity

All Quickshell windows share the WM_CLASS "quickshell" on X11 (PanelWindow
has no per-window title). The single class rule in `default/quickshell.sh`
covers every surface; focusability is decided per window by
PanelWindow.focusable.
