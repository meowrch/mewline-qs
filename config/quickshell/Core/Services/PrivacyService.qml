import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: root

    // Poll interval mirrors the mewline privacy service (2s).
    property int pollInterval: 2000
    property bool camActive: false
    property bool micActive: false
    property bool screenActive: false
    property bool locActive: false
    property var micApps: []
    property var camApps: []
    property var screenApps: []
    property var locApps: []
    readonly property bool anyActive: camActive || micActive || screenActive || locActive

    function refresh() {
        if (probeProc.running)
            return ;

        probeProc.running = true;
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: probeProc

        command: ["python3", Quickshell.shellDir + "/Scripts/system/privacy_info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let doc = JSON.parse(text);
                    root.camActive = doc.cam === true;
                    root.micActive = doc.mic === true;
                    root.screenActive = doc.screen === true;
                    root.locActive = doc.loc === true;
                    root.micApps = doc.mic_apps || [];
                    root.camApps = doc.cam_apps || [];
                    root.screenApps = doc.screen_apps || [];
                    root.locApps = doc.loc_apps || [];
                } catch (e) {
                    // Keep the previous state on a failed probe; transient
                    // pw-dump hiccups must not flash the dots off/on.
                }
            }
        }

    }

}
