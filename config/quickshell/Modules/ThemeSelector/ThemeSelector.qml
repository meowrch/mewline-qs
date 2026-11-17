import QtQuick
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Windows

OverlayWindow {
    id: root

    // The window is mapped fresh on every open, so an exclusive keyboard
    // grab is granted immediately and arrow navigation works without any
    // prior click. Imperative (not a binding): WlrLayershell does not exist
    // on X11, where OverlayWindow activates the window explicitly instead.
    onIsOpenChanged: Qt.callLater(root.updateKeyboardFocus)

    function updateKeyboardFocus() {
        if (CompositorService.isX11)
            return ;

        const win = root.QsWindow.window;
        if (!win)
            return ;

        const layershell = win.WlrLayershell;
        if (!layershell)
            return ;

        layershell.keyboardFocus = root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    widgetId: "pawlette"
    positionAtBottom: true
    // Drawer geometry identical to ConvexBottomHost for full (non-compact)
    // widgets: the ConvexDrawerShape inlays its straight sides by
    // cornerRadius, so the window adds cornerRadius * 2 around the content
    // (the host's safeMarginX = cornerRadius * 2 + contentPadding * 2).
    readonly property int drawerCornerRadius: Constants.sizeLg * 2
    preferredWidth: content.implicitWidth + (contentPadding * 2) + (drawerCornerRadius * 2)
    preferredHeight: content.implicitHeight + (contentPadding * 2)
    initialFocusItem: content.initialFocusItem
    onWidgetOpened: {
        content.resetSelector();
    }

    ThemeSelectorContent {
        id: content

        widget: root
    }

}
