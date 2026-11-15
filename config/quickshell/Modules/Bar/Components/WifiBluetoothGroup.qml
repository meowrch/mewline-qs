import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Single island holding the wifi and bluetooth indicators side by side.
// The whole capsule is one button: it opens the control center, which owns
// the network / bluetooth sections. Icons only reflect connection state.
Rectangle {
    id: root

    property bool isHovered: capsuleMouse.containsMouse
    readonly property bool wifiConnected: ConnectivityService.networkConnected
    readonly property bool btConnected: ConnectivityService.bluetoothConnected
    readonly property bool btPowered: ConnectivityService.bluetoothPowered

    color: capsuleMouse.pressed ? Theme.bgAccent : (isHovered ? Theme.bgTertiary : Theme.bgSecondary)
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

        SvgIcon {
            icon: ConnectivityService.wifiIcon
            iconSize: Constants.sizeMd
            flat: true
            iconColor: root.isHovered ? Theme.accent : (root.wifiConnected ? Theme.fg : Theme.muted)
        }

        SvgIcon {
            icon: ConnectivityService.bluetoothIcon
            iconSize: Constants.sizeMd
            flat: true
            iconColor: root.isHovered ? Theme.accent : (root.btConnected || root.btPowered ? Theme.fg : Theme.muted)
        }

    }

    MouseArea {
        id: capsuleMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: AppState.toggleWidget("controlCenter")
    }

}
