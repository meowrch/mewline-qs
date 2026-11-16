import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    readonly property string userName: Quickshell.env("USER") || "user"
    property string hostName: ""
    property string uptimeText: ""
    // Vector logo fallback for the avatar (always ships with the shell).
    readonly property string logoPath: "file://" + Quickshell.shellDir + "/assets/meowrch/logo.svg"
    // User avatar: ~/.face.icon wins over the logo; the logo also covers a
    // face file that exists but cannot be decoded.
    property bool faceIconExists: false
    property bool faceIconFailed: false
    readonly property bool useFaceIcon: faceIconExists && !faceIconFailed
    readonly property int avatarSize: Constants.size5Xl
    readonly property int avatarInset: 3
    // Compact fastfetch-style rows keep the card narrow and scannable.
    readonly property int infoTextSize: Constants.sizeSm
    // Longest label ("Packages:") measured with the real font so the value
    // column starts aligned at every font scale.
    readonly property int labelColumnWidth: labelMeter.implicitWidth + Constants.size2Xs
    readonly property string themeName: {
        if (PawletteService.dynamicEnabled)
            return "Dynamic (wallpaper)";

        let base = PawletteService.lastAppliedTheme !== "" ? PawletteService.lastAppliedTheme : "Pawlette";
        let variant = PawletteService.lastAppliedVariant;
        if (variant !== "" && variant !== "default")
            return base + " (" + variant + ")";

        return base;
    }
    // Fastfetch-style key/value rows. The list is a binding, so every row
    // refreshes on its own when the underlying service property changes.
    readonly property var infoRows: [{
            "label": "OS",
            "value": SystemStats.osName
        }, {
            "label": "Host",
            "value": SystemStats.hostModel !== "" ? SystemStats.hostModel : SystemStats.hostname
        }, {
            "label": "Kernel",
            "value": SystemStats.kernel
        }, {
            "label": "Uptime",
            "value": uptimeText !== "" ? uptimeText : "..."
        }, {
            "label": "Packages",
            "value": SystemStats.packages
        }, {
            "label": "Shell",
            "value": SystemStats.shell
        }, {
            "label": "Display",
            "value": SystemStats.display
        }, {
            "label": "WM",
            "value": SystemStats.wm
        }, {
            "label": "Theme",
            "value": themeName
        }, {
            "label": "CPU",
            "value": SystemStats.cpuModel + (SystemStats.cpuCores !== "" ? " (" + SystemStats.cpuCores + ")" : "")
        }, {
            "label": "Memory",
            "value": SystemStats.memSizeText
        }]

    function formatUptime(seconds) {
        let d = Math.floor(seconds / 86400);
        let h = Math.floor((seconds % 86400) / 3600);
        let m = Math.floor((seconds % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";

        if (h > 0)
            return h + "h " + m + "m";

        return m + "m";
    }

    contentPadding: Constants.sizeMd
    // Cap the natural width so the longest value (CPU model) elides instead
    // of stretching the horizontal two-column dashboard.
    implicitWidth: Math.min(contentCol.implicitWidth + root.contentPadding * 2, 400)
    implicitHeight: contentCol.implicitHeight + root.contentPadding * 2

    // Invisible meter for the widest info label; drives the label column width.
    Text {
        id: labelMeter

        visible: false
        font.family: Constants.fontFamily
        font.pixelSize: Math.round(root.infoTextSize * SettingsService.fontScale)
        text: "Packages:"
    }

    ColumnLayout {
        id: contentCol

        anchors.fill: parent
        spacing: Constants.sizeSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd

            // Circular avatar frame: ~/.face.icon when present, meowrch logo otherwise.
            Rectangle {
                id: avatarFrame

                Layout.preferredWidth: root.avatarSize
                Layout.preferredHeight: root.avatarSize
                radius: width / 2
                color: Theme.bgSecondary
                border.width: 1.5
                border.color: Theme.accent

                Image {
                    id: avatarImage

                    anchors.fill: parent
                    anchors.margins: root.avatarInset
                    source: root.useFaceIcon ? "file://" + Quickshell.env("HOME") + "/.face.icon" : root.logoPath
                    fillMode: Image.PreserveAspectCrop
                    mipmap: true
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true

                    onStatusChanged: {
                        // A face file that exists but fails to load falls back to the logo.
                        if (root.useFaceIcon && status === Image.Error)
                            root.faceIconFailed = true;

                    }

                    // Same circular masking recipe as the lock screen avatar.
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        // Keep a real 0..1 alpha ramp so the antialiased
                        // circle edge is not promoted to fully opaque.
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1

                        maskSource: ShaderEffectSource {
                            visible: false
                            hideSource: true
                            smooth: true

                            sourceItem: Rectangle {
                                width: avatarImage.width
                                height: avatarImage.height
                                radius: avatarImage.width / 2
                                antialiasing: true
                                color: Theme.white
                            }

                        }

                    }

                }

            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                ThemedText {
                    text: root.userName
                    customSize: Constants.sizeXl
                    font.bold: true
                    color: Theme.fg
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                ThemedText {
                    text: root.userName + "@" + (root.hostName !== "" ? root.hostName : "hyprland")
                    customSize: Constants.sizeSm
                    color: Theme.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

            }

            // Shell settings shortcut: opens the minflair settings window.
            SvgIconButton {
                id: settingsBtn

                icon: "tune"
                iconSize: Constants.sizeLg
                flat: true
                Layout.alignment: Qt.AlignVCenter

                onClicked: {
                    AppState.closeAllWidgets();
                    AppState.toggleWidget("minflair_settings");
                }
            }

        }

        Divider {
            Layout.fillWidth: true
        }

        // Fastfetch-style system information block; own tight spacing so the
        // rows read as one compact table.
        ColumnLayout {
            id: infoRowsCol

            Layout.fillWidth: true
            spacing: 3

            Repeater {
                model: root.infoRows

                delegate: RowLayout {
                    id: infoRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Constants.size2Xs

                    ThemedText {
                        text: infoRow.modelData.label + ":"
                        customSize: root.infoTextSize
                        color: Theme.accent
                        elide: Text.ElideRight
                        Layout.preferredWidth: root.labelColumnWidth
                    }

                    ThemedText {
                        text: infoRow.modelData.value === "" ? "-" : infoRow.modelData.value
                        customSize: root.infoTextSize
                        color: Theme.fg
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                }

            }

        }

    }

    Component.onCompleted: {
        hostLoader.running = true;
        faceProbe.running = true;
        uptimeLoader.running = true;
    }

    Process {
        id: hostLoader

        command: ["cat", "/etc/hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hostName = text.trim();
            }
        }

    }

    Process {
        id: faceProbe

        command: ["sh", "-c", "test -f \"$HOME/.face.icon\" && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.faceIconExists = text.trim() === "1";
            }
        }

    }

    Process {
        id: uptimeLoader

        command: ["sh", "-c", "awk '{print int($1)}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                let seconds = parseInt(text.trim());
                root.uptimeText = isNaN(seconds) ? "" : root.formatUptime(seconds);
            }
        }

    }

    Timer {
        id: uptimeTimer

        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            uptimeLoader.running = false;
            uptimeLoader.running = true;
        }
    }

}
