import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// bspwm (X11) backend of the compositor abstraction layer.
//
// State comes from two sources:
// - `bspc subscribe report` — a full state line on every change. The
//   subscription auto-reconnects (mewline's Python service lacked this and
//   died silently when bspwm was restarted).
// - cheap polls for things bspwm does not push: focused window title/class
//   (500ms, `bspc query -T -n focused`) and the keyboard layout (1s,
//   xkb-switch / setxkbmap).
//
// The report grammar (man bspwm): colon-separated items —
//   M/m<name>  focused / unfocused monitor
//   O/o<name>  occupied desktop, focused / unfocused
//   F/f<name>  free (empty) desktop, focused / unfocused
//   U/u<name>  urgent desktop, focused / unfocused
//   L(T|M)     layout of the monitor's focused desktop
//   T(T|P|F|=|@)  focused node state, F = fullscreen
//   G(S?P?L?M?)   focused node flags
// Example: `MHDMI-0:o1:O2:o3:f4:F5:LT:TF:G`.

Item {
    id: root

    // True while the report subscription is alive.
    property bool connected: false

    // Flat ordered list of desktops: [{ name, focused, occupied, urgent }]
    property var workspaces: []

    // Name of the focused desktop ("3").
    property string focusedDesktop: ""

    // The focused node is fullscreen (report T tag).
    property bool focusedFullscreen: false

    // Focused window identity ("" when the desktop itself is focused).
    property string activeWindowClass: ""
    property string activeWindowTitle: ""

    // Active keyboard layout ("us") and the full configured list ("us,ru").
    property string keyboardLayout: "us"
    property string layoutList: ""
    readonly property var layoutCodes: layoutList !== "" ? layoutList.split(",") : []

    readonly property bool isActive: CompositorService.isX11

    Component.onCompleted: {
        if (!isActive)
            return ;

        // `bspc subscribe report` does not guarantee an initial line, so a
        // one-shot query seeds the state until the first event arrives.
        initialRefreshProc.running = true;
        subscribeProc.running = true;
    }

    // ------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------

    function command(args) {
        Quickshell.execDetached(["bspc"].concat(args));
    }

    function focusDesktop(name) {
        command(["desktop", "-f", String(name)]);
    }

    function closeNode(address) {
        command(["node", "-c", address]);
    }

    function focusNode(address) {
        command(["node", "-f", address]);
    }

    // ------------------------------------------------------------------
    // Report stream (persistent, auto-reconnect)
    // ------------------------------------------------------------------

    function handleReport(line) {
        let monitorsArr = [];
        let cur = null;
        let focusedWs = "";
        let focusedFullscreen = false;
        const parts = line.trim().split(":");
        for (let i = 0; i < parts.length; i++) {
            const part = parts[i];
            if (part.length < 1)
                continue;

            const tag = part[0];
            const val = part.substring(1);
            if (tag === "W") {
                // Real report lines start with W<M|m><monitor-name>: the
                // outer W wraps the monitor state (a live line looks like
                // `WMeDP:O1:f2:...:LT:TT:G`). mewline's parser handles the
                // same quirk.
                if (val.length > 1) {
                    cur = {
                        "name": val.substring(1),
                        "focused": val.charAt(0) === "M",
                        "desktops": []
                    };
                    monitorsArr.push(cur);
                }
            } else if (tag === "M" || tag === "m") {
                cur = {
                    "name": val,
                    "focused": tag === "M",
                    "desktops": []
                };
                monitorsArr.push(cur);
            } else if (tag === "O" || tag === "o" || tag === "F" || tag === "f" || tag === "U" || tag === "u") {
                if (!cur)
                    continue;

                const lower = tag.toLowerCase();
                // Uppercase marks the focused desktop (only on the focused
                // monitor). Urgent desktops count as occupied — an urgent
                // desktop always has something to look at.
                const focused = tag !== lower;
                const occupied = lower === "o" || lower === "u";
                const urgent = lower === "u";
                cur.desktops.push({
                    "name": val,
                    "focused": focused,
                    "occupied": occupied,
                    "urgent": urgent
                });
                if (focused)
                    focusedWs = val;

            }
            // L (layout), T (focused node state — its letters do not map to
            // what the man page claims, empirically `TF` arrives for a
            // focused tiled window) and G (node flags) are not used: the
            // fullscreen state comes from the debounced query below.
        }
        let flat = [];
        for (let m = 0; m < monitorsArr.length; m++)
            for (let d = 0; d < monitorsArr[m].desktops.length; d++)
                flat.push(monitorsArr[m].desktops[d]);

        root.workspaces = flat;
        root.focusedDesktop = focusedWs;
        fullscreenCheckDebounce.restart();
    }

    Process {
        id: subscribeProc

        command: ["bspc", "subscribe", "report"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line && line.trim() !== "")
                    root.handleReport(line);

            }
        }
        onExited: {
            root.connected = false;
            // Reconnect: bspwm may have been restarted (bspc wm -r) or the
            // socket raced the shell at login.
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

    // ------------------------------------------------------------------
    // One-shot initial state (names + occupied + focused + focused node)
    // ------------------------------------------------------------------

    Process {
        id: initialRefreshProc

        command: ["sh", "-c", "echo \"$(bspc query -D --names 2>/dev/null)\"; echo -n \"|$(bspc query -D -d .occupied --names 2>/dev/null)\"; echo -n \"|$(bspc query -D -d focused --names 2>/dev/null)\"; echo -n \"|\"; bspc query -T -n focused 2>/dev/null"]
        stdout: StdioCollector {
            id: initialOutput

            onStreamFinished: {
                const text = (initialOutput.text || "").trim();
                if (text === "")
                    return ;

                const sections = text.split("|");
                const names = sections[0].split("\n").map((n) => {
                    return n.trim();
                }).filter((n) => {
                    return n !== "";
                });
                const occupied = {};
                sections[1].split("\n").forEach((n) => {
                    n = n.trim();
                    if (n !== "")
                        occupied[n] = true;
                });
                const focusedName = sections[2].trim();
                const out = [];
                for (let i = 0; i < names.length; i++) {
                    out.push({
                        "name": names[i],
                        "focused": names[i] === focusedName,
                        "occupied": occupied[names[i]] === true,
                        "urgent": false
                    });
                }
                if (out.length > 0) {
                    root.workspaces = out;
                    root.focusedDesktop = focusedName;
                }
                fullscreenCheckDebounce.restart();
            }
        }

    }

    // Fullscreen state of the focused desktop: the report T tag turned out
    // unreliable, so this is a direct query, debounced per report burst.
    Timer {
        id: fullscreenCheckDebounce

        interval: 150
        repeat: false
        onTriggered: {
            fullscreenCheckProc.running = false;
            fullscreenCheckProc.running = true;
        }
    }

    Process {
        id: fullscreenCheckProc

        command: ["sh", "-c", "bspc query -N -d focused -n .fullscreen 2>/dev/null"]
        stdout: StdioCollector {
            id: fullscreenCheckOutput

            onStreamFinished: {
                root.focusedFullscreen = (fullscreenCheckOutput.text || "").trim() !== "";
            }
        }

    }

    // ------------------------------------------------------------------
    // Focused window identity poll (bspwm pushes no title events)
    // ------------------------------------------------------------------

    Timer {
        id: activeWinTimer

        interval: 500
        running: root.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            activeWinProc.running = false;
            activeWinProc.running = true;
        }
    }

    Process {
        id: activeWinProc

        command: ["sh", "-c", "bspc query -T -n focused 2>/dev/null"]
        stdout: StdioCollector {
            id: activeWinOutput

            onStreamFinished: {
                try {
                    const node = JSON.parse((activeWinOutput.text || "").trim());
                    const client = node && node.client ? node.client : null;
                    root.activeWindowClass = client ? (client.className || "") : "";
                    root.activeWindowTitle = client ? (client.title || "") : "";
                } catch (e) {
                    root.activeWindowClass = "";
                    root.activeWindowTitle = "";
                }
            }
        }

    }

    // ------------------------------------------------------------------
    // Keyboard layout poll (xkb-switch gives the active layout)
    // ------------------------------------------------------------------

    Timer {
        id: layoutTimer

        interval: 1000
        running: root.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            layoutProc.running = false;
            layoutProc.running = true;
        }
    }

    Process {
        id: layoutProc

        command: ["sh", "-c", "L=$(setxkbmap -query 2>/dev/null | awk '/^layout/{print $2}'); A=$(command -v xkb-switch >/dev/null 2>&1 && xkb-switch -p 2>/dev/null); echo \"$L|$A\""]
        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                const parts = data.trim().split("|");
                const list = (parts[0] || "").trim();
                const active = (parts[1] || "").trim();
                if (list !== "")
                    root.layoutList = list;

                let code = "us";
                if (active !== "")
                    code = active;
                else if (list !== "")
                    code = list.split(",")[0];
                if (root.keyboardLayout !== code)
                    root.keyboardLayout = code;

            }
        }

    }

    onConnectedChanged: {
        if (!connected)
            return ;

        // Fresh subscription: seed identity/layout immediately.
        activeWinProc.running = true;
        layoutProc.running = true;
    }
}
