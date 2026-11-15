import QtQuick
import Quickshell
import qs.Core
import qs.Core.Components

QuickSettingsTile {
    id: root

    // Action tile (not a toggle): pick a screen region, extract its text,
    // copy it to the clipboard and raise a notification. The heavy lifting
    // lives in Scripts/system/ocr.sh, run detached like screenshot.sh.
    isActive: false
    icon: "ocr"
    label: "OCR"
    subtitle: "Extract text"
    onMenuClicked: clicked()
    onClicked: {
        let scriptPath = Quickshell.shellDir + "/Scripts/system/ocr.sh";
        Quickshell.execDetached(["bash", scriptPath]);
    }
}
