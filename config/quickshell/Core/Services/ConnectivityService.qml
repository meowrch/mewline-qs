import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: connectivityService

    // Reuses the ControlCenter helper scripts as the single source of truth
    // for NM/Bluez state so the bar and the control center tiles always
    // agree. Polling only (no long-running processes): wifi.py status and
    // bluetooth.py status are one-shot commands.
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiSsid: ""
    property bool ethernetConnected: false
    property bool bluetoothPowered: false
    property bool bluetoothConnected: false
    property string bluetoothDeviceName: ""

    readonly property bool networkConnected: wifiConnected || ethernetConnected
    readonly property string wifiIcon: networkConnected ? "wifi" : "wifi-off"
    readonly property string bluetoothIcon: bluetoothPowered ? "bluetooth" : "bluetooth-off"

    function refresh() {
        if (!wifiProc.running)
            wifiProc.running = true;

        if (!ethProc.running)
            ethProc.running = true;

        if (!btProc.running)
            btProc.running = true;

    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: connectivityService.refresh()
    }

    Process {
        id: wifiProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return ;

                try {
                    let st = JSON.parse(text.trim());
                    connectivityService.wifiEnabled = st.radio === true;
                    let ssid = st.connected_ssid || "";
                    connectivityService.wifiSsid = ssid;
                    connectivityService.wifiConnected = ssid !== "" && ssid !== "Disconnected";
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: ethProc

        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                let connected = false;
                let lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    // terse format: TYPE:STATE:CONNECTION
                    let parts = lines[i].trim().split(":");
                    if (parts.length >= 2 && parts[0] === "ethernet" && parts[1] === "connected")
                        connected = true;

                }
                connectivityService.ethernetConnected = connected;
            }
        }

    }

    Process {
        id: btProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "")
                    return ;

                try {
                    let st = JSON.parse(text.trim());
                    connectivityService.bluetoothPowered = st.powered === true;
                    let dev = st.connected_device || "";
                    connectivityService.bluetoothDeviceName = dev;
                    connectivityService.bluetoothConnected = dev !== "";
                } catch (e) {
                }
            }
        }

    }

}
