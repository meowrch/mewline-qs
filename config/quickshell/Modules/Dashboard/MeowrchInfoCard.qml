import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    readonly property string userName: Quickshell.env("USER") || "user"
    property string hostName: ""
    property string meowrchVersion: ""
    // The meowrch logo ships with the shell; a runtime copy wins if present.
    readonly property string logoPath: runtimeLogoExists ? "file://" + Quickshell.env("HOME") + "/.local/share/meowrch/assets/meowrch-logo.png" : "file://" + Quickshell.shellDir + "/assets/meowrch/meowrch-logo.png"
    property bool runtimeLogoExists: false

    contentPadding: Constants.sizeMd
    implicitHeight: contentCol.implicitHeight + root.contentPadding * 2

    ColumnLayout {
        id: contentCol

        anchors.fill: parent
        spacing: Constants.sizeSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd

            Image {
                source: root.logoPath
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                ThemedText {
                    text: root.userName
                    customSize: Constants.sizeXl
                    font.bold: true
                    color: Theme.fg
                }

                ThemedText {
                    text: root.userName + "@" + (root.hostName !== "" ? root.hostName : "hyprland")
                    customSize: Constants.sizeSm
                    color: Theme.muted
                }

            }

            Rectangle {
                visible: root.meowrchVersion !== ""
                color: Theme.bgAccent
                radius: height / 2
                implicitWidth: versionText.implicitWidth + 16
                implicitHeight: Constants.sizeLg + 4

                ThemedText {
                    id: versionText

                    anchors.centerIn: parent
                    text: "meowrch " + root.meowrchVersion
                    customSize: Constants.sizeXs
                    font.bold: true
                    color: Theme.accent
                }

            }

        }

        Divider {
            Layout.fillWidth: true
        }

        InfoRow {
            icon: "info"
            label: "System"
            value: SystemInfoService.osName
        }

        InfoRow {
            icon: "calendar"
            label: "Session"
            value: Qt.formatDateTime(SystemInfoService.currentTime, "ddd d MMM")
        }

        InfoRow {
            icon: "charger-filled"
            label: "Power profile"
            value: {
                let profile = SystemInfoService.powerProfile;
                return profile.charAt(0).toUpperCase() + profile.slice(1);
            }
        }

    }

    Component.onCompleted: {
        hostLoader.running = true;
        versionLoader.running = true;
        logoProbe.running = true;
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
        id: versionLoader

        command: ["cat", "/usr/local/share/meowrch/users/" + root.userName + "/version"]
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.meowrchVersion = "";

        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.meowrchVersion = text.trim();
            }
        }

    }

    Process {
        id: logoProbe

        command: ["python3", "-c", "import os,sys; print('1' if os.path.isfile(os.path.expanduser('~/.local/share/meowrch/assets/meowrch-logo.png')) else '0')"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.runtimeLogoExists = text.trim() === "1";
            }
        }

    }

}
