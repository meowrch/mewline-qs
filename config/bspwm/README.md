# mewline-qs on bspwm (X11)

Everything here is additive to an existing bspwm setup (meowrch build):
source the modules from your `bspwmrc`, the sxhkd fragment from `sxhkdrc`,
and merge the picom rules.

## Files

- `default/quickshell.sh` — autostart module: launches the shell and tags
  the three fullscreen surfaces (bar overlay, menu host, gaming) with
  unique window names. Source it from `~/.config/bspwm/bspwmrc`:
  `source "$XDG_CONFIG_HOME/bspwm/default/quickshell.sh"`
- `sxhkdrc-mewline` — the shell keybinds (widget socket toggles), mirroring
  the fabric-cli island binds of the meowrch sxhkdrc. Paste the block into
  your sxhkdrc or pass both files to sxhkd.
- `picom-mewline.conf` — picom rules for the shell windows (no double
  shadows, no picom fade, 32px frame radius). Merge into picom.conf or
  `include-file` it.

## Window identity and keyboard (X11)

Shell windows are `_NET_WM_WINDOW_TYPE_DOCK`: bspwm does not manage them
(no rules needed) and never answers ICCCM activation requests, which makes
`requestActivate()` useless for keyboard handover. Instead the autostart
module tags the fullscreen surfaces with unique names (`mewline-drawers`,
`mewline-bar-overlay`, `mewline-gaming`) and the shell hands the keyboard
over with a direct `xdotool windowfocus` on the tagged name. Note: Qt
leaves WM_NAME empty (only `_NET_WM_NAME` is set) and `xdotool search
--name` reads WM_NAME — the tagging sets both atoms.
