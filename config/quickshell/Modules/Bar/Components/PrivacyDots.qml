import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// 2x2 privacy dot grid, ported from the mewline combined controls widget:
// microphone and camera on the top row, screen share and location below.
// Inactive dots stay faintly visible (same dim opacity as mewline), active
// dots light up in their palette color.
Item {
    id: root

    readonly property real dimOpacity: 0.12
    readonly property color micColor: PawletteService.paletteReady && PawletteService.palette.color_red ? PawletteService.palette.color_red : "#ff5c5c"
    readonly property color camColor: PawletteService.paletteReady && PawletteService.palette.color_magenta ? PawletteService.palette.color_magenta : "#ff6ec7"
    readonly property color screenColor: PawletteService.paletteReady && PawletteService.palette.color_green ? PawletteService.palette.color_green : "#5cff7a"
    readonly property color locColor: PawletteService.paletteReady && PawletteService.palette.color_blue ? PawletteService.palette.color_blue : "#5c9dff"
    readonly property int dotSize: 10

    implicitWidth: dotsColumn.implicitWidth
    implicitHeight: SettingsService.barWidgetHeight

    function appsText(names) {
        if (!names || names.length === 0)
            return "";

        let shown = names.slice(0, 3).join(", ");
        if (names.length > 3)
            shown += " +" + (names.length - 3);

        return shown;
    }

    ColumnLayout {
        id: dotsColumn

        anchors.centerIn: parent
        spacing: 2

        RowLayout {
            spacing: 3
            Layout.alignment: Qt.AlignHCenter

            PrivacyDot {
                dotColor: root.micColor
                active: PrivacyService.micActive
                tooltipText: PrivacyService.micActive ? "Microphone in use: " + root.appsText(PrivacyService.micApps) : ""
            }

            PrivacyDot {
                dotColor: root.camColor
                active: PrivacyService.camActive
                tooltipText: PrivacyService.camActive ? "Camera in use: " + root.appsText(PrivacyService.camApps) : ""
            }

        }

        RowLayout {
            spacing: 3
            Layout.alignment: Qt.AlignHCenter

            PrivacyDot {
                dotColor: root.screenColor
                active: PrivacyService.screenActive
                tooltipText: PrivacyService.screenActive ? "Screen share: " + root.appsText(PrivacyService.screenApps) : ""
            }

            PrivacyDot {
                dotColor: root.locColor
                active: PrivacyService.locActive
                tooltipText: PrivacyService.locActive ? "Location in use: " + root.appsText(PrivacyService.locApps) : ""
            }

        }

    }

    component PrivacyDot: Item {
        id: dot

        property color dotColor: "#ffffff"
        property bool active: false
        property string tooltipText: ""

        Layout.preferredWidth: root.dotSize
        Layout.preferredHeight: root.dotSize
        implicitWidth: root.dotSize
        implicitHeight: root.dotSize

        Rectangle {
            anchors.centerIn: parent
            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            color: dot.dotColor
            opacity: dot.active ? 1 : root.dimOpacity

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

        }

        ThemedTooltip {
            visible: dotHover.hovered && dot.active && text !== ""
            text: dot.tooltipText
        }

        HoverHandler {
            id: dotHover

            cursorShape: Qt.ArrowCursor
        }

    }

}
