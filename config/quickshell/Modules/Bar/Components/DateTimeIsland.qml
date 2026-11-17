import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Compact datetime island in the mewline style: "15-11-26 20:23" with the
// active keyboard layout label next to it. Opens the calendar (the same
// widget the old center clock opened).
Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed

    // XKB layout code -> compact language label ("En"/"Ru"). Unknown codes
    // fall back to the capitalized code so any layout stays readable.
    function layoutLabel(code) {
        const labels = {
            "us": "En",
            "en": "En",
            "gb": "En",
            "ru": "Ru",
            "ua": "Ua",
            "ara": "Ar",
            "latam": "La",
            "es": "Es",
            "de": "De",
            "fr": "Fr",
            "ca": "Fr",
            "it": "It",
            "br": "Br",
            "pt": "Pt",
            "pl": "Pl",
            "tr": "Tr",
            "jp": "Jp",
            "kr": "Kr",
            "nl": "Nl",
            "se": "Se",
            "no": "No",
            "dk": "Dk",
            "fi": "Fi",
            "cz": "Cz",
            "gr": "Gr",
            "il": "Il"
        };
        let c = (code || "us").trim();
        if (c === "")
            c = "us";

        if (labels[c] !== undefined)
            return labels[c];

        return c.charAt(0).toUpperCase() + c.slice(1);
    }

    // Fixed compact mewline format: DD-MM-YY HH:MM, 24h.
    readonly property string timeText: Qt.formatDateTime(SystemInfoService.currentTime, "HH:mm")
    readonly property string dateText: Qt.formatDateTime(SystemInfoService.currentTime, "dd-MM-yy")

    // Caps Lock flips the layout label case: ru <-> RU.
    function caseFor(text) {
        return CompositorService.capsLockOn ? text.toUpperCase() : text.toLowerCase();
    }

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

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: Constants.size2Xs

        ThemedText {
            text: root.dateText
            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
            font.weight: Font.DemiBold
            color: Theme.muted
        }

        ThemedText {
            text: root.timeText
            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
            font.bold: true
            color: Theme.fg
        }

        Divider {
            vertical: true
            Layout.preferredHeight: Constants.sizeMd
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignVCenter
        }

        // Current keyboard layout; Caps Lock flips the case (ru <-> RU).
        ThemedText {
            text: root.caseFor(root.layoutLabel(CompositorService.keyboardLayout))
            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
            font.weight: Font.DemiBold
            color: Theme.fg
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: AppState.toggleWidget("calendar")
    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutBack
        }

    }

}
