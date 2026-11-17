import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils

Item {
    id: root

    property color bgColor: Theme.bgSecondary
    property bool compact: false
    property int customHeight: compact ? 20 : SettingsService.barWidgetHeight
    property real containerPadding: compact ? 8 : 10
    property int dotSpacing: compact ? 5 : 6
    readonly property int dotHeight: compact ? 6 : 8
    readonly property int activePillWidth: compact ? 18 : 24
    // State comes from the compositor abstraction layer (Hyprland on
    // Wayland, BspwmService's report backend on X11).
    readonly property int activeWsId: CompositorService.focusedWorkspaceId
    readonly property var workspaceStates: CompositorService.workspaces
    readonly property int maxOccupiedWsId: {
        let maxId = 1;
        for (let i = 0; i < workspaceStates.length; i++) {
            const ws = workspaceStates[i];
            if (!ws || !ws.occupied)
                continue;

            const id = parseInt(ws.name);
            if (!isNaN(id) && id > maxId)
                maxId = id;

        }
        return Math.max(maxId, root.activeWsId);
    }
    readonly property int visibleWorkspaceCount: Math.min(SettingsService.numberOfWorkspaces, Math.max(Math.max(activeWsId, maxOccupiedWsId) + 1, 5))

    function handleWheel(wheel) {
        const currentId = root.activeWsId;
        const targetId = wheel.angleDelta.y > 0 ? (currentId - 1) : (currentId + 1);
        if (targetId >= 1 && targetId <= 10)
            CompositorService.switchWorkspace(targetId);

    }

    implicitHeight: customHeight
    height: customHeight
    Layout.preferredHeight: customHeight
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: Math.round(hLayout.implicitWidth + (root.bgColor === "transparent" ? 0 : (containerPadding * 2)))
    width: implicitWidth

    Rectangle {
        id: bgContainer

        anchors.fill: parent
        color: root.bgColor
        radius: DisplayProfileService.gameModeActive ? 0 : height / 2
        visible: root.bgColor !== "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Constants.animFast
            }

        }

    }

    MouseArea {
        id: wheelArea

        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            return root.handleWheel(wheel);
        }
    }

    Row {
        id: hLayout

        anchors.centerIn: parent
        spacing: root.dotSpacing

        Repeater {
            model: SettingsService.numberOfWorkspaces

            Item {
                id: wsSlot

                readonly property int wsId: index + 1
                readonly property bool isActive: root.activeWsId === wsSlot.wsId
                readonly property bool isVisibleSlot: wsId <= root.visibleWorkspaceCount
                readonly property bool hasWindows: {
                    for (let i = 0; i < root.workspaceStates.length; i++) {
                        const ws = root.workspaceStates[i];
                        if (ws && parseInt(ws.name) === wsSlot.wsId && ws.occupied)
                            return true;

                    }
                    return false;
                }
                readonly property bool isHovered: mouseAreaH.containsMouse

                visible: opacity > 0.001
                opacity: isVisibleSlot ? 1 : 0
                height: root.dotHeight
                width: isActive ? root.activePillWidth : root.dotHeight

                Rectangle {
                    id: dotItem

                    anchors.centerIn: parent
                    height: root.dotHeight
                    width: parent.width
                    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
                    color: {
                        if (wsSlot.isActive)
                            return Theme.accent;

                        if (wsSlot.hasWindows)
                            return wsSlot.isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.95) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65);

                        return wsSlot.isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22);
                    }
                    scale: mouseAreaH.pressed ? 0.85 : (wsSlot.isHovered && !wsSlot.isActive ? 1.2 : 1)

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animFast
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                }

                MouseArea {
                    id: mouseAreaH

                    anchors.centerIn: parent
                    width: Math.max(parent.width, 14)
                    height: Math.max(parent.height, 18)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: CompositorService.switchWorkspace(wsSlot.wsId)
                    onWheel: (wheel) => {
                        return root.handleWheel(wheel);
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                    }

                }

            }

        }

    }

}
