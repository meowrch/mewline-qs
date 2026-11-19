import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import "../../../Core/Utils/DeviceBattery.js" as DeviceBattery

// A separate peripheral island, not another symbol inside the workspace strip.
Rectangle {
    id: root

    property string position: "left"
    property real maxWidth: 128
    readonly property bool enabledHere: SettingsService.deviceBatteryPosition === position
    // Large fonts/narrow slots fall back to icons rather than an unreadable +1.
    readonly property bool showPercent: SettingsService.deviceBatteryShowPercent && maxWidth >= Math.round(62 * SettingsService.fontScale) + 14 + (DeviceBatteryService.devices.length > 1 ? 28 : 0)
    readonly property real cellWidth: showPercent ? Math.round(62 * SettingsService.fontScale) : Math.round(26 * SettingsService.fontScale)
    readonly property var arrangement: DeviceBattery.layout(enabledHere ? DeviceBatteryService.devices : [], maxWidth, cellWidth, 7, 4)
    readonly property var shownDevices: arrangement.shown
    readonly property var hiddenDevices: arrangement.hidden

    implicitWidth: arrangement.width
    implicitHeight: SettingsService.barWidgetHeight
    width: implicitWidth
    height: implicitHeight
    visible: implicitWidth > 0
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignVCenter
    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
    color: Theme.bgSecondary
    border.width: DisplayProfileService.gameModeActive ? 1 : 0
    border.color: Theme.border

    Row {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.shownDevices

            delegate: Rectangle {
                id: deviceCell
                required property var modelData
                readonly property bool low: modelData.percent >= 0 && modelData.percent <= 15 && !modelData.charging && !modelData.asleep
                readonly property color statusColor: low ? (PawletteService.paletteReady && PawletteService.palette.color_red ? PawletteService.palette.color_red : "#ff5c5c") : (modelData.charging ? Theme.accent : Theme.fg)
                width: root.cellWidth
                height: root.height - 4
                radius: DisplayProfileService.gameModeActive ? 0 : 6
                color: hover.hovered ? Theme.bgTertiary : "transparent"

                Item {
                    anchors.fill: parent
                    opacity: deviceCell.modelData.asleep || deviceCell.modelData.lastKnown ? 0.45 : 1

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 1
                        spacing: 4

                        SvgIcon {
                            icon: DeviceBattery.iconFor(deviceCell.modelData)
                            iconSize: Math.min(18, Math.floor((root.height - 8) / SettingsService.fontScale))
                            flat: true
                            iconColor: deviceCell.statusColor
                        }

                        ThemedText {
                            visible: root.showPercent
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceCell.modelData.percent >= 0 ? deviceCell.modelData.percent + "%" : "—"
                            font.pixelSize: Math.round(10 * SettingsService.fontScale)
                            font.weight: Font.DemiBold
                            color: deviceCell.statusColor
                        }
                    }

                    // No fill at 0%; no made-up level for unknown telemetry.
                    Rectangle {
                        id: levelTrack
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: parent.width - 10
                        height: 2
                        radius: 1
                        color: Theme.border

                        Rectangle {
                            height: parent.height
                            radius: 1
                            width: deviceCell.modelData.percent >= 0 ? parent.width * deviceCell.modelData.percent / 100 : 0
                            color: deviceCell.statusColor
                            Behavior on width {
                                NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    SvgIcon {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        visible: deviceCell.modelData.charging
                        icon: "bolt"
                        iconSize: 8
                        flat: true
                        iconColor: Theme.accent
                    }
                }

                HoverHandler { id: hover }
                ThemedTooltip {
                    visible: hover.hovered
                    timeout: 0
                    text: DeviceBattery.tooltip(deviceCell.modelData)
                }
            }
        }

        Rectangle {
            id: overflow
            visible: root.hiddenDevices.length > 0
            width: visible ? 24 : 0
            height: root.height - 4
            radius: DisplayProfileService.gameModeActive ? 0 : 6
            color: overflowHover.hovered ? Theme.bgTertiary : "transparent"

            ThemedText {
                anchors.centerIn: parent
                text: "+" + root.hiddenDevices.length
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.muted
            }
            HoverHandler { id: overflowHover }
            ThemedTooltip {
                visible: overflowHover.hovered
                timeout: 0
                text: root.hiddenDevices.map(function (device) { return DeviceBattery.tooltip(device); }).join("\n\n")
            }
        }
    }
}
