import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: itemRoot

    property var trayItem: null
    property int itemIndex: -1
    property int customHeight: SettingsService.barWidgetHeight
    property int iconSize: Constants.sizeSm
    property int hitPadding: 0
    readonly property string widgetId: itemIndex >= 0 ? ("systemTray_" + itemIndex) : ""
    readonly property bool isActive: (widgetId !== "" && AppState.isWidgetOpen(widgetId)) || (AppState.activeTrayItem === trayItem && AppState.activeWidget.startsWith("systemTray_"))
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed

    signal clicked(var mouse)

    // Tighter packing: the box hugs the icon instead of spanning the full
    // bar height, so icons sit closer together (capped by customHeight so
    // compact island usage keeps its square layout).
    implicitHeight: customHeight
    implicitWidth: Math.min(customHeight, iconSize + hitPadding * 2 + Constants.sizeXs)
    width: implicitWidth
    height: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.alignment: Qt.AlignVCenter
    color: isActive ? Theme.bgAccent : (isHovered ? Theme.bgSecondary : "transparent")
    radius: height / 2
    scale: isPressed ? 0.92 : (isHovered ? 1.05 : 1)

    // Well-known tray apps are drawn as nerd-font glyphs (the same font the
    // old mewline bar used), which keeps the tray monochrome and consistent.
    // Unmapped apps fall back to their real tray icon image.
    readonly property string trayIdent: {
        if (!trayItem)
            return "";

        let parts = [];
        if (trayItem.iconName !== undefined && trayItem.iconName !== null)
            parts.push(trayItem.iconName.toString());

        if (trayItem.id !== undefined && trayItem.id !== null)
            parts.push(trayItem.id.toString());

        if (trayItem.title !== undefined && trayItem.title !== null)
            parts.push(trayItem.title.toString());

        return parts.join(" ").toLowerCase();
    }
    readonly property string trayGlyph: {
        const glyphs = {
            "telegram": "\uF2C6",
            "telegram-desktop": "\uF2C6",
            "discord": "\uF392",
            "vesktop": "\uF392",
            "webcord": "\uF392",
            "spotify": "\uF1BC",
            "playerctl": "\uF1BC",
            "steam": "\uF1B6",
            "chrome": "\uF268",
            "google-chrome": "\uF268",
            "chromium": "\uF268",
            "brave": "\uF268",
            "github": "\uF09B",
            "nm-applet": "\uF1EB",
            "network-manager": "\uF1EB",
            "network-wireless": "\uF1EB",
            "blueman": "\uF293",
            "blueman-tray": "\uF293",
            "bluetooth": "\uF293",
            "kdeconnect": "\uF10B",
            "kdeconnect-indicator": "\uF10B",
            "pasystray": "\uF028",
            "volumeicon": "\uF028",
            "keepassxc": "\uF084",
            "qbittorrent": "\uF0EA"
        };
        for (let key in glyphs) {
            if (trayIdent.indexOf(key) !== -1)
                return glyphs[key];

        }
        return "";
    }

    ThemedText {
        anchors.centerIn: parent
        visible: root.trayGlyph !== ""
        text: root.trayGlyph
        font.family: SettingsService.kittyFontFamily
        font.pixelSize: Math.round(root.iconSize * SettingsService.fontScale)
        color: itemRoot.isActive ? Theme.accent : (isHovered ? Theme.fg : Theme.muted)
    }

    SvgIcon {
        id: iconImage

        visible: root.trayGlyph === ""
        anchors.centerIn: parent
        iconSize: itemRoot.iconSize
        width: itemRoot.iconSize
        height: itemRoot.iconSize
        useOriginalColors: {
            if (!itemRoot.trayItem)
                return true;

            let identifiers = [];
            if (itemRoot.trayItem.iconName !== undefined && itemRoot.trayItem.iconName !== null)
                identifiers.push(itemRoot.trayItem.iconName.toString().toLowerCase());

            if (itemRoot.trayItem.id !== undefined && itemRoot.trayItem.id !== null)
                identifiers.push(itemRoot.trayItem.id.toString().toLowerCase());

            if (itemRoot.trayItem.title !== undefined && itemRoot.trayItem.title !== null)
                identifiers.push(itemRoot.trayItem.title.toString().toLowerCase());

            let identString = identifiers.join(" ");
            let colorIcons = ["youtube", "discord", "spotify", "slack", "telegram", "whatsapp", "skype", "steam", "obs", "vlc", "chrome", "firefox", "brave", "edge", "vesktop", "webcord"];
            for (let i = 0; i < colorIcons.length; i++) {
                if (identString.includes(colorIcons[i]))
                    return true;

            }
            for (let i = 0; i < identifiers.length; i++) {
                let n = identifiers[i];
                if (n.endsWith("-symbolic") || n.endsWith("-tray") || n.endsWith("-panel") || n.endsWith("-indicator"))
                    return false;

            }
            let monoIcons = ["blueman", "nm-device", "network-wireless", "network-wired", "audio-volume", "microphone-sensitivity", "battery", "kdeconnect", "cbatticon", "indicator-sound", "indicator-bluetooth", "network-manager", "nm-applet", "volume", "mic", "network", "bluetooth", "wifi", "sound"];
            for (let i = 0; i < monoIcons.length; i++) {
                if (identString.includes(monoIcons[i]))
                    return false;

            }
            if (itemRoot.trayItem.category === "SystemServices" || itemRoot.trayItem.category === "Hardware")
                return false;

            return false;
        }
        iconColor: itemRoot.isActive ? Theme.accent : Theme.fg
        flat: true
        icon: {
            if (!itemRoot.trayItem)
                return "";

            try {
                if (itemRoot.trayItem.iconName !== undefined && itemRoot.trayItem.iconName !== "")
                    return "image://icon/" + itemRoot.trayItem.iconName + "?fallback=false";

                let icon = itemRoot.trayItem.icon;
                if (!icon)
                    return "";

                let iconStr = icon.toString();
                if (iconStr.indexOf("://") !== -1 || iconStr.startsWith("/"))
                    return iconStr;

                return "image://icon/" + iconStr + "?fallback=false";
            } catch (e) {
                return "";
            }
        }

        Behavior on iconColor {
            ColorAnimation {
                duration: Constants.animFast
            }

        }

    }

    MouseArea {
        id: mouseArea

        z: 10
        anchors.fill: parent
        anchors.margins: -itemRoot.hitPadding
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (!itemRoot.trayItem)
                return ;

            if (mouse.button === Qt.LeftButton && !itemRoot.trayItem.onlyMenu)
                itemRoot.trayItem.activate();

            itemRoot.clicked(mouse);
        }
        // SNI scroll action: vertical wheel scrolls (e.g. volume on mixer
        // applets); shift+wheel maps to the horizontal scroll axis.
        onWheel: (wheel) => {
            if (!itemRoot.trayItem)
                return ;

            const dy = wheel.angleDelta.y;
            const dx = wheel.angleDelta.x;
            if (dy === 0 && dx === 0)
                return ;

            const horizontal = dy === 0;
            const delta = (horizontal ? dx : dy) > 0 ? 1 : -1;
            itemRoot.trayItem.scroll(delta, horizontal);
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
