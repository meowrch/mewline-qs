import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import "../../../Core/Utils/DeviceBattery.js" as DeviceBattery

// Peripheral batteries as separate capsules — one pill per device (plus an
// overflow pill), matching the other bar islands instead of a shared strip.
Item {
    id: root

    property string position: "left"
    property real maxWidth: 180
    readonly property bool enabledHere: SettingsService.deviceBatteryPosition === position
    // Display mode: "auto" follows the device count (one or two devices show
    // the percentage next to the icon, three or more switch to compact icons
    // with a level bar); "percent"/"bar" force one style. Narrow slots and
    // large fonts fall back to icons rather than an unreadable +1.
    readonly property string displayMode: SettingsService.deviceBatteryDisplayMode
    readonly property bool showPercent: displayMode === "percent"
        || (displayMode === "auto" && DeviceBatteryService.devices.length <= 2
            && maxWidth >= Math.round(66 * SettingsService.fontScale) + 4)
    // Cell width includes the capsule's own horizontal padding.
    readonly property real cellWidth: showPercent ? Math.round(66 * SettingsService.fontScale) : Math.round(36 * SettingsService.fontScale)
    readonly property var arrangement: DeviceBattery.layout(enabledHere ? DeviceBatteryService.devices : [], maxWidth, cellWidth, 0, 4, cellWidth)
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

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.shownDevices

            delegate: Rectangle {
                id: deviceCell
                required property var modelData
                readonly property bool low: modelData.percent >= 0 && modelData.percent <= 15 && !modelData.charging && !modelData.asleep
                readonly property color statusColor: low ? (PawletteService.paletteReady && PawletteService.palette.color_red ? PawletteService.palette.color_red : "#ff5c5c") : (modelData.charging ? Theme.accent : Theme.fg)
                width: root.cellWidth
                height: root.height
                radius: DisplayProfileService.gameModeActive ? 0 : height / 2
                color: hover.hovered ? Theme.bgTertiary : Theme.bgSecondary
                border.width: DisplayProfileService.gameModeActive ? 1 : 0
                border.color: Theme.border

                Item {
                    anchors.fill: parent
                    opacity: deviceCell.modelData.asleep || deviceCell.modelData.lastKnown ? 0.45 : 1

                    // Percentage mode centers the icon+digit group; compact
                    // mode pins the icon to the top so the level bar below
                    // keeps a small gap instead of touching it.
                    Row {
                        id: iconRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: root.showPercent ? parent.verticalCenter : undefined
                        anchors.top: root.showPercent ? undefined : parent.top
                        anchors.topMargin: root.showPercent ? 0 : 1
                        spacing: 4

                        SvgIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: DeviceBattery.iconFor(deviceCell.modelData)
                            iconSize: Math.min(18, Math.floor((root.height - 10) / SettingsService.fontScale))
                            flat: true
                            iconColor: deviceCell.statusColor
                        }

                        ThemedText {
                            visible: root.showPercent
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceCell.modelData.percent >= 0 ? deviceCell.modelData.percent + "%" : "—"
                            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                            font.weight: Font.DemiBold
                            color: deviceCell.statusColor
                        }
                    }

                    // Compact mode only: with one or two devices the percentage
                    // replaces the bar. No fill at 0%; no made-up level for
                    // unknown telemetry.
                    Rectangle {
                        id: levelTrack
                        visible: !root.showPercent
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: parent.width - 12
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
                        // In percentage mode the colored text already signals
                        // charging; the bolt badge is for the compact cells.
                        visible: deviceCell.modelData.charging && !root.showPercent
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
            width: visible ? root.cellWidth : 0
            height: root.height
            radius: DisplayProfileService.gameModeActive ? 0 : height / 2
            color: overflowHover.hovered ? Theme.bgTertiary : Theme.bgSecondary
            border.width: DisplayProfileService.gameModeActive ? 1 : 0
            border.color: Theme.border

            ThemedText {
                anchors.centerIn: parent
                text: "+" + root.hiddenDevices.length
                font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
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
