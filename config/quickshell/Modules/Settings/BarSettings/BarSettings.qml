import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components

AppContainer {
    id: barSettingsRoot

    AppGroup {
        title: "Clock Format"
        icon: "clock"

        SettingToggle {
            label: "24-Hour Time"
            description: "Use 24-hour time format instead of 12-hour AM/PM"
            bindTarget: SettingsService
            bindProperty: "clock24h"
        }

        SettingToggle {
            label: "Show Seconds"
            description: "Display seconds on the main clock"
            bindTarget: SettingsService
            bindProperty: "clockSeconds"
        }

        SettingToggle {
            label: "Show Date"
            description: "Display the current date next to the clock"
            bindTarget: SettingsService
            bindProperty: "clockShowDate"
        }

    }

    AppGroup {
        title: "Workspaces"
        icon: "slider"

        SettingSpinBox {
            label: "Number of Workspaces"
            description: "Set the total number of workspaces shown on the bar"
            value: SettingsService.numberOfWorkspaces
            from: 1
            to: 20
            stepSize: 1
            decimals: 0
            suffix: ""
            onMoved: (val) => {
                SettingsService.numberOfWorkspaces = val;
            }
        }

    }

}
