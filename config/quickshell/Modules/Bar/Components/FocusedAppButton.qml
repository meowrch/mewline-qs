import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Focused application pill for the center island: app icon + window title,
// hidden while the desktop is focused. Display-only (matches the reference
// bar's centered "focused app" row).
Rectangle {
    id: root

    readonly property bool hasApp: FocusedAppService.hasWindow
    readonly property bool isHovered: mouseArea.containsMouse
    // Cap the title so the island stays compact (~360px total with flares).
    readonly property real maxTitleWidth: 260
    readonly property int iconSize: Constants.sizeLg + 2
    readonly property string iconSource: FocusedAppService.appIconSource

    color: "transparent"
    implicitWidth: hasApp ? mainLayout.implicitWidth : 0
    implicitHeight: mainLayout.implicitHeight
    width: implicitWidth
    height: implicitHeight
    opacity: hasApp ? 1 : 0
    visible: opacity > 0.001
    clip: true
    scale: DisplayProfileService.gameModeActive ? 1 : (isHovered ? 1.02 : 1)

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: mainLayout

        anchors.centerIn: parent
        spacing: Constants.sizeXs

        Item {
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: appIconImage

                anchors.fill: parent
                sourceSize: Qt.size(48, 48)
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: root.hasApp && status === Image.Ready
            }

            SvgIcon {
                anchors.fill: parent
                icon: "apps-filled"
                iconSize: root.iconSize
                flat: true
                iconColor: Theme.muted
                visible: !appIconImage.visible
            }

        }

        ThemedText {
            text: FocusedAppService.displayTitle
            elide: Text.ElideRight
            visible: root.hasApp && text !== ""
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maxTitleWidth
            Layout.preferredWidth: Math.min(implicitWidth, root.maxTitleWidth)

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    Behavior on opacity {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutBack
        }

    }

}
