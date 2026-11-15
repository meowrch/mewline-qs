import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// Tracks the focused Hyprland toplevel (window class + title) and resolves an
// application icon for it, so bar styles can show a "focused app" pill.
//
// Tracking is event-driven from Hyprland's s1 socket (Quickshell.Hyprland):
// - `activewindow>>CLASS,TITLE` fires on every focus change AND whenever the
//   focused window's title changes (Hyprland re-emits it for the active
//   window on metadata updates), with an empty class "," when the desktop
//   gets focus. parse(2) keeps commas inside the title intact because only
//   the first n-1 args are split.
// - Quickshell's own `Hyprland.activeToplevel` is NOT used as the source of
//   truth because in 0.3.x it stays stale when the desktop is focused (the
//   empty `activewindowv2` address fails hex parsing and is ignored) and its
//   window class would require extra refreshToplevels() round trips.

Singleton {
    id: focusedAppService

    // Window class of the focused toplevel, "" when the desktop is focused.
    property string windowClass: ""
    // Title of the focused toplevel, "" when unknown.
    property string windowTitle: ""

    // True while a real application window (not the desktop) is focused.
    readonly property bool hasWindow: windowClass !== ""

    // Ready-to-use Image source for the focused app icon ("" when unresolved).
    readonly property string appIconSource: {
        let icon = resolveIcon(windowClass);
        if (icon === "")
            return "";

        let path = icon;
        let home = Quickshell.env("HOME");
        if (path.startsWith("$HOME"))
            path = home + path.substring(5);
        else if (path.startsWith("~"))
            path = home + path.substring(1);

        if (path.startsWith("file://"))
            return path;

        if (path.startsWith("/"))
            return "file://" + path;

        // Theme icon name; check=true returns "" instead of a broken fallback.
        return Quickshell.iconPath(path, true);
    }

    // Hostname for the no-focus fallback label (user@host, like mewline).
    property string hostname: {
        try {
            if (hostFile.loaded && hostFile.text() !== "")
                return hostFile.text().trim();

        } catch (e) {
        }
        return "";
    }

    FileView {
        id: hostFile

        path: "/etc/hostname"
    }

    // Text shown in the bar: the live window title, falling back to the
    // desktop entry's name, then the raw window class, then user@hostname
    // when the desktop itself is focused (nothing is).
    readonly property string displayTitle: {
        let title = windowTitle.trim();
        if (title !== "")
            return title;

        if (windowClass.trim() === "" || windowClass === "undefined") {
            let user = Quickshell.env("USER") || "user";
            return user + "@" + (hostname !== "" ? hostname : "hyprland");
        }

        let entry = DesktopEntries.heuristicLookup(windowClass);
        if (entry && entry.name && entry.name.trim() !== "")
            return entry.name;

        return windowClass;
    }

    // Resolves an icon name (or path) for a window class:
    // 1. Desktop entry lookup (exact id, then StartupWMClass match).
    // 2. Theme icon candidates derived from the class spelling.
    // 3. Standard "missing app" icon as the last resort.
    function resolveIcon(cls) {
        if (!cls || cls === "")
            return "";

        let entry = DesktopEntries.heuristicLookup(cls);
        if (entry && entry.icon && entry.icon !== "")
            return entry.icon;

        let candidates = [];
        let add = (c) => {
            if (c && c !== "" && candidates.indexOf(c) === -1)
                candidates.push(c);

        };
        add(cls);
        add(cls.toLowerCase());
        let dot = cls.lastIndexOf(".");
        if (dot !== -1 && dot < cls.length - 1) {
            let tail = cls.substring(dot + 1);
            add(tail);
            add(tail.toLowerCase());
        }
        let dash = cls.indexOf("-");
        if (dash > 0)
            add(cls.substring(0, dash).toLowerCase());

        for (let i = 0; i < candidates.length; i++)
            if (Quickshell.hasThemeIcon(candidates[i]))
                return candidates[i];

        return "application-x-executable";
    }

    Connections {
        function onRawEvent(event) {
            if (event.name !== "activewindow")
                return ;

            let args = event.parse(2);
            focusedAppService.windowClass = args[0] || "";
            focusedAppService.windowTitle = args[1] || "";
        }

        target: Hyprland
    }

    // Initial state: Hyprland only emits `activewindow` on changes, so seed
    // the current focus once at startup. `hyprctl -j activewindow` prints
    // non-JSON "invalid" when the desktop is focused -> treated as no window.
    Process {
        id: activeWindowInitProc

        command: ["sh", "-c", "hyprctl -j activewindow 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let win = JSON.parse(text.trim());
                    focusedAppService.windowClass = win.class || "";
                    focusedAppService.windowTitle = win.title || "";
                } catch (e) {
                    focusedAppService.windowClass = "";
                    focusedAppService.windowTitle = "";
                }
            }
        }
    }

    Component.onCompleted: activeWindowInitProc.running = true
}
