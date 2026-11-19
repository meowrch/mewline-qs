import QtQuick
import QtQuick.Layouts
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
        title: "Wireless Device Batteries"
        icon: "device-headset"

        SettingSegmented {
            label: "Position"
            description: "A separate island; hidden when no device reports a battery"
            currentValue: SettingsService.deviceBatteryPosition
            model: [{text: "Left", value: "left"}, {text: "Right", value: "right"}, {text: "Off", value: "off"}]
            onActivated: value => SettingsService.deviceBatteryPosition = value
        }

        SettingSegmented {
            label: "Display"
            description: "Auto shows percentages for one or two devices and bars for three"
            currentValue: SettingsService.deviceBatteryDisplayMode
            model: [{text: "Auto", value: "auto"}, {text: "Percent", value: "percent"}, {text: "Bar", value: "bar"}]
            onActivated: value => SettingsService.deviceBatteryDisplayMode = value
        }

        SettingToggle {
            label: "BatteryHub Backend"
            description: "Optional wireless-battery --json for supported USB receivers (every 60s)"
            bindTarget: SettingsService
            bindProperty: "deviceBatteryUseBatteryHub"
        }

        ThemedText {
            text: !SettingsService.deviceBatteryUseBatteryHub ? "Using Linux / Bluetooth battery readings only." : (DeviceBatteryService.batteryHubError ? "BatteryHub: " + DeviceBatteryService.batteryHubError : (DeviceBatteryService.batteryHubAvailable ? "BatteryHub detected. Linux / Bluetooth readings are also enabled." : "BatteryHub not detected yet. Linux / Bluetooth readings work without it."))
            wrapMode: Text.Wrap
            color: Theme.muted
            customSize: Constants.sizeSm
            Layout.fillWidth: true
        }
    }

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
