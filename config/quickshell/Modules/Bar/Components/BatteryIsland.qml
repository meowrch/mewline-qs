import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Battery island (laptops only): charge-state glyph + percentage. Hidden
// entirely on desktop machines (no /sys/class/power_supply/BAT*).
Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed

    // Hidden until the first power poll reports a battery: on desktops
    // hasBattery turns false immediately, so the island never appears.
    visible: SystemInfoService.hasBattery && SystemInfoService._powerInitialized
    color: Theme.bgSecondary
    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
    implicitHeight: SettingsService.barWidgetHeight
    implicitWidth: contentRow.implicitWidth + Constants.sizeSm * 2
    width: implicitWidth
    height: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter
    scale: DisplayProfileService.gameModeActive ? 1 : (isPressed ? 0.95 : (isHovered ? 1.03 : 1))

    // The bolt follows the adapter: charging AND plugged-but-full both count
    // (the user reads "plugged in" as "charging"); only unplugged hides it.
    readonly property bool charging: SystemInfoService.isPluggedIn
    readonly property bool lowBattery: !charging && SystemInfoService.batteryLevel <= 20
    readonly property color fillColor: lowBattery ? (PawletteService.paletteReady && PawletteService.palette.color_red ? PawletteService.palette.color_red : "#ff5c5c") : (charging ? Theme.accent : Theme.fg)

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: Constants.size2Xs

        // Battery glyph drawn in-place (no battery svg asset in the shell):
        // body outline + proportional fill + terminal nub, with a lightning
        // bolt over the fill while the battery is actively charging.
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 22
            implicitHeight: 11
            width: implicitWidth
            height: implicitHeight

            Rectangle {
                id: nub

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 0
                width: 3
                height: 5
                radius: 1
                color: root.lowBattery ? root.fillColor : Theme.muted
            }

            Rectangle {
                id: body

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: parent.width - nub.width - 1
                height: 11
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: root.lowBattery ? root.fillColor : Theme.muted

                Rectangle {
                    id: fill

                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                    radius: 1
                    color: root.fillColor
                    width: Math.max(1.5, Math.min(1, SystemInfoService.batteryLevel / 100) * (body.width - 4))

                    Behavior on width {
                        NumberAnimation {
                            duration: Constants.animNormal
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animNormal
                        }

                    }

                }

                // Lightning bolt while actively charging. QtQuick.Shapes
                // renders nothing in this Quickshell build, so the bolt is a
                // plain SvgIcon overlay (assets/bolt.svg, the same bolt path
                // as charger-filled without the circle badge).
                SvgIcon {
                    anchors.centerIn: parent
                    visible: root.charging
                    icon: "bolt"
                    iconSize: 10
                    flat: true
                    iconColor: Theme.bg
                }

            }

        }

        ThemedText {
            text: SystemInfoService.batteryPercentage
            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
            font.weight: Font.DemiBold
            color: root.lowBattery ? root.fillColor : Theme.fg
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        // Battery limit / power settings live in the control center quick settings.
        onClicked: AppState.toggleWidget("controlCenter")
    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutBack
        }

    }

}
