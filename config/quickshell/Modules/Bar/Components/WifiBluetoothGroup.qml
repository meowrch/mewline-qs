import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Single island holding the wifi and bluetooth indicators side by side.
// Icons reflect connection state; clicking either opens the control center,
// which owns the network / bluetooth sections.
Rectangle {
    id: root

    color: Theme.bgSecondary
    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
    implicitHeight: SettingsService.barWidgetHeight
    implicitWidth: iconRow.implicitWidth + Constants.sizeXs * 2
    width: implicitWidth
    height: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: iconRow

        anchors.centerIn: parent
        spacing: Constants.size3Xs

        Rectangle {
            id: wifiButton

            property bool isHovered: wifiMouse.containsMouse
            readonly property bool connected: ConnectivityService.networkConnected

            width: Constants.sizeXl + 6
            height: SettingsService.barWidgetHeight - 6
            radius: DisplayProfileService.gameModeActive ? 0 : height / 2
            color: wifiMouse.pressed ? Theme.bgAccent : (isHovered ? Theme.bgTertiary : "transparent")

            SvgIcon {
                anchors.centerIn: parent
                icon: ConnectivityService.wifiIcon
                iconSize: Constants.sizeMd
                flat: true
                iconColor: wifiButton.isHovered ? Theme.accent : (wifiButton.connected ? Theme.fg : Theme.muted)
            }

            MouseArea {
                id: wifiMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: AppState.toggleWidget("controlCenter")
            }

        }

        Rectangle {
            id: btButton

            property bool isHovered: btMouse.containsMouse
            readonly property bool connected: ConnectivityService.bluetoothConnected
            readonly property bool powered: ConnectivityService.bluetoothPowered

            width: Constants.sizeXl + 6
            height: SettingsService.barWidgetHeight - 6
            radius: DisplayProfileService.gameModeActive ? 0 : height / 2
            color: btMouse.pressed ? Theme.bgAccent : (isHovered ? Theme.bgTertiary : "transparent")

            SvgIcon {
                anchors.centerIn: parent
                icon: ConnectivityService.bluetoothIcon
                iconSize: Constants.sizeMd
                flat: true
                iconColor: btButton.isHovered ? Theme.accent : (btButton.connected ? Theme.fg : (btButton.powered ? Theme.fg : Theme.muted))
            }

            MouseArea {
                id: btMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: AppState.toggleWidget("controlCenter")
            }

        }

    }

}
