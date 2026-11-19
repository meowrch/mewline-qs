pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Services
import "../Utils/DeviceBattery.js" as DeviceBattery

Item {
    id: root

    readonly property bool active: SettingsService.settingsLoaded && SettingsService.deviceBatteryPosition !== "off"
    property var nativeDevices: []
    property var hubDevices: []
    property var lastKnown: ({})
    property bool batteryHubAvailable: false
    property string batteryHubError: ""
    readonly property var devices: DeviceBattery.merge(nativeDevices, hubDevices)

    Component.onCompleted: {
        refreshNative();
        refreshHub();
    }

    function refreshNative() {
        if (active && !nativeProc.running)
            nativeProc.running = true;
    }

    function refreshHub() {
        if (active && SettingsService.deviceBatteryUseBatteryHub && !hubProc.running)
            hubProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            refreshNative();
            refreshHub();
        } else {
            nativeProc.running = false;
            hubProc.running = false;
            nativeDevices = [];
            hubDevices = [];
            lastKnown = ({});
        }
    }

    Connections {
        target: SettingsService
        function onDeviceBatteryUseBatteryHubChanged() {
            if (SettingsService.deviceBatteryUseBatteryHub) {
                root.refreshHub();
            } else {
                hubProc.running = false;
                root.hubDevices = [];
                root.lastKnown = ({});
                root.batteryHubError = "";
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active
        onTriggered: root.refreshNative()
    }

    // Vendor HID queries are deliberately infrequent. Native reads above do
    // not send hardware requests; this optional backend may do so.
    Timer {
        interval: 60000
        repeat: true
        running: root.active && SettingsService.deviceBatteryUseBatteryHub
        onTriggered: root.refreshHub()
    }

    Process {
        id: nativeProc
        command: ["python3", Quickshell.shellDir + "/Scripts/system/device_batteries.py", "--native"]
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.active)
                root.nativeDevices = [];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                try {
                    let data = JSON.parse(text);
                    root.nativeDevices = Array.isArray(data.devices) ? data.devices : [];
                } catch (e) {
                    root.nativeDevices = [];
                }
            }
        }
    }

    Process {
        id: hubProc
        command: ["python3", Quickshell.shellDir + "/Scripts/system/device_batteries.py", "--batteryhub"]
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.active && SettingsService.deviceBatteryUseBatteryHub) {
                root.hubDevices = [];
                root.lastKnown = ({});
                root.batteryHubError = "BatteryHub helper failed";
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active || !SettingsService.deviceBatteryUseBatteryHub)
                    return;
                try {
                    let data = JSON.parse(text);
                    root.batteryHubAvailable = data.available === true;
                    root.batteryHubError = data.error || "";
                    let snapshot = DeviceBattery.withLastKnown(Array.isArray(data.devices) ? data.devices : [], root.lastKnown, Date.now());
                    root.hubDevices = snapshot.devices;
                    root.lastKnown = snapshot.cache;
                } catch (e) {
                    root.hubDevices = [];
                    root.lastKnown = ({});
                    root.batteryHubError = "Invalid BatteryHub output";
                }
            }
        }
    }
}
