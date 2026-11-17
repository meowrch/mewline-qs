import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services

PanelWindow {
    id: root

    required property var notificationService
    required property PanelWindow barSurface
    // Game Mode is handled by its own surfaces.
    readonly property bool isGameMode: DisplayProfileService.gameModeActive
    // Convex drawer widgets (launcher, clipboard, wallpaper, power menu) are
    // hosted by the ConvexDesktop window (ConvexPanels -> ConvexBottomHost),
    // which holds the keyboard itself while a drawer menu is open. Claiming
    // the keyboard here as well left two OnDemand surfaces and two focus
    // grabs fighting over delivery, and keybind/IPC-opened drawer menus
    // stayed keyboard-dead until they were clicked.
    readonly property bool convexDrawerHandledByDesktop: SettingsService.barConvexMode && AppState.isFocusWidgetOpen
    // While any bar-attached menu (dashboard, calendar, control center, ...)
    // is open this window holds the keyboard and routes keys through the
    // proxy below. Closing is always one step away: Escape bind +
    // click-outside.
    readonly property bool menuKeyboardGrab: !root.isGameMode && AppState.barMenuOpen && !convexDrawerHandledByDesktop
    readonly property bool needsFocus: menuKeyboardGrab

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // WlrLayershell.keyboardFocus is the single source of truth for the
    // keyboard grab. PanelWindow.focusable would race it with an OnDemand
    // mode, which never receives keys until the layer is clicked — that is
    // why keybind-opened menus were dead.
    // Convex attached menus (control center, dashboards): OnDemand +
    // HyprlandFocusGrab — the Caelestia/DMS consensus. Exclusive + grab
    // captures the pointer too (noctalia) and kills every click inside the
    // window. Convex drawer menus are NOT claimed here: ConvexBottomHost
    // flips their host window (ConvexDesktop) to Exclusive while a drawer
    // menu is open.
    WlrLayershell.keyboardFocus: needsFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    focusable: false

    // Keyboard proxy for bar menus. While a menu is open the window holds
    // the keyboard grab; this catcher keeps focus and routes keys:
    //  - Escape closes the menu,
    //  - everything else is forwarded to the open popup's focus item so
    //    arrow navigation (theme/wallpaper/launcher search fields) works
    //    even when the menu was opened by a keybind and nothing inside was
    //    clicked yet.
    Item {
        anchors.fill: parent
        focus: needsFocus && !AppState.barMenuFocusItem

        Keys.forwardTo: AppState.barMenuFocusItem ? [AppState.barMenuFocusItem] : []

        Keys.onEscapePressed: {
            if (AppState.barMenuOpen)
                AppState.closeAllWidgets();

        }
    }

    // Plain Escape bind for the lifetime of any bar menu: closes whatever is
    // open without needing the layer window to hold the keyboard focus.
    // Registered/unregistered as barMenuOpen flips, so the key is untouched
    // the rest of the time.
    Process {
        id: escapeBindProc
    }

    Connections {
        function onBarMenuOpenChanged() {
            if (AppState.barMenuOpen)
                escapeBindProc.command = ["hyprctl", "eval", "hl.bind(\"ESCAPE\", hl.dsp.exec_cmd(\"qs -p " + Quickshell.shellDir + " ipc call barscape esc\"))"];

            else
                escapeBindProc.command = ["hyprctl", "eval", "hl.unbind(\"ESCAPE\")"];

            escapeBindProc.running = false;
            escapeBindProc.running = true;
        }

        target: AppState
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    HyprlandFocusGrab {
        id: surfaceFocusGrab

        // needsFocus (not PanelWindow.focusable) drives the grab: this is
        // what actually hands the keyboard to the bar while a menu is open.
        active: needsFocus
        windows: [root]
    }

    mask: Region {
    }

}
