# AGENTS.md

Mewline is a Quickshell (QML) desktop shell for the meowrch distribution — Hyprland, niri and bspwm. There is no build system: QML is loaded from source at runtime.

## Run and verify

- Dev run from the checkout: `quickshell -p config/quickshell`
- Most users run the packaged copy at `/usr/share/mewline-qs/quickshell`; repo edits are **not** live there. Reinstall, or run the checkout and compare with `diff -rq /usr/share/mewline-qs/quickshell config/quickshell`.
- No test suite, and CI does not run `qmllint`. Closest checks:
  - `python -m compileall -q config/quickshell/Scripts`
  - `shellcheck --severity=error config/bspwm/default/quickshell.sh config/quickshell/Scripts/system/*.sh`
  - `bash -n <script>` — bash only parses its first file argument, so check scripts one at a time.
- QML errors only surface at load; after changing QML, launch the shell and exercise the affected widget.

## Layout

- `config/quickshell/shell.qml` — `ShellRoot`: IPC handlers, panel windows, module loaders.
- `Core/Services/*.qml` — `pragma Singleton` state and compositor backends. `Core/Components`, `Core/Windows`, `Core/Utils` — shared UI/helpers.
- `Modules/Bar` — bar styles (`Styles/Convex`, `Styles/Gaming`) and widgets; `Modules/<Widget>` — drawers/popups.
- `Scripts/` and `*/scripts/` — Python/bash runtime helpers invoked through `Quickshell.shellDir`.
- `config/bspwm/` — X11-only integration (window tagging, sxhkd, picom); `docs/device-batteries.md` — peripheral battery limits.

## QML conventions and gotchas

- The `qs` import root is `config/quickshell` (`qs.Core.Services` → `config/quickshell/Core/Services`). Quickshell auto-generates `qmldir`; singletons need `pragma Singleton` and must live in the module directory. Do not add hand-written qmldir files.
- All compositor-facing code goes through `Core/Services/CompositorService.qml`. Widgets must not call `Hyprland`, `bspc` or `niri` directly. Backends: `HyprlandService`, `NiriService`, `BspwmService`.
- `CompositorService.wm` is `"hyprland"`, `"niri"` or `"bspwm"` — never `"x11"` or `"wayland"`.
- `Quickshell.env()` returns `undefined` for unset variables, and `undefined !== ""` is true. Always coalesce: `(Quickshell.env("X") || "")`. This exact bug made a Hyprland session detect as niri, which silently broke workspace switching.
- Hyprland dispatcher syntax depends on the config provider: `hyprland.conf` uses `workspace 3` / `exec cmd`; `hyprland.lua` uses `hl.dsp.focus({workspace=3})` / `hl.dsp.exec_cmd("cmd")`. Each mode rejects the other's syntax, and `hyprctl` may still exit 0. `Hyprland.usingLua` is async and false until `j/status` lands — read it at call time, or prefer object APIs (`HyprlandWorkspace.activate()`, `Toplevel.activate()`) that branch internally.
- The bar style is fixed to Convex (`SettingsService.barStyle`); Gaming is a separate surface toggled by `DisplayProfileService.gameModeActive`.
- The workspace widget shows only occupied workspaces plus the focused one (`Modules/Bar/Components/Workspaces.qml`). Empty slots are intentionally hidden — don't reintroduce fixed empty dots. `SettingsService.workspaceDisplayMode` switches between `"dots"` and `"numbers"` (mini capsules).
- Settings persist to `~/.cache/quickshell/settings_prefs.json`; theme/wallpaper caches also live under `~/.cache/quickshell`.

## IPC

- `qs ipc call widgets toggle calendar`, `qs ipc call barscape esc`, `qs ipc call osd showVolume 40 false`.
- Each widget also listens on `/tmp/quickshell_<widgetId>` (used by the bspwm sxhkd fragment): `socat - UNIX-CONNECT:/tmp/quickshell_calendar`.

## Packaging

- Only `PKGBUILD.stable` is tracked; the AUR workflow rewrites its `pkgver`/`sha256sums` on release. The version also appears in the README badges.
- The package copies `config/quickshell` verbatim, so keep the shell self-contained (no paths outside the tree at runtime).
