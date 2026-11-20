import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

PanelWindow {
    id: root

    required property var notificationService
    property bool isShellReady: false
    property string activeBarStyle: "convex"
    // The cached settings are read asynchronously, so barStyle still holds its
    // "convex" default for the first frames. Require settingsLoaded so the
    // convex surface (content and mask) never flashes before the saved style
    // is known.
    readonly property bool isConvexMode: SettingsService.settingsLoaded && SettingsService.barConvexMode && !DisplayProfileService.gameModeActive
    readonly property bool isExiting: !isConvexMode
    property int barHeight: BarStyleConfig.barHeight("convex")
    property real animatedBarHeight: barHeight
    property int bezelSize: Constants.sizeXs
    property bool hasFullscreen: CompositorService.hasFullscreen
    property real fsTransitionProg: hasFullscreen ? 0 : 1
    // Wayland: only the drawer menus (focus widgets) claim the keyboard
    // here — attached menus are handled by the BarOverlayWindow proxy.
    // X11: this window hosts ALL convex menus, so any open menu makes it
    // the keyboard owner (dock windows never receive keys from a keybind
    // without an explicit activation).
    readonly property bool waylandNeedsFocus: root.isConvexMode && AppState.isFocusWidgetOpen && convexPanels.hasAnyDrawerOpen
    readonly property bool needsFocus: CompositorService.isX11 ? (root.isConvexMode && !DisplayProfileService.gameModeActive && AppState.barMenuOpen) : root.waylandNeedsFocus

    function triggerStyleSwitch() {
        root.activeBarStyle = SettingsService.barStyle;
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: needsFocus
    color: "transparent"
    // The keyboard claim of the drawer host: Exclusive through the layer
    // shell on Wayland (re-asserted after the focusable write lands, see
    // ConvexBottomHost), an explicit X11 activation (xdotool SetInputFocus)
    // on bspwm, plus capture/restore of the previously focused node.
    onNeedsFocusChanged: {
        if (CompositorService.isX11) {
            if (root.needsFocus) {
                CompositorService.captureFocus();
                activateTimer.restart();
            } else {
                CompositorService.restoreFocus();
            }
        } else {
            Qt.callLater(root.updateWaylandKeyboardFocus);
        }
    }

    function updateWaylandKeyboardFocus() {
        const win = root.QsWindow.window;
        if (!win)
            return ;

        const layershell = win.WlrLayershell;
        if (!layershell)
            return ;

        layershell.keyboardFocus = root.needsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None;
    }

    Timer {
        id: activateTimer

        interval: 50
        repeat: false
        onTriggered: {
            // requestActivate alone cannot reach an unmanaged dock window
            // (nobody answers the ICCCM activation request on bspwm) — the
            // direct SetInputFocus through the tagged name does.
            CompositorService.activateWindowByTitle("mewline-drawers");
        }
    }

    Component.onCompleted: {
        activeBarStyle = SettingsService.barStyle;
        Qt.callLater(() => {
            isShellReady = true;
        });
    }

    // X11: Escape closes whatever bar menu / drawer is open. The window owns
    // the X keyboard while a menu is open (needsFocus → explicit activation),
    // and a window-level Shortcut catches Escape regardless of which item
    // holds Qt focus — the per-host Keys handlers only receive it after a
    // click focuses them. On Wayland BarOverlayWindow registers a compositor
    // Escape bind instead, so this stays X11-only.
    Shortcut {
        sequence: "Escape"
        enabled: CompositorService.isX11 && root.isConvexMode && AppState.barMenuOpen
        onActivated: AppState.closeAllWidgets()
    }
    onVisibleChanged: {
        if (visible && SettingsService.barStyle === "convex") {
            shellFrameContainer.enableTransitionAnim = false;
            root.activeBarStyle = "convex";
            barContainer.switchOpacity = 1;
            barContainer.scale = 1;
            convexBarTranslate.y = 0;
        }
    }

    Connections {
        function onSettingsLoadedChanged() {
            if (SettingsService.settingsLoaded)
                root.activeBarStyle = SettingsService.barStyle;

        }

        function onBarStyleChanged() {
            root.triggerStyleSwitch();
        }

        target: SettingsService
    }

    Process {
        id: slurpCheckProcess

        command: ["sh", "-c", "pidof slurp"]
        onExited: {
            if (exitCode !== 0) {
                if (AppState.activeWidget !== "")
                    AppState.activeWidget = "";

            }
        }
    }

    // HyprlandFocusGrab is a Hyprland protocol; on niri the window holds
    // the keyboard through WlrLayershell keyboardFocus, on X11 through the
    // explicit activation above.
    Loader {
        active: CompositorService.isHyprland

        sourceComponent: HyprlandFocusGrab {
            id: surfaceFocusGrab

            active: root.focusable
            windows: [root]
            onCleared: {
                slurpCheckProcess.running = true;
            }
        }

    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ConvexExclusions {
        hasFullscreen: root.hasFullscreen
        barHeight: root.barHeight
        bezelSize: root.bezelSize
        isExiting: root.isExiting
    }

    Item {
        id: unifiedShadowGroup

        anchors.fill: parent
        opacity: root.isConvexMode ? 1 : 0
        visible: root.isConvexMode || opacity > 0.001
        layer.enabled: HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.powerProfile !== "power-saver")

        ConvexPanels {
            id: convexPanels

            z: 1
            anchors.fill: parent
            barHeight: root.barHeight
            bezelSize: root.bezelSize
            notificationService: root.notificationService
        }

        ConvexFrameBezel {
            id: shellFrameContainer

            z: 10
            hasFrame: true
            isShellReady: root.isShellReady
            barHeight: Math.round(root.animatedBarHeight)
            activeBarStyle: root.activeBarStyle
            bezelSize: root.bezelSize
            fsTransitionProg: root.fsTransitionProg
        }

        Item {
            id: barContainer

            property QtObject activeItem: convexLoader.item
            property real switchOpacity: 1

            z: 20
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: (activeItem && (activeItem.centerHeight || 0) > root.barHeight) ? activeItem.centerHeight : root.barHeight
            transformOrigin: Item.Top
            opacity: root.fsTransitionProg * switchOpacity
            visible: opacity > 0.01
            transform: [
                Translate {
                    id: convexBarTranslate

                    y: 0
                }
            ]

            Loader {
                id: convexLoader

                anchors.fill: parent
                active: true
                visible: true
                source: "ConvexBar.qml"
                onLoaded: {
                    if (item) {
                        item.notificationService = root.notificationService;
                        item.mainPanelWidget = Qt.binding(() => {
                            return convexPanels.dashboardWidget;
                        });
                        item.controlCenterWidget = Qt.binding(() => {
                            return convexPanels.controlCenterWidget;
                        });
                        item.notificationsCenterWidget = Qt.binding(() => {
                            return convexPanels.notificationsCenterWidget;
                        });
                    }
                }
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, Theme.isDark ? 1 : Math.min(1, Theme.shadow.a * 1.6))
            blurMax: HyprlandService.hyprShadowRange
            shadowBlur: 1
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }

    }

    Behavior on fsTransitionProg {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.InOutCubic
        }

    }

    mask: Region {
        // Top border + Bar
        Region {
            x: 0
            y: 0
            width: root.isConvexMode ? root.width : 0
            height: root.isConvexMode ? (root.barHeight * root.fsTransitionProg) : 0
        }

        // Left border
        Region {
            x: 0
            y: root.barHeight * root.fsTransitionProg
            width: root.isConvexMode ? (root.bezelSize * root.fsTransitionProg) : 0
            height: root.isConvexMode ? root.height : 0
        }

        // Right border
        Region {
            x: root.width - (root.bezelSize * root.fsTransitionProg)
            y: root.barHeight * root.fsTransitionProg
            width: root.isConvexMode ? (root.bezelSize * root.fsTransitionProg) : 0
            height: root.isConvexMode ? root.height : 0
        }

        // Bottom border
        Region {
            x: root.bezelSize * root.fsTransitionProg
            y: root.height - (root.bezelSize * root.fsTransitionProg)
            width: root.isConvexMode ? (root.width - (2 * root.bezelSize * root.fsTransitionProg)) : 0
            height: root.isConvexMode ? (root.bezelSize * root.fsTransitionProg) : 0
        }

        // X11: the mask is also the window's visual shape there (picom paints
        // only what is inside it), so the bezel's rounded corner fills — which
        // reach bezelSize + innerRadius past the screen edges — must be part
        // of the mask or they get clipped to the thin strips and the screen
        // corners look square until a panel opens (the panels overlay region
        // then unclips the whole window). On Wayland the mask only routes
        // input and the corners must stay click-through, hence the isX11 gate.
        Region {
            id: x11CornerMask

            readonly property bool on: CompositorService.isX11 && root.isConvexMode
            readonly property real extent: (root.bezelSize + Constants.size4Xl) * root.fsTransitionProg

            // Top corners, hanging from the bar line
            Region {
                x: 0
                y: root.barHeight * root.fsTransitionProg
                width: x11CornerMask.on ? x11CornerMask.extent : 0
                height: x11CornerMask.on ? Constants.size4Xl * root.fsTransitionProg : 0
            }

            Region {
                x: root.width - (x11CornerMask.on ? x11CornerMask.extent : 0)
                y: root.barHeight * root.fsTransitionProg
                width: x11CornerMask.on ? x11CornerMask.extent : 0
                height: x11CornerMask.on ? Constants.size4Xl * root.fsTransitionProg : 0
            }

            // Bottom corners, spanning the strip and the inner rounding
            Region {
                x: 0
                y: root.height - (x11CornerMask.on ? x11CornerMask.extent : 0)
                width: x11CornerMask.on ? x11CornerMask.extent : 0
                height: x11CornerMask.on ? x11CornerMask.extent : 0
            }

            Region {
                x: root.width - (x11CornerMask.on ? x11CornerMask.extent : 0)
                y: root.height - (x11CornerMask.on ? x11CornerMask.extent : 0)
                width: x11CornerMask.on ? x11CornerMask.extent : 0
                height: x11CornerMask.on ? x11CornerMask.extent : 0
            }
        }

        // Active Panels Overlay (Full Screen for Clicks/Focus)
        Region {
            property bool isActive: root.isConvexMode && (convexPanels.hasAnyPanelOpen || convexPanels.isConvexCenterOpen)

            x: 0
            y: 0
            width: isActive ? root.width : 0
            height: isActive ? root.height : 0
        }

        // Convex Center Notch Expanded Region
        Region {
            readonly property bool isConvexExpanded: root.activeBarStyle === "convex" && barContainer.activeItem && (barContainer.activeItem.centerHeight > root.barHeight)
            readonly property real cX: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerX || 0) : 0
            readonly property real cW: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerWidth || 0) : 0
            readonly property real cH: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerHeight || 0) : 0

            x: isConvexExpanded ? (cX - 8) : 0
            y: 0
            width: isConvexExpanded ? (cW + 16) : 0
            height: isConvexExpanded ? (cH + 16) : 0
        }

    }

}
