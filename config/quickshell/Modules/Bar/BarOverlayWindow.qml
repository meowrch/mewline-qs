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
    // Wayland-only mechanics: on X11 the attached menus live in the
    // ConvexDesktop window (which handles its own focus) and Escape comes
    // from the sxhkd bind calling the barscape IPC target.
    readonly property bool menuKeyboardGrab: CompositorService.isWayland && !root.isGameMode && AppState.barMenuOpen && !convexDrawerHandledByDesktop
    readonly property bool needsFocus: menuKeyboardGrab

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    focusable: false
    // OnDemand keyboard through the layer shell while a menu is open — set
    // imperatively (the attached object does not exist on X11).
    onNeedsFocusChanged: Qt.callLater(root.updateWaylandKeyboardFocus)

    function updateWaylandKeyboardFocus() {
        const win = root.QsWindow.window;
        if (!win)
            return ;

        const layershell = win.WlrLayershell;
        if (!layershell)
            return ;

        layershell.keyboardFocus = root.needsFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None;
    }

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
            // The dynamic Escape bind is a Hyprland-only safety net
            // (hyprctl eval); niri and bspwm rely on the layer window
            // keyboard focus + the sxhkd barscape bind respectively.
            if (CompositorService.wm !== "hyprland")
                return ;

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

    // HyprlandFocusGrab is a Hyprland protocol: niri covers menu keyboard
    // focus through the WlrLayershell OnDemand path above.
    Loader {
        active: CompositorService.isHyprland

        sourceComponent: HyprlandFocusGrab {
            // needsFocus (not PanelWindow.focusable) drives the grab: this is
            // what actually hands the keyboard to the bar while a menu is open.
            active: needsFocus
            windows: [root]
        }

    }

    mask: Region {
    }

}
