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
    // "numbers" replaces the dots with mini capsules showing the slot number.
    readonly property bool numbersMode: SettingsService.workspaceDisplayMode === "numbers"
    readonly property int capsuleHeight: compact ? 16 : 20
    readonly property int capsuleMinWidth: compact ? 16 : 20
    readonly property int capsulePadding: compact ? 8 : 10
    // Extra width for the focused slot, so it reads as a pill rather than
    // a circle even for single-digit workspaces.
    readonly property int activeCapsuleExtra: compact ? 10 : 18
    // State comes from the compositor abstraction layer (Hyprland on
    // Wayland, BspwmService's report backend on X11).
    readonly property int activeWsId: CompositorService.focusedWorkspaceId
    readonly property var workspaceStates: CompositorService.workspaces

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
        spacing: root.numbersMode ? (root.compact ? 3 : 4) : root.dotSpacing

        Repeater {
            model: SettingsService.numberOfWorkspaces

            Item {
                id: wsSlot

                readonly property int wsId: index + 1
                readonly property bool isActive: root.activeWsId === wsSlot.wsId
                readonly property bool hasWindows: {
                    for (let i = 0; i < root.workspaceStates.length; i++) {
                        const ws = root.workspaceStates[i];
                        if (ws && parseInt(ws.name) === wsSlot.wsId && ws.occupied)
                            return true;

                    }
                    return false;
                }
                // Only occupied workspaces and the focused one are shown;
                // empty slots stay hidden until they get a window or focus.
                readonly property bool isVisibleSlot: isActive || hasWindows
                readonly property bool isHovered: mouseAreaH.containsMouse

                visible: opacity > 0.001
                opacity: isVisibleSlot ? 1 : 0
                height: root.numbersMode ? root.capsuleHeight : root.dotHeight
                width: root.numbersMode ? (Math.max(root.capsuleMinWidth, wsNumber.implicitWidth + root.capsulePadding) + (isActive ? root.activeCapsuleExtra : 0)) : (isActive ? root.activePillWidth : root.dotHeight)

                Rectangle {
                    id: dotItem

                    anchors.centerIn: parent
                    height: parent.height
                    width: parent.width
                    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
                    border.width: root.numbersMode && !wsSlot.isActive ? 1 : 0
                    border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
                    color: {
                        if (wsSlot.isActive)
                            return Theme.accent;

                        if (root.numbersMode) {
                            // Capsules: a faint tint so the number stays legible.
                            const alpha = wsSlot.isHovered ? 0.22 : 0.12;
                            return Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, alpha);
                        }

                        if (wsSlot.hasWindows)
                            return wsSlot.isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.95) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65);

                        return wsSlot.isHovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22);
                    }
                    scale: mouseAreaH.pressed ? 0.9 : (wsSlot.isHovered && !wsSlot.isActive ? (root.numbersMode ? 1.06 : 1.2) : 1)

                    ThemedText {
                        id: wsNumber

                        anchors.centerIn: parent
                        visible: root.numbersMode
                        text: wsSlot.wsId
                        customSize: root.compact ? 8 : 10
                        font.weight: wsSlot.isActive ? Font.Bold : Font.Medium
                        color: wsSlot.isActive ? Theme.bg : (wsSlot.isHovered ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.8))

                        Behavior on color {
                            ColorAnimation {
                                duration: Constants.animFast
                            }

                        }

                    }

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
