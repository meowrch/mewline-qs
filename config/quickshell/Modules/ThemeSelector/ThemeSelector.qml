import QtQuick
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Windows

OverlayWindow {
    id: root

    // The window is mapped fresh on every open, so an exclusive keyboard
    // grab is granted immediately and arrow navigation works without any
    // prior click.
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    widgetId: "pawlette"
    enableShadow: true
    positionAtBottom: true
    preferredWidth: content.implicitWidth + (contentPadding * 2)
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
