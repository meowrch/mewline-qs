import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

QuickSettingsTile {
    id: root

    // hyprsunset is optional; probe for it once at startup so the tile can say
    // "Not installed" instead of silently doing nothing when the binary is missing.
    property bool hyprsunsetAvailable: false

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

        command: ["sh", "-c", "command -v hyprsunset"]

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "")
                    root.hyprsunsetAvailable = true;

            }
        }

    }
}
