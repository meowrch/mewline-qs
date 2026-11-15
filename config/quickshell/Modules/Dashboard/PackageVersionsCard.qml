import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    property var widget: null

    // The meowrch package family, in display order.
    readonly property var packageNames: ["meowrch", "mewline", "pawlette", "meowrch-settings", "meowrch-tools"]
    // name -> installed version (only present when the package is installed).
    property var installedVersions: ({})
    // meowrch itself may be installed outside pacman (local /usr/local copy);
    // its version file is the fallback when pacman does not know the package.
    property string localMeowrchVersion: ""
    // name -> pending repository version ("pkg old -> new" from checkupdates).
    property var repoUpdates: ({})
    // name -> pending AUR version ("pkg version" from the AUR helper's -Qua).
    property var aurUpdates: ({})
    // One entry per tracked package: {name, installed, version, update, channel, newVersion}.
    property var packageModel: []
    readonly property int updatesCount: {
        let count = 0;
        for (let i = 0; i < packageModel.length; i++) {
            if (packageModel[i].update)
                count++;

        }
        return count;
    }
    readonly property bool isChecking: installedProc.running || repoUpdatesProc.running || aurUpdatesProc.running

    function refresh() {
        installedProc.running = false;
        installedProc.running = true;
        repoUpdatesProc.running = false;
        repoUpdatesProc.running = true;
        aurUpdatesProc.running = false;
        aurUpdatesProc.running = true;
    }

    // Generic "name value" line parser, shared by `pacman -Q` and the AUR
    // helper's -Qua output (missing packages only appear on stderr).
    function parseNameVersionMap(text) {
        let map = {};
        let lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            let parts = lines[i].trim().split(/\s+/);
            if (parts.length >= 2 && root.packageNames.includes(parts[0]))
                map[parts[0]] = parts[1];

        }
        return map;
    }

    // "pkg old -> new" lines from checkupdates, filtered to our packages.
    function parseRepoUpdateMap(text) {
        let map = {};
        let lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            let parts = lines[i].trim().split(/\s+/);
            if (parts.length >= 4 && parts[2] === "->" && root.packageNames.includes(parts[0]))
                map[parts[0]] = parts[3];

        }
        return map;
    }

    function rebuildModel() {
        let rows = [];
        for (let i = 0; i < packageNames.length; i++) {
            let name = packageNames[i];
            let installed = installedVersions[name] !== undefined;
            let version = installed ? installedVersions[name] : "";
            if (name === "meowrch" && !installed && localMeowrchVersion !== "") {
                // Locally installed meowrch (no pacman record) still has a
                // version file; treat it as installed so the row shows it.
                installed = true;
                version = localMeowrchVersion;
            }
            let channel = "";
            let newVersion = "";
            if (repoUpdates[name] !== undefined) {
                channel = "repo";
                newVersion = repoUpdates[name];
            } else if (aurUpdates[name] !== undefined) {
                channel = "aur";
                newVersion = aurUpdates[name];
            }
            rows.push({
                "name": name,
                "installed": installed,
                "version": version,
                "update": channel !== "",
                "channel": channel,
                "newVersion": newVersion
            });
        }
        packageModel = rows;
    }

    function pendingEntries() {
        let entries = [];
        for (let i = 0; i < packageModel.length; i++) {
            if (packageModel[i].update)
                entries.push(packageModel[i]);

        }
        return entries;
    }

    // Launches the update for the given entries in a hold-open terminal.
    // Repo packages go through pacman, AUR packages through the configured
    // helper; a mixed selection is queued in one shell so the pacman lock is
    // never contended by two transactions.
    function applyUpdates(entries) {
        if (!entries || entries.length === 0)
            return ;

        let repoNames = [];
        let aurNames = [];
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].channel === "aur")
                aurNames.push(entries[i].name);
            else
                repoNames.push(entries[i].name);

        }
        if (repoNames.length > 0 && aurNames.length > 0) {
            let cmd = "sudo pacman -S --needed " + repoNames.join(" ") + "; " + SettingsService.aurHelper + " -S --needed " + aurNames.join(" ");
            Quickshell.execDetached(["kitty", "--hold", "sh", "-c", cmd]);
        } else if (repoNames.length > 0) {
            Quickshell.execDetached(["kitty", "--hold", "sudo", "pacman", "-S", "--needed"].concat(repoNames));
        } else if (aurNames.length > 0) {
            Quickshell.execDetached(["kitty", "--hold", SettingsService.aurHelper, "-S", "--needed"].concat(aurNames));
        }
        // Re-read versions a few times while the transaction runs; the global
        // counters refresh with it.
        recheckTimer.runs = 0;
        recheckTimer.restart();
        UpdateService.checkUpdates();
    }

    // Full-repository upgrade (every pending extra/core repo package).
    function updateAllRepo() {
        Quickshell.execDetached(["kitty", "--hold", "sudo", "pacman", "-Syu"]);
        recheckTimer.runs = 0;
        recheckTimer.restart();
        UpdateService.checkUpdates();
    }

    // Upgrade every pending AUR package through the configured helper.
    function updateAllAur() {
        Quickshell.execDetached(["kitty", "--hold", SettingsService.aurHelper, "-ua"]);
        recheckTimer.runs = 0;
        recheckTimer.restart();
        UpdateService.checkUpdates();
    }

    contentPadding: Constants.sizeMd
    implicitHeight: contentCol.implicitHeight + root.contentPadding * 2

    ColumnLayout {
        id: contentCol

        anchors.fill: parent
        spacing: Constants.sizeXs

        // Branded header: meowrch logo, name and the suite's own version.
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            Image {
                source: "file://" + Quickshell.shellDir + "/assets/meowrch/logo.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                Layout.preferredWidth: Constants.size2Xl
                Layout.preferredHeight: Constants.size2Xl
            }

            ThemedText {
                text: "meowrch"
                customSize: Constants.sizeMd
                font.bold: true
                color: Theme.fg
            }

            Rectangle {
                visible: root.installedVersions["meowrch"] !== undefined || root.localMeowrchVersion !== ""
                color: Theme.bgAccent
                radius: height / 2
                implicitWidth: versionPillText.implicitWidth + 12
                implicitHeight: Constants.sizeLg + 2

                ThemedText {
                    id: versionPillText

                    anchors.centerIn: parent
                    text: root.installedVersions["meowrch"] || root.localMeowrchVersion
                    customSize: Constants.sizeXs
                    font.bold: true
                    color: Theme.accent
                }

            }

            Item {
                Layout.fillWidth: true
            }

            Rectangle {
                visible: !root.isChecking
                color: Theme.bgSecondary
                radius: height / 2
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: Constants.sizeLg + 2

                ThemedText {
                    id: countText

                    anchors.centerIn: parent
                    text: {
                        if (UpdateService.isSystemUpdating)
                            return "updating...";

                        return root.updatesCount > 0 ? root.updatesCount + " NEW" : "ALL LATEST";
                    }
                    customSize: Constants.sizeXs + 1
                    font.bold: true
                    color: root.updatesCount > 0 ? Theme.accent : Theme.muted
                }

            }

            ThemedText {
                visible: root.isChecking
                text: "checking..."
                customSize: Constants.sizeXs + 1
                color: Theme.muted
            }

            SvgIconButton {
                icon: "reload"
                flat: true
                iconSize: Constants.sizeSm
                onClicked: root.refresh()
            }

        }

        Divider {
        }

        Repeater {
            model: root.packageModel

            delegate: RowLayout {
                id: packageRow

                required property var modelData

                Layout.fillWidth: true
                spacing: Constants.sizeXs

                SvgIcon {
                    icon: packageRow.modelData.channel === "aur" ? "github" : "box"
                    flat: true
                    iconSize: Constants.sizeSm + 2
                    iconColor: packageRow.modelData.installed ? Theme.accent : Theme.muted
                }

                ThemedText {
                    text: packageRow.modelData.name
                    customSize: Constants.sizeSm
                    font.bold: true
                    color: packageRow.modelData.installed ? Theme.fg : Theme.muted
                }

                ThemedText {
                    visible: packageRow.modelData.installed
                    text: packageRow.modelData.version
                    customSize: Constants.sizeXs + 1
                    color: Theme.muted
                }

                ThemedText {
                    visible: packageRow.modelData.update && packageRow.modelData.newVersion !== ""
                    text: "-> " + packageRow.modelData.newVersion
                    customSize: Constants.sizeXs + 1
                    color: Theme.accent
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                }

                Item {
                    Layout.fillWidth: true
                }

                // Update pill button (matches the version pill in MeowrchInfoCard).
                Rectangle {
                    id: updatePill

                    visible: packageRow.modelData.update
                    color: updateMouse.containsMouse ? Theme.bgAccentComplementary : Theme.bgAccent
                    radius: height / 2
                    implicitWidth: updatePillText.implicitWidth + Constants.sizeSm + 4
                    implicitHeight: Constants.sizeLg

                    MouseArea {
                        id: updateMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.applyUpdates([packageRow.modelData])
                    }

                    ThemedText {
                        id: updatePillText

                        anchors.centerIn: parent
                        text: "Update"
                        customSize: Constants.sizeXs
                        font.bold: true
                        color: Theme.accent
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animFast
                        }

                    }

                }

                ThemedText {
                    visible: packageRow.modelData.installed && !packageRow.modelData.update
                    text: "latest"
                    customSize: Constants.sizeXs + 1
                    color: Theme.muted
                }

                ThemedText {
                    visible: !packageRow.modelData.installed
                    text: "not installed"
                    customSize: Constants.sizeXs + 1
                    color: Theme.muted
                }

            }

        }

        Divider {
        }

        // Global update actions: full repo upgrade and full AUR upgrade,
        // each running in a hold-open terminal.
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                visible: root.updatesCount > 0
                text: root.updatesCount + (root.updatesCount === 1 ? " update pending" : " updates pending")
                customSize: Constants.sizeXs + 1
                color: Theme.muted
            }

            Item {
                Layout.fillWidth: true
            }

            ThemedButton {
                text: "Update extra"
                onClicked: root.updateAllRepo()
            }

            ThemedButton {
                text: "Update AUR"
                onClicked: root.updateAllAur()
            }

        }

    }

    Component.onCompleted: {
        localVersionProc.running = true;
        root.refresh();
    }

    Connections {
        function onIsOpenChanged() {
            // Re-check whenever the dashboard is opened so the versions are
            // never stale from the last session.
            if (root.widget && root.widget.isOpen)
                root.refresh();

        }

        target: root.widget
        ignoreUnknownSignals: true
    }

    Process {
        id: installedProc

        command: ["pacman", "-Q"].concat(root.packageNames)
        stdout: StdioCollector {
            onStreamFinished: {
                root.installedVersions = root.parseNameVersionMap(text);
                root.rebuildModel();
            }
        }
        // Missing packages report "error: package ... was not found" here;
        // they simply stay out of installedVersions and show "not installed".
        stderr: StdioCollector {
        }

    }

    Process {
        id: repoUpdatesProc

        // checkupdates exits non-zero when there is nothing to do; output is
        // still parsed and an empty result just means "up to date".
        command: ["sh", "-c", "checkupdates 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repoUpdates = root.parseRepoUpdateMap(text);
                root.rebuildModel();
            }
        }

    }

    Process {
        id: aurUpdatesProc

        command: ["sh", "-c", SettingsService.aurHelper + " -Qua 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.aurUpdates = root.parseNameVersionMap(text);
                root.rebuildModel();
            }
        }

    }

    Process {
        id: localVersionProc

        // Version of a local (non-pacman) meowrch installation.
        command: ["sh", "-c", "cat /usr/local/share/meowrch/users/$USER/version 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localMeowrchVersion = text.trim();
                root.rebuildModel();
            }
        }

    }

    Timer {
        id: recheckTimer

        property int runs: 0

        interval: 30000
        repeat: true
        onTriggered: {
            runs++;
            root.refresh();
            if (runs >= 3)
                stop();

        }
    }

}
