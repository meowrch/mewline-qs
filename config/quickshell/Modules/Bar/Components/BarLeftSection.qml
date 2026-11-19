import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

Rectangle {
    id: root

    property var mainPanelWidget: null
    property var notificationService: null
    property QtObject mainBar: null
    property real sidePadding: Constants.size3Xl
    property real contentMargin: Constants.sizeLg
    // Tray is hidden behind the chevron: the chevron reveals the tray
    // island next to the workspaces, clicking it again collapses it.
    property bool trayOpen: false
    readonly property real targetWidth: contentRow.implicitWidth + root.sidePadding

    height: parent ? parent.height : implicitHeight
    width: targetWidth
    color: "transparent"

    RowLayout {
        id: contentRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.contentMargin
        spacing: Constants.sizeXs

        // Chevron toggle at the left end: rotates when the tray is open.
        Rectangle {
            id: trayChevron

            readonly property bool isHovered: chevronArea.containsMouse
            readonly property bool isPressed: chevronArea.pressed

            implicitHeight: SettingsService.barWidgetHeight
            implicitWidth: implicitHeight
            width: implicitWidth
            height: implicitHeight
            Layout.preferredHeight: implicitHeight
            Layout.preferredWidth: implicitWidth
            Layout.alignment: Qt.AlignVCenter
            radius: DisplayProfileService.gameModeActive ? 0 : height / 2
            color: isPressed ? Theme.bgTertiary : (isHovered ? Theme.bgTertiary : Theme.bgSecondary)
            scale: isPressed ? 0.95 : (isHovered ? 1.05 : 1)

            SvgIcon {
                anchors.centerIn: parent
                icon: "chevron-down"
                iconSize: Constants.sizeMd
                flat: true
                iconColor: trayChevron.isHovered ? Theme.accent : Theme.fg
                rotation: root.trayOpen ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on iconColor {
                    ColorAnimation {
                        duration: Constants.animFast
                    }

                }

            }

            MouseArea {
                id: chevronArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.trayOpen = !root.trayOpen;
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
                    easing.type: Easing.OutBack
                }

            }

        }

        MewlineButton {
            id: mewlineBtn

            Layout.alignment: Qt.AlignVCenter
        }

        Workspaces {
            id: workspacesWidget

            Layout.alignment: Qt.AlignVCenter
            visible: true
        }

        DeviceBatteryIsland {
            position: "left"
            // Reserve room for the center drawer without reading this section's
            // width: doing so would form a binding loop.
            maxWidth: root.mainBar ? Math.min(180, Math.max(0, root.mainBar.centerX - root.sidePadding - trayChevron.implicitWidth - mewlineBtn.implicitWidth - workspacesWidget.implicitWidth - (root.trayOpen ? trayGroup.implicitWidth : 0) - contentRow.spacing * 5 - 16)) : 128
        }

        // System tray island: revealed next to the workspaces while the
        // chevron is open. The width reveal follows the shell's indicator
        // pattern (animated Layout.preferredWidth + fade, clip keeps the
        // row hidden while collapsed).
        SystemTrayGroup {
            id: trayGroup

            forceHide: false
            hasBackground: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.trayOpen ? trayGroup.implicitWidth : 0
            opacity: root.trayOpen ? 1 : 0
            enabled: root.trayOpen
        }

    }

}
