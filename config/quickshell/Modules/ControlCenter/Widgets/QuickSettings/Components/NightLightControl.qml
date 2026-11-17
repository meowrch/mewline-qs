import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

QuickSettingsTile {
    id: root

    // hyprsunset (Wayland) / redshift (X11) are optional; probe at startup
    // and again every time
    // the quick settings open, so installing the binary is picked up without
    // restarting the shell.
    property bool hyprsunsetAvailable: false
    property bool isVisible: false

    onIsVisibleChanged: {
        if (isVisible) {
            availabilityProbe.running = false;
            availabilityProbe.running = true;
        }
    }

    isActive: DisplayProfileService.nightLightActive
    icon: isActive ? "moon-filled" : "moon"
    label: "Night Light"
    subtitle: {
        if (!root.hyprsunsetAvailable)
            return "Not installed";

        return isActive ? "On" : "Off";
    }
    onMenuClicked: clicked()
    onClicked: {
        DisplayProfileService.nightLightActive = !DisplayProfileService.nightLightActive;
    }

    Component.onCompleted: availabilityProbe.running = true

    Process {
        id: availabilityProbe

        command: ["sh", "-c", "command -v hyprsunset || command -v redshift"]

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "")
                    root.hyprsunsetAvailable = true;

            }
        }

    }
}
