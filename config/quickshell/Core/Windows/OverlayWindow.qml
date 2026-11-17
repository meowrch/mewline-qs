import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Styles.Convex

PanelWindow {
    id: root

    property var notificationService: null
    property string widgetId: ""
    property bool isOpen: false
    property Item initialFocusItem: null
    property bool exclusive: true
    // We bind the external content to our inner content holder
    default property alias content: innerContentHolder.data
    property int animationDuration: HyprlandService.enableAnimations ? Constants.animSlow : 0
    readonly property int closeDuration: HyprlandService.enableAnimations ? Constants.animNormal : 0
    property int fadeDuration: HyprlandService.enableAnimations ? Constants.animNormal : 0
    property color backgroundColor: Theme.bg
    property int preferredWidth: (innerContentHolder.children.length > 0 && innerContentHolder.children[0].implicitWidth > 0) ? (innerContentHolder.children[0].implicitWidth + contentPadding * 2) : 600
    property int preferredHeight: (innerContentHolder.children.length > 0 && innerContentHolder.children[0].implicitHeight > 0) ? (innerContentHolder.children[0].implicitHeight + contentPadding * 2) : 500
    property real smoothPreferredWidth: preferredWidth
    property real smoothPreferredHeight: preferredHeight
    property bool positionAtBottom: false
    property bool _windowVisible: false
    property bool forceVisible: false
    property int contentPadding: Constants.sizeLg
    property int windowRadius: Constants.size3Xl
    property bool enableShadow: false
    property real smoothWindowRadius: windowRadius
    property real smoothContentPadding: contentPadding
    property real openProgress: root.isOpen ? 1 : 0
    property real bounceProgress: root.isOpen ? 1 : 0
    property bool windowFocusable: true
    // Bottom sheets (positionAtBottom widgets) render as a ConvexDesktop-style
    // drawer on the bottom edge; anything else floats as a rounded panel.
    readonly property bool isBottomSheet: positionAtBottom
    // Same corner radius ConvexBottomHost uses for full (non-compact)
    // drawers. The drawer shape inlays its straight sides by this radius,
    // so content windows must compensate for it in their preferred width.
    readonly property real drawerRadius: Constants.sizeLg * 2

    signal widgetOpened()
    signal widgetClosed()
    signal fullyClosed()

    function finishClosing() {
        closeDelayTimer.stop();
        root._windowVisible = false;
        root.fullyClosed();
    }

    function close() {
        isOpen = false;
    }

    // Distinct title so the X11 session can address this window (focus
    // activation + bspwm window rules).
    surfaceFormat.opaque: false
    color: "transparent"
    focusable: root.isOpen && root.windowFocusable
    exclusionMode: ExclusionMode.Ignore
    visible: _windowVisible || forceVisible
    onIsOpenChanged: {
        // X11: dock windows never get keyboard from a fresh mapping alone —
        // capture the focused node, then hand the keyboard over explicitly.
        if (CompositorService.isX11 && root.windowFocusable) {
            if (root.isOpen) {
                CompositorService.captureFocus();
                x11ActivateTimer.restart();
            } else {
                CompositorService.restoreFocus();
            }
        }
        if (widgetId === "")
            return ;

        if (widgetId === "")
            return ;

        if (isOpen) {
            closeDelayTimer.stop();
            if (exclusive && !AppState.isWidgetOpen(widgetId))
                AppState.openWidget(widgetId);

            _windowVisible = true;
            root.widgetOpened();
            if (root.initialFocusItem)
                initialFocusTimer.start();

        } else {
            let anotherFocusOpen = AppState.isFocusWidgetOpen && !AppState.isWidgetOpen(widgetId);
            if (exclusive && anotherFocusOpen) {
                closeDelayTimer.stop();
                _windowVisible = false;
                root.widgetClosed();
                root.fullyClosed();
            } else {
                closeDelayTimer.start();
                root.widgetClosed();
            }
        }
    }
    onInitialFocusItemChanged: {
        if (isOpen && windowFocusable && initialFocusItem)
            initialFocusTimer.restart();

    }
    onWindowFocusableChanged: {
        if (isOpen && windowFocusable && initialFocusItem)
            initialFocusTimer.restart();

    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.isOpen
        onClicked: root.isOpen = false
    }

    Timer {
        id: closeDelayTimer

        interval: Constants.durationFactor > 0 ? Constants.animExpressive : 10
        repeat: false
        onTriggered: {
            if (exclusive && AppState.isWidgetOpen(widgetId))
                AppState.closeWidget(widgetId);

            root.finishClosing();
        }
    }

    Timer {
        id: x11ActivateTimer

        interval: 50
        repeat: false
        onTriggered: {
            // Sheets are created on demand and cannot be pre-tagged: the
            // newest shell window is always the sheet being opened.
            CompositorService.activateNewestShellWindow();
        }
    }

    Timer {
        id: initialFocusTimer

        interval: 30
        repeat: false
        onTriggered: {
            if (root.windowFocusable && root.initialFocusItem) {
                if (root.initialFocusItem.textField)
                    root.initialFocusItem.textField.forceActiveFocus();
                else
                    root.initialFocusItem.forceActiveFocus();
            }
        }
    }

    // The content holder anchors inside the visible container below
    Item {
        id: innerContentHolder

        parent: contentLayoutContainer
        anchors.fill: parent
        // Forward keys to the focused item
        Keys.forwardTo: (root.windowFocusable && root.initialFocusItem) ? [root.initialFocusItem] : []
        Keys.enabled: root.isOpen && root.windowFocusable
        Keys.onEscapePressed: {
            if (root.windowFocusable)
                root.isOpen = false;

        }
    }

    Item {
        id: mainContainer

        readonly property real currentWidth: isBottomSheet ? Math.round(root.smoothPreferredWidth) : Math.round(root.smoothPreferredWidth)
        // Bottom sheets grow from the bottom edge with the shared progress
        // curve, like ConvexBottomHost's contentContainer
        // (currentHeight = height * openProgress).
        readonly property real currentHeight: isBottomSheet ? Math.max(root.smoothPreferredHeight * root.bounceProgress, 0.01) : Math.round(root.smoothPreferredHeight)

        width: currentWidth
        height: currentHeight
        anchors.horizontalCenter: parent.horizontalCenter
        // The bottom edge stays pinned to the screen border while the height
        // grows upward; floating panels hang from the top.
        y: isBottomSheet ? Math.round(parent.height - currentHeight) : 8
        clip: isBottomSheet
        opacity: (root._windowVisible || root.forceVisible) ? 1 : 0

        // Bottom sheets draw the exact same drawer background as the
        // wallpaper selector's ConvexBottomHost: rounded top corners, flat
        // flare toward the screen bottom, no border, no shadow, no capsule.
        ConvexDrawerShape {
            anchors.fill: parent
            visible: root.isBottomSheet
            color: root.backgroundColor
            cornerRadius: root.drawerRadius
            edge: Qt.BottomEdge
            enableShadow: false
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.isBottomSheet
            color: root.backgroundColor
            radius: root.smoothWindowRadius
            border.width: 1
            border.color: Theme.border
        }

        // Prevent clicks on the container from reaching the dismiss area
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: contentLayoutContainer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: parent.top
            anchors.leftMargin: root.contentPadding + (root.isBottomSheet ? root.drawerRadius : 0)
            anchors.rightMargin: root.contentPadding + (root.isBottomSheet ? root.drawerRadius : 0)
            anchors.topMargin: root.contentPadding
            anchors.bottomMargin: root.contentPadding
            // Bottom sheets keep the content at its final size pinned to the
            // drawer bottom (ConvexBottomHost pins its loader above the same
            // margin) and the growing container reveals it upward.
            height: root.isBottomSheet ? Math.max(0, root.smoothPreferredHeight - root.contentPadding * 2) : (parent.height - root.contentPadding * 2)
            clip: true
            transformOrigin: root.isBottomSheet ? Item.Bottom : Item.Top
            opacity: !root.isOpen ? Math.min(1, Math.max(0, (root.bounceProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (root.bounceProgress - 0.2) / 0.8))
            scale: !root.isOpen ? (0.94 + 0.06 * Math.min(1, Math.max(0, (root.bounceProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (root.bounceProgress - 0.15) / 0.85)))
        }

    }

    mask: Region {
        Region {
            x: root.isOpen ? 0 : mainContainer.x
            y: root.isOpen ? 0 : mainContainer.y
            width: root.isOpen ? root.width : mainContainer.width
            height: root.isOpen ? root.height : mainContainer.height
        }

    }

    Behavior on smoothPreferredWidth {
        enabled: HyprlandService.enableAnimations && root.isOpen

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPreferredHeight {
        enabled: HyprlandService.enableAnimations && root.isOpen

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothWindowRadius {
        enabled: HyprlandService.enableAnimations && root.isOpen

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothContentPadding {
        enabled: HyprlandService.enableAnimations && root.isOpen

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

    Behavior on openProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: root.isOpen ? root.fadeDuration : root.closeDuration
            easing.type: root.isOpen ? Easing.OutCubic : Easing.InCubic
        }

    }

    Behavior on bounceProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            // Bottom sheets use the ConvexBottomHost drawer physics:
            // expressive OutQuint on open, normal OutCubic on close. Plain
            // floating popups keep their own curves.
            duration: root.positionAtBottom ? (root.isOpen ? Constants.animExpressive : Constants.animNormal) : (root.isOpen ? Constants.animNormal : Constants.animNormal)
            easing.type: root.positionAtBottom ? (root.isOpen ? Easing.OutQuint : Easing.OutCubic) : (root.isOpen ? Easing.OutCubic : Easing.InCubic)
        }

    }

}
