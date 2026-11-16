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

    // Icon resolution mirrors the python mewline bar: icon name with a
    // -symbolic variant through the theme first, then the item's own icon
    // URL (theme name or pixmap). The provider paints a pink/black
    // placeholder for missing names even with fallback=false, so every
    // theme lookup is gated with hasThemeIcon.
    readonly property string iconSource: {
        if (!trayItem)
            return "";

        try {
            let name = (trayItem.iconName !== undefined && trayItem.iconName !== null) ? trayItem.iconName.toString().trim() : "";
            if (name !== "") {
                let sym = name.endsWith("-symbolic") ? name : name + "-symbolic";
                if (Quickshell.hasThemeIcon(sym))
                    return "image://icon/" + sym;

                if (Quickshell.hasThemeIcon(name))
                    return "image://icon/" + name;

            }

            let ic = (trayItem.icon !== undefined && trayItem.icon !== null) ? trayItem.icon.toString().trim() : "";
            if (ic !== "") {
                if (ic.indexOf("image://icon/") === 0) {
                    let n = ic.substring("image://icon/".length).split("?")[0];
                    let sym = n.endsWith("-symbolic") ? n : n + "-symbolic";
                    if (Quickshell.hasThemeIcon(sym))
                        return "image://icon/" + sym;

                    if (Quickshell.hasThemeIcon(n))
                        return "image://icon/" + n;

                    return ic;
                }

                return ic;
            }

            return "";
        } catch (e) {
            return "";
        }
    }

    SvgIcon {
        id: iconImage

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
        icon: itemRoot.iconSource

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
