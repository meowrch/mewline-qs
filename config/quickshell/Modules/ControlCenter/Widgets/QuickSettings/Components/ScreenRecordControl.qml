import QtQuick
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

QuickSettingsTile {
    id: root

    // Screen recording through the shared RecorderService / record.sh flow:
    // picking the tile selects a region via slurp and starts wf-recorder;
    // picking it again stops the recording (saved to ~/Videos/Recordings).
    // wf-recorder is optional — say "Not installed" instead of doing nothing.
    property bool recorderAvailable: false
    property bool isVisible: false

    onIsVisibleChanged: {
        if (isVisible) {
            availabilityProbe.running = false;
            availabilityProbe.running = true;
        }
    }

    isActive: RecorderService.running
    icon: isActive ? "record-icon" : "record-area"
    label: "Screen Record"
    subtitle: {
        if (!root.recorderAvailable)
            return "Not installed";

        return isActive ? RecorderService.formattedTime() : "Off";
    }
    onMenuClicked: clicked()
    onClicked: {
        if (!root.recorderAvailable)
            return ;

        if (RecorderService.running) {
            RecorderService.toggle();
        } else {
            // Get the control center out of the way before the area picker.
            AppState.closeAllWidgets();
            RecorderService.toggle(["-r"]);
        }
    }

    Component.onCompleted: availabilityProbe.running = true

    Process {
        id: availabilityProbe

        command: ["sh", "-c", "command -v wf-recorder"]

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim() !== "")
                    root.recorderAvailable = true;

            }
        }

    }
}
