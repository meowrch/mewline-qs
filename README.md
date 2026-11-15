<div align="center">

# ✨ Mewline QS

**Quickshell status bar for the [meowrch](https://github.com/meowrch/meowrch) distribution.**
Convex bar, pawlette-driven theming, privacy dots, theme & wallpaper popups.

</div>

## About

Mewline QS is the Quickshell successor of [mewline](https://github.com/meowrch/mewline)
(the Python + Fabric bar). The shell is built on top of the
[Minflair](https://github.com/t4lentles5/minflair) Quickshell shell
(GPL-3.0) and heavily reworked for meowrch:

- **Pawlette integration** — the shell is painted live from
  `~/.local/state/pawlette/active_palette.json`; a bottom-sheet theme
  selector (same UX as the wallpaper selector) applies themes and accent
  variants through the `pawlette` CLI, with Dynamic (wallpaper-driven) and
  Random modes.
- **Dashboard** — meowrch info card (logo, user@host, meowrch version),
  package updates, quotes. No cloud/github services.
- **Privacy dots** — 2×2 mic/camera/screen/location indicators ported from
  the mewline privacy service, with per-app tooltips.
- **Configurable wallpaper folder** (default `~/.local/share/wallpapers`).
- **Nothing is written outside the shell's own cache** — Hyprland input,
  GTK/Qt fonts and themes are never modified at startup; Hyprland input
  config stays owned by `hyprland.lua`.

## Run

```bash
quickshell -p /usr/share/mewline-qs/quickshell   # packaged
quickshell -p config/quickshell                  # from this repo
```

Requirements: `quickshell`, `pawlette`, `python` (stdlib only scripts),
`awww`, pipewire, hyprland.

## IPC

Every widget exposes a unix socket (`/tmp/quickshell_<id>`):

```bash
socat - UNIX-CONNECT:/tmp/quickshell_pawlette    # theme selector
socat - UNIX-CONNECT:/tmp/quickshell_wallpaper   # wallpaper selector
socat - UNIX-CONNECT:/tmp/quickshell_launcher    # launcher
# ... dashboard, controlCenter, clipboard, powerMenu, ...
```

## License

GPL-3.0 — see [LICENSE](LICENSE). Based on Minflair by t4lentles5;
privacy detection logic ported from mewline (MIT, meowrch).
