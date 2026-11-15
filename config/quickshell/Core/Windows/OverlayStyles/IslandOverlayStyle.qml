import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Styles.Convex as ConvexStyle
import qs.Modules.Bar.Styles.Island as IslandStyle
import qs.Modules.Notifications as NotificationsModule

Item {
    id: root

    property var widget
    readonly property bool isOpen: widget ? widget.isOpen : false
    readonly property real preferredWidth: widget ? widget.smoothPreferredWidth : 0
    readonly property real preferredHeight: widget ? widget.smoothPreferredHeight : 0
    readonly property real windowRadius: widget ? widget.smoothWindowRadius : 0
    readonly property real contentPadding: widget ? widget.smoothContentPadding : 0
    readonly property var notificationService: widget ? widget.notificationService : null
    readonly property bool _windowVisible: widget ? widget._windowVisible : false
    readonly property bool forceVisible: widget ? widget.forceVisible : false
    property alias contentSlot: contentLayoutContainer
    property alias container: mainContainer
    property bool isHandover: false
    readonly property real bounceProgress: widget ? widget.bounceProgress : 0

    anchors.fill: parent
    onIsOpenChanged: {
        // Bottom sheets (positionAtBottom widgets) never morph from the bar
        // island: they reveal from the bottom edge exactly like the wallpaper
        // drawer in ConvexBottomHost, so they don't touch the island morph
        // state either.
        if (mainContainer.isBottomSheet)
            return ;

        if (isOpen) {
            handoverTimer.stop();
            isHandover = false;
            AppState.isIslandOpen = true;
            let nw = (AppState.hasActiveNotification && AppState.activeNotificationWidth > 0) ? AppState.activeNotificationWidth : 0;
            let nh = (AppState.hasActiveNotification && AppState.activeNotificationHeight > 0) ? AppState.activeNotificationHeight : 0;
            mainContainer.fromWidth = nw > 0 ? nw : ((AppState.barIslandWidth > 0) ? AppState.barIslandWidth : ((AppState.islandWidth > 0) ? AppState.islandWidth : mainContainer.fromWidth));
            mainContainer.fromHeight = nh > 0 ? nh : ((AppState.barIslandHeight > 0) ? AppState.barIslandHeight : ((AppState.islandHeight > 0) ? AppState.islandHeight : mainContainer.fromHeight));
            mainContainer.fromRadius = nh > 0 ? Constants.sizeSm : mainContainer.fromHeight / 2;
        } else {
            let nw = (AppState.hasActiveNotification && AppState.activeNotificationWidth > 0) ? AppState.activeNotificationWidth : 0;
            let nh = (AppState.hasActiveNotification && AppState.activeNotificationHeight > 0) ? AppState.activeNotificationHeight : 0;
            mainContainer.fromWidth = nw > 0 ? nw : ((AppState.barIslandWidth > 0) ? AppState.barIslandWidth : ((AppState.islandWidth > 0) ? AppState.islandWidth : mainContainer.fromWidth));
            mainContainer.fromHeight = nh > 0 ? nh : ((AppState.barIslandHeight > 0) ? AppState.barIslandHeight : ((AppState.islandHeight > 0) ? AppState.islandHeight : mainContainer.fromHeight));
            mainContainer.fromRadius = nh > 0 ? Constants.sizeSm : mainContainer.fromHeight / 2;
        }
    }

    Connections {
        function onFullyClosed() {
            if (SettingsService.barIslandMode && !widget.positionAtBottom) {
                isHandover = true;
                AppState.isIslandOpen = false;
                if (AppState.activeWidget !== "")
                    AppState.activeWidget = "";

                handoverTimer.restart();
            }
        }

        target: widget
    }

    Timer {
        id: handoverTimer

        interval: 60
        repeat: false
        onTriggered: {
            isHandover = false;
        }
    }

    Item {
        id: mainContainer

        // Bottom sheets are standalone fullscreen windows (positionAtBottom
        // widgets like the theme selector) that must render exactly like the
        // wallpaper drawer hosted by ConvexBottomHost: a ConvexDrawerShape on
        // the bottom edge, full width immediately, growing upward from just
        // above the screen edge. No width morph, no pill radius, ever.
        readonly property bool isBottomSheet: widget ? widget.positionAtBottom : false
        // Same corner radius ConvexBottomHost uses for full (non-compact)
        // drawers. The drawer shape inlays its straight sides by this radius,
        // so content windows must compensate for it in their preferred width.
        readonly property real drawerRadius: Constants.sizeLg * 2

        readonly property real notifW: (AppState.hasActiveNotification && AppState.activeNotificationWidth > 0) ? AppState.activeNotificationWidth : 0
        readonly property real notifH: (AppState.hasActiveNotification && AppState.activeNotificationHeight > 0) ? AppState.activeNotificationHeight : 0
        property real fromWidth: notifW > 0 ? notifW : ((AppState.barIslandWidth > 0) ? AppState.barIslandWidth : ((AppState.islandWidth > 0) ? AppState.islandWidth : 180))
        property real fromHeight: notifH > 0 ? notifH : ((AppState.barIslandHeight > 0) ? AppState.barIslandHeight : ((AppState.islandHeight > 0) ? AppState.islandHeight : Constants.islandBarHeight))
        property real fromRadius: notifH > 0 ? Constants.sizeXl : fromHeight / 2
        readonly property real currentWidth: isBottomSheet ? Math.round(preferredWidth) : Math.round(fromWidth + (preferredWidth - fromWidth) * bounceProgress)
        // Bottom sheets grow from the bottom edge with the shared progress
        // curve, like ConvexBottomHost's contentContainer
        // (currentHeight = height * openProgress).
        readonly property real currentHeight: isBottomSheet ? Math.max(preferredHeight * bounceProgress, 0.01) : Math.round(fromHeight + (preferredHeight - fromHeight) * bounceProgress)
        readonly property real currentRadius: isBottomSheet ? drawerRadius : Math.round(fromRadius + (windowRadius - fromRadius) * bounceProgress)

        width: currentWidth
        height: currentHeight
        anchors.horizontalCenter: parent.horizontalCenter
        // The bottom edge stays pinned just above the screen edge (same gap
        // as ConvexBottomHost's bezelSize margin) while the height grows
        // upward; island popups hang below the bar as before.
        y: isBottomSheet ? Math.round(parent.height - currentHeight - Constants.sizeLg) : 8
        clip: isBottomSheet
        opacity: (_windowVisible || isHandover || forceVisible) ? 1 : 0

        // Bottom sheets draw the exact same drawer background as the
        // wallpaper selector's ConvexBottomHost: rounded top corners, flat
        // flare toward the screen bottom, no border, no shadow, no capsule.
        Loader {
            anchors.fill: parent
            active: mainContainer.isBottomSheet

            sourceComponent: ConvexStyle.ConvexDrawerShape {
                color: widget ? widget.backgroundColor : Theme.bg
                cornerRadius: mainContainer.drawerRadius
                edge: Qt.BottomEdge
                enableShadow: false
            }

        }

        IslandStyle.IslandBackground {
            anchors.fill: parent
            visible: !mainContainer.isBottomSheet
            radius: mainContainer.currentRadius
            enableShadow: SettingsService.barIslandMode && !isHandover
        }

        Item {
            id: notifSlotHolder

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: (AppState.hasActiveNotification && AppState.activeNotificationWidth > 0) ? AppState.activeNotificationWidth : parent.width
            height: (AppState.hasActiveNotification && AppState.activeNotificationHeight > 0) ? AppState.activeNotificationHeight : 76
            clip: true
            visible: AppState.hasActiveNotification && opacity > 0.001
            opacity: (AppState.hasActiveNotification && !isOpen) ? (isHandover ? 1 : Math.min(1, Math.max(0, (1 - bounceProgress) / 0.7))) : 0
            transformOrigin: Item.Top

            NotificationsModule.NotificationDelegateContent {
                anchors.fill: parent
                notifData: (notificationService && notificationService.activeList && notificationService.activeList.count > 0) ? notificationService.activeList.get(0).notifData : null
            }

        }

        Item {
            id: barSlotHolder

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: mainContainer.fromWidth
            height: mainContainer.fromHeight
            clip: true
            visible: !AppState.hasActiveNotification && opacity > 0.001
            opacity: AppState.hasActiveNotification ? 0 : (isHandover ? 1 : (!isOpen ? Math.min(1, Math.max(0, (1 - bounceProgress) / 0.7)) : 0))
            transformOrigin: Item.Top

            QtObject {
                id: dummyIslandBar

                property string activeBarStyle: "island"
                property bool isExpanded: false
            }

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
            anchors.leftMargin: contentPadding + (mainContainer.isBottomSheet ? mainContainer.drawerRadius : 0)
            anchors.rightMargin: contentPadding + (mainContainer.isBottomSheet ? mainContainer.drawerRadius : 0)
            anchors.topMargin: contentPadding
            anchors.bottomMargin: contentPadding
            // Bottom sheets keep the content at its final size pinned to the
            // drawer bottom (ConvexBottomHost pins its loader above the same
            // margin) and the growing container reveals it upward. Island
            // mode fills the morphing container as before.
            height: mainContainer.isBottomSheet ? Math.max(0, preferredHeight - contentPadding * 2) : (parent.height - contentPadding * 2)
            // island mode anchors only bottom (height drives position); top
            // anchor is a no-op there because height is pinned to the parent
            // minus margins
            clip: true
            transformOrigin: mainContainer.isBottomSheet ? Item.Bottom : Item.Top
            opacity: !isOpen ? Math.min(1, Math.max(0, (bounceProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (bounceProgress - 0.2) / 0.8))
            scale: !isOpen ? (0.94 + 0.06 * Math.min(1, Math.max(0, (bounceProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (bounceProgress - 0.15) / 0.85)))
        }

    }

}
