import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// niri backend of the compositor abstraction layer.
//
// State comes from niri's IPC event stream (`niri msg --json event-stream`):
// the stream always sends the full current state up-front, then NDJSON
// deltas. Delta events that cannot be applied locally (WorkspaceActivated,
// WorkspaceActiveWindowChanged, ...) trigger a debounced re-query — the
// same pattern CompositorService uses for the Hyprland rawEvent debounce.
// The subscription auto-reconnects when niri restarts.
//
// Two IPC quirks are worth documenting:
//  - niri does not expose a fullscreen flag: a fullscreen tile spans the
//    whole logical output (exclusive zones included), while a maximized
//    column stops at the bar's exclusive zone. focusedFullscreen is
//    derived by comparing the focused window's tile size with its
//    workspace output's logical size.
//  - there is no OutputsChanged event: outputs are polled once at startup
//    and then every 30 s (same cadence as the X11 xrandr poll), plus a
//    re-query on ConfigLoaded (output config may change with it).
//
// Workspaces are merged across outputs by display name: meowrch uses the
// numbered slots 1..10 from config.kdl's named workspaces, so a
// multi-monitor dynamic workspace with the same idx folds into its slot.

Item {
    id: root

    // True while the event stream subscription is alive.
    property bool connected: false

    // Flat merged list of workspaces: [{ name, focused, occupied, urgent }]
    property var workspaces: []

    // Numeric slot of the focused workspace ("1".."10" -> 1..10).
    readonly property int focusedWorkspaceId: {
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i].focused)
                return parseInt(workspaces[i].name) || 1;
        }
        return 1;
    }

    // Focused tile covers the whole logical output (fullscreen heuristic).
    property bool focusedFullscreen: false

    // Focused window identity ("" when nothing is focused, e.g. the
    // overview or a layer surface holds the keyboard).
    property string activeWindowClass: ""
    property string activeWindowTitle: ""

    // Active keyboard layout ("us") and the full configured list
    // ("us,ru"). niri reports XKB names directly — no name mapping needed
    // (unlike the hyprctl keymap display names HyprlandService resolves).
    property string keyboardLayout: "us"
    property string layoutList: ""
    readonly property var layoutCodes: layoutList !== "" ? layoutList.split(",") : []

    // Current refresh rate of the highest-refresh connected output — the
    // wallpaper transition target.
    property int maxMonitorRefresh: 60

    // Raw IPC state (not normalized).
    property var _rawWorkspaces: [] // niri Workspace objects
    property var _windows: ({}) // window id (as string) -> Window object
    property var _outputs: ({}) // output name -> { width, height, refresh }
    property int _focusedId: 0 // 0 = no window focused

    readonly property bool isActive: CompositorService.wm === "niri"

    Component.onCompleted: {
        if (!isActive)
            return ;

        // The event stream seeds everything (workspaces, windows, layouts),
        // but outputs have no push event and the fullscreen heuristic needs
        // their logical sizes — query them right away.
        outputsProc.running = true;
        subscribeProc.running = true;
    }

    // ------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------

    function command(args) {
        Quickshell.execDetached(["niri", "msg"].concat(args));
    }

    function switchWorkspace(id) {
        command(["action", "focus-workspace", String(id)]);
    }

    function closeFocusedWindow() {
        command(["action", "close-window"]);
    }

    // ------------------------------------------------------------------
    // Event stream (persistent, auto-reconnect)
    // ------------------------------------------------------------------

    Process {
        id: subscribeProc

        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line && line.trim() !== "")
                    root.handleEvent(line);

            }
        }
        onExited: {
            root.connected = false;
            // Reconnect: niri may have been restarted or the socket raced
            // the shell at login.
            reconnectTimer.restart();
        }
    }

    Timer {
        id: reconnectTimer

        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isActive && !subscribeProc.running)
                subscribeProc.running = true;

        }
    }

    function handleEvent(line) {
        root.connected = true;
        let ev;
        try {
            ev = JSON.parse(line.trim());
        } catch (e) {
            return ;
        }

        const name = Object.keys(ev)[0];
        const payload = ev[name];
        if (name === "WorkspacesChanged") {
            root._rawWorkspaces = payload.workspaces || [];
            root.normalizeWorkspaces();
            root.updateFullscreen();
        } else if (name === "WorkspaceActivated" || name === "WorkspaceActiveWindowChanged" || name === "WorkspaceUrgencyChanged") {
            // No output name in the payload — a debounced re-query is
            // cheaper than reconstructing per-output activation by hand.
            stateRefreshTimer.restart();
        } else if (name === "WindowsChanged") {
            root.applyWindows(payload.windows || []);
        } else if (name === "WindowOpenedOrChanged") {
            root.upsertWindow(payload.window);
        } else if (name === "WindowClosed") {
            root.removeWindow(payload.id);
        } else if (name === "WindowFocusChanged") {
            root.setFocused(payload.id);
        } else if (name === "WindowUrgencyChanged") {
            const w = root._windows[String(payload.id)];
            if (w)
                w.is_urgent = payload.urgent === true;

        } else if (name === "WindowLayoutsChanged") {
            root.applyLayoutChanges(payload.changes || []);
        } else if (name === "KeyboardLayoutsChanged") {
            root.applyLayouts(payload.keyboard_layouts || {});
        } else if (name === "KeyboardLayoutSwitched") {
            const codes = root.layoutCodes;
            if (payload.idx !== undefined && codes[payload.idx])
                root.keyboardLayout = codes[payload.idx];

        } else if (name === "ConfigLoaded") {
            // Output config can change with the config file.
            outputsProc.running = false;
            outputsProc.running = true;
        }
        // OverviewOpenedOrClosed, ScreenshotCaptured, Casts*,
        // WindowFocusTimestampChanged, TouchpadToggled — not consumed.
    }

    // ------------------------------------------------------------------
    // Debounced one-shot state re-query (workspaces + windows)
    // ------------------------------------------------------------------

    Timer {
        id: stateRefreshTimer

        interval: 100
        repeat: false
        onTriggered: {
            wsQueryProc.running = false;
            wsQueryProc.running = true;
            winQueryProc.running = false;
            winQueryProc.running = true;
        }
    }

    Process {
        id: wsQueryProc

        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // `niri msg --json` prints the unwrapped payload (a plain
                    // array here); the raw socket would wrap it in Ok/Err.
                    const reply = JSON.parse((text || "").trim());
                    const list = Array.isArray(reply) ? reply : ((reply.Ok && reply.Ok.Workspaces) || []);
                    if (list.length > 0) {
                        root._rawWorkspaces = list;
                        root.normalizeWorkspaces();
                        root.updateFullscreen();
                    }
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: winQueryProc

        command: ["niri", "msg", "--json", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse((text || "").trim());
                    const list = Array.isArray(reply) ? reply : ((reply.Ok && reply.Ok.Windows) || []);
                    if (list.length > 0 || Object.keys(root._windows).length > 0)
                        root.applyWindows(list);

                } catch (e) {
                }
            }
        }

    }

    // ------------------------------------------------------------------
    // Outputs poll (no push event for outputs in the IPC)
    // ------------------------------------------------------------------

    Process {
        id: outputsProc

        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const reply = JSON.parse((text || "").trim());
                    // CLI output: plain { name: Output } map (no Ok wrapper)
                    const outputs = reply.Ok ? (reply.Ok.Outputs || {}) : (reply || {});
                    const map = {};
                    let maxRefresh = 0;
                    for (const name of Object.keys(outputs)) {
                        const out = outputs[name];
                        const logical = out.logical || null;
                        let refresh = 0;
                        if (out.current_mode !== null && out.modes && out.modes[out.current_mode])
                            refresh = (out.modes[out.current_mode].refresh_rate || 0) / 1000;

                        map[name] = {
                            "width": logical ? logical.width : 0,
                            "height": logical ? logical.height : 0,
                            "refresh": Math.round(refresh)
                        };
                        if (refresh > maxRefresh)
                            maxRefresh = refresh;

                    }
                    root._outputs = map;
                    if (maxRefresh > 0)
                        root.maxMonitorRefresh = Math.round(maxRefresh);

                    root.updateFullscreen();
                } catch (e) {
                }
            }
        }

    }

    Timer {
        id: outputsPollTimer

        interval: 30000
        running: root.connected
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            outputsProc.running = false;
            outputsProc.running = true;
        }
    }

    // ------------------------------------------------------------------
    // Normalization
    // ------------------------------------------------------------------

    function normalizeWorkspaces() {
        const merged = {};
        const list = root._rawWorkspaces;
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            if (!ws)
                continue;

            // meowrch named workspaces are "1".."10"; dynamic workspaces
            // fall back to their per-output idx and fold into the same slot
            // when names collide across monitors.
            const name = ws.name || String(ws.idx);
            let cur = merged[name];
            if (!cur) {
                cur = {
                    "name": name,
                    "focused": false,
                    "occupied": false,
                    "urgent": false
                };
                merged[name] = cur;
            }
            if (ws.is_focused)
                cur.focused = true;

            if (ws.active_window_id !== null && ws.active_window_id !== undefined)
                cur.occupied = true;

            if (ws.is_urgent)
                cur.urgent = true;

        }
        const out = Object.values(merged);
        out.sort((a, b) => {
            const na = parseInt(a.name), nb = parseInt(b.name);
            if (!isNaN(na) && !isNaN(nb))
                return na - nb;
            if (!isNaN(na))
                return -1;
            if (!isNaN(nb))
                return 1;
            return a.name.localeCompare(b.name);
        });
        root.workspaces = out;
    }

    function applyWindows(list) {
        const map = {};
        let focused = 0;
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w)
                continue;

            map[String(w.id)] = w;
            if (w.is_focused)
                focused = w.id;

        }
        root._windows = map;
        root._focusedId = focused;
        root.updateFocusedIdentity();
        root.updateFullscreen();
    }

    function upsertWindow(w) {
        if (!w)
            return ;

        // "If the window is focused, all other windows are no longer
        // focused" — WindowOpenedOrChanged carries focus transitions.
        if (w.is_focused) {
            for (const key of Object.keys(root._windows))
                root._windows[key].is_focused = false;

            root._focusedId = w.id;
        }
        root._windows[String(w.id)] = w;
        root.updateFocusedIdentity();
        root.updateFullscreen();
    }

    function removeWindow(id) {
        delete root._windows[String(id)];
        if (root._focusedId === id) {
            root._focusedId = 0;
            root.updateFocusedIdentity();
            root.updateFullscreen();
        }
    }

    function setFocused(id) {
        root._focusedId = id || 0;
        for (const key of Object.keys(root._windows))
            root._windows[key].is_focused = (Number(key) === root._focusedId);

        root.updateFocusedIdentity();
        root.updateFullscreen();
    }

    function applyLayoutChanges(changes) {
        for (let i = 0; i < changes.length; i++) {
            const w = root._windows[String(changes[i][0])];
            if (w)
                w.layout = changes[i][1];

        }
        root.updateFullscreen();
    }

    function applyLayouts(kl) {
        const names = kl.names || [];
        // niri reports RMLVO display names ("English (US)") despite what
        // the docs call them — resolve codes the way HyprlandService does
        // for hyprctl keymap names.
        root.layoutList = names.map((n) => {
            return root.layoutCode(n);
        }).join(",");
        const idx = kl.current_idx || 0;
        root.keyboardLayout = root.layoutCode(names[idx]) || "us";
    }

    function layoutCode(name) {
        if (!name)
            return "";

        const map = CompositorService.layoutNameMap;
        if (map[name] !== undefined)
            return map[name];

        for (let key of Object.keys(map)) {
            if (name.indexOf(key) !== -1)
                return map[key];

        }
        const candidate = name.toLowerCase().split(" ")[0];
        return (candidate.length >= 2 && candidate.length <= 4) ? candidate : name;
    }

    function updateFocusedIdentity() {
        const w = root._windows[String(root._focusedId)];
        root.activeWindowClass = (w && w.app_id) ? w.app_id : "";
        root.activeWindowTitle = (w && w.title) ? w.title : "";
    }

    function updateFullscreen() {
        const w = root._windows[String(root._focusedId)];
        if (!w || !w.layout || !w.workspace_id) {
            root.focusedFullscreen = false;
            return ;
        }

        let output = null;
        for (let i = 0; i < root._rawWorkspaces.length; i++) {
            if (root._rawWorkspaces[i] && root._rawWorkspaces[i].id === w.workspace_id) {
                output = root._rawWorkspaces[i].output;
                break;
            }
        }
        const out = (output && root._outputs[output]) ? root._outputs[output] : null;
        if (!out || !out.width) {
            root.focusedFullscreen = false;
            return ;
        }

        // Fullscreen tile spans the whole logical output (exclusive zones
        // included); a maximized column stops at the bar's exclusive zone.
        const tile = w.layout.tile_size || [0, 0];
        root.focusedFullscreen = Math.abs(tile[0] - out.width) <= 2 && Math.abs(tile[1] - out.height) <= 2;
    }
}
