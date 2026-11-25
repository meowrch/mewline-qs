import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// Compositor abstraction layer. The shell must run on Hyprland (Wayland),
// niri (Wayland) and bspwm (X11): everything compositor-facing goes through
// this singleton instead of touching Hyprland/WlrLayershell directly.
//
// Session detection is synchronous (env only): a Wayland session is
// Hyprland unless NIRI_SOCKET is set (niri exports it for its IPC), and
// anything non-Wayland is treated as the bspwm/X11 build. The backends are
// HyprlandService (Wayland/Hyprland), NiriService (Wayland/niri) and
// BspwmService (X11) — this file only normalizes their state and routes
// commands.

Item {
    id: root

    // ------------------------------------------------------------------
    // Session detection
    // ------------------------------------------------------------------
    readonly property string sessionType: (Quickshell.env("XDG_SESSION_TYPE") || "").toLowerCase()
    // Quickshell.env() returns undefined for unset variables, and
    // `undefined !== ""` is true — always coalesce before comparing.
    readonly property bool isWayland: sessionType === "wayland" || (sessionType === "" && (Quickshell.env("WAYLAND_DISPLAY") || "") !== "")
    readonly property bool isNiri: isWayland && (Quickshell.env("NIRI_SOCKET") || "") !== ""
    readonly property bool isX11: !isWayland
    readonly property bool isHyprland: isWayland && !isNiri
    // Backend identifier ("hyprland" / "niri" / "bspwm") — matches the
    // per-WM keys used by the config files.
    readonly property string wm: isX11 ? "bspwm" : (isNiri ? "niri" : "hyprland")

    // ------------------------------------------------------------------
    // Uniform state — declared in the "Normalized state" section below as
    // readonly bindings over the active backend. Only the mutable X11
    // poll target and the caps LED state live here.
    // ------------------------------------------------------------------

    // Caps lock state (bar layout indicator, case-flipped clock label).
    // Sysfs LED polling works on both Wayland and X11 — it is kernel level.
    property bool capsLockOn: false
    property string capsLedPath: ""

    // XKB layout code for a keymap display name ("English (US)" -> "us").
    // Hyprland (hyprctl keymap names) and niri (KeyboardLayoutsChanged
    // names) both report RMLVO-style display names.
    readonly property var layoutNameMap: ({
        "Arabic": "ara",
        "English (US)": "us",
        "English (UK)": "gb",
        "English": "us",
        "Spanish (Latin American)": "latam",
        "Spanish (Spain)": "es",
        "Spanish": "latam",
        "French (Canada)": "ca",
        "French": "fr",
        "German": "de",
        "Italian": "it",
        "Portuguese (Brazil)": "br",
        "Portuguese": "pt",
        "Russian": "ru",
        "Ukrainian": "ua",
        "Polish": "pl",
        "Turkish": "tr",
        "Japanese": "jp",
        "Korean": "kr",
        "Dutch": "nl",
        "Swedish": "se",
        "Norwegian": "no",
        "Danish": "dk",
        "Finnish": "fi",
        "Czech": "cz",
        "Greek": "gr",
        "Hebrew": "il"
    })

    // ------------------------------------------------------------------
    // Wayland/Hyprland state mirrors (bindings, no manual refresh needed)
    // ------------------------------------------------------------------
    readonly property var hyprWorkspaces: {
        if (!isHyprland)
            return [];

        const list = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : [];
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        const focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            if (!ws || ws.id <= 0)
                continue;

            let hasWins = false;
            if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
                hasWins = true;

            if (!hasWins)
                hasWins = tops.some((top) => {
                    return top && top.workspace && top.workspace.id === ws.id;
                });

            out.push({
                "name": String(ws.id),
                "focused": focusedId === ws.id,
                "occupied": hasWins,
                "urgent": false
            });
        }
        out.sort((a, b) => {
            return parseInt(a.name) - parseInt(b.name);
        });
        return out;
    }

    readonly property var hyprLayoutCodes: HyprlandService.layoutList !== "" ? HyprlandService.layoutList.split(",") : []

    readonly property int hyprMaxRefresh: {
        let max = 0;
        const monitors = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
        for (let i = 0; i < monitors.length; i++) {
            const r = (monitors[i].lastIpcObject && monitors[i].lastIpcObject.refreshRate) || 0;
            if (r > max)
                max = r;
        }
        return max > 0 ? Math.round(max) : 60;
    }

    // ------------------------------------------------------------------
    // Normalized state per backend
    // ------------------------------------------------------------------
    readonly property var workspaces: isX11 ? (BspwmService.workspaces || []) : (isNiri ? (NiriService.workspaces || []) : hyprWorkspaces)

    // Numeric id of the focused workspace (parseInt of the desktop name on
    // bspwm, the workspace slot id on niri, the Hyprland workspace id on
    // Hyprland).
    readonly property int focusedWorkspaceId: isX11 ? ((parseInt(BspwmService.focusedDesktop) || 0) || 1) : (isNiri ? NiriService.focusedWorkspaceId : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1))

    readonly property bool hasFullscreen: isX11 ? BspwmService.focusedFullscreen : (isNiri ? NiriService.focusedFullscreen : ((Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen) ? HyprlandService.isTrueFullscreen : false))

    readonly property string keyboardLayout: isX11 ? BspwmService.keyboardLayout : (isNiri ? NiriService.keyboardLayout : HyprlandService.keyboardLayout)

    readonly property var layoutCodes: isX11 ? BspwmService.layoutCodes : (isNiri ? NiriService.layoutCodes : hyprLayoutCodes)

    // Highest refresh rate among the connected monitors — the wallpaper
    // transition target. On X11 it comes from a xrandr poll (current mode
    // of every output is starred), on niri from the IPC outputs query.
    readonly property int maxMonitorRefresh: isX11 ? x11MaxRefresh : (isNiri ? NiriService.maxMonitorRefresh : hyprMaxRefresh)

    property int x11MaxRefresh: 60
    readonly property string x11RefreshCmd: "xrandr --query 2>/dev/null | grep '\\*' | grep -oE '[0-9]+(\\.[0-9]+)?\\*' | tr -d '*' | sort -nr | head -1"

    Process {
        id: x11RefreshProc

        command: ["sh", "-c", root.x11RefreshCmd]
        stdout: SplitParser {
            onRead: (data) => {
                const rate = parseFloat((data || "").trim());
                if (!isNaN(rate) && rate > 0)
                    root.x11MaxRefresh = Math.round(rate);
            }
        }

    }

    Timer {
        id: x11RefreshTimer

        interval: 30000
        running: root.isX11
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            x11RefreshProc.running = false;
            x11RefreshProc.running = true;
        }
    }

    // Caps Lock LED probe + poll (kernel level — shared by all backends).
    Process {
        id: capsLedProbe

        command: ["sh", "-c", "for f in /sys/class/leds/*::capslock/brightness; do echo \"$f\"; break; done"]
        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "")
                    root.capsLedPath = data.trim();

            }
        }

    }

    FileView {
        id: capsLedFile

        path: root.capsLedPath
        onLoaded: root.capsLockOn = text().trim() === "1"
    }

    Timer {
        id: capsPollTimer

        interval: 700
        running: root.capsLedPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: capsLedFile.reload()
    }

    // Wayland workspace refresh loop — same pattern the bar widget used to
    // run inline: Hyprland model bindings only re-evaluate when the model
    // is explicitly refreshed.
    Timer {
        id: refreshDebounce

        interval: 100
        repeat: false
        onTriggered: {
            if (root.isHyprland)
                Hyprland.refreshWorkspaces();

        }
    }

    Connections {
        function onRawEvent(event) {
            if (!root.isHyprland || !event || !event.name)
                return ;

            const ev = event.name;
            if (ev === "openwindow" || ev === "closewindow" || ev === "movewindowv2" || ev === "createworkspacev2" || ev === "destroyworkspacev2" || ev === "workspace" || ev === "workspacev2" || ev === "focusedmon" || ev === "fullscreen")
                refreshDebounce.restart();

        }

        target: Hyprland
    }

    Component.onCompleted: {
        capsLedProbe.running = true;
        // Seed the workspaces / focused state once at startup.
        refreshDebounce.restart();
    }

    // ------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------

    function switchWorkspace(id) {
        if (root.isHyprland) {
            // Prefer the workspace object: activate() branches on the config
            // provider internally, so it works with both hyprland.conf and
            // hyprland.lua. Only a not-yet-created workspace needs a raw
            // dispatcher, whose syntax depends on the provider.
            const list = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : [];
            for (let i = 0; i < list.length; i++) {
                if (list[i] && list[i].id === id) {
                    list[i].activate();
                    return ;
                }
            }
            // Read usingLua at call time — it only turns true after
            // Quickshell's async `j/status` request lands.
            Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({workspace=' + id + '})' : 'workspace ' + id);
        } else if (root.isNiri)
            NiriService.switchWorkspace(id);
        else
            BspwmService.command(["desktop", "-f", String(id)]);
    }

    // Launch an application command string through the compositor the way
    // the session keybinds do (keeps env/scratchpad behavior consistent).
    function launchCommand(cmd) {
        if (root.isHyprland) {
            const request = Hyprland.usingLua ? "hl.dsp.exec_cmd(" + JSON.stringify(cmd) + ")" : "exec " + cmd;
            Hyprland.dispatch(request);
        } else {
            // bspwm and niri: plain detached spawn inherits the session env
            Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    // X11 only: remember the currently focused bspwm node before a shell
    // window grabs the keyboard, restore it when the popup closes.
    function captureFocus() {
        if (!root.isX11)
            return ;

        Quickshell.execDetached(["sh", "-c", "id=$(bspc query -N -n focused 2>/dev/null); [ -n \"$id\" ] && printf '%s' \"$id\" > \"$XDG_RUNTIME_DIR/quickshell_focus_backup\""]);
    }

    function restoreFocus() {
        if (!root.isX11)
            return ;

        Quickshell.execDetached(["sh", "-c", "id=$(cat \"$XDG_RUNTIME_DIR/quickshell_focus_backup\" 2>/dev/null); [ -n \"$id\" ] && bspc node \"$id\" --focus 2>/dev/null; rm -f \"$XDG_RUNTIME_DIR/quickshell_focus_backup\""]);
    }

    // X11 keyboard handover. Shell windows are dock-type and unmanaged:
    // bspwm never answers the ICCCM _NET_ACTIVE_WINDOW request Qt sends on
    // requestActivate(), so the compositor-abstraction helpers hand the
    // keyboard over with a direct xdotool SetInputFocus instead. The
    // static surfaces are tagged with unique names by the bspwm autostart
    // module (PanelWindow exposes no per-window title), dynamically opened
    // sheets are always the newest shell window.

    // Focus a shell window by its tagged name ("mewline-drawers", ...).
    function activateWindowByTitle(title) {
        if (!root.isX11)
            return ;

        Quickshell.execDetached(["sh", "-c", "id=$(xdotool search --onlyvisible --name \"$1\" 2>/dev/null | tail -1); [ -n \"$id\" ] && xdotool windowfocus --sync \"$id\" 2>/dev/null", "qs-focus", title]);
    }

    // Focus the newest shell window — used for dynamically created sheets
    // (theme selector), which cannot be tagged at startup. Their WM_NAME is
    // empty, so enumeration filters on _NET_WM_NAME via xprop instead of
    // xdotool search.
    function activateNewestShellWindow() {
        if (!root.isX11)
            return ;

        Quickshell.execDetached(["sh", "-c", "id=$(for w in $(xdotool search --name '' 2>/dev/null); do nm=$(xprop -id \"$w\" _NET_WM_NAME 2>/dev/null); case \"$nm\" in *'\"quickshell\"'*) echo \"$w\";; esac; done | tail -1); [ -n \"$id\" ] && xdotool windowfocus --sync \"$id\" 2>/dev/null"]);
    }

}
