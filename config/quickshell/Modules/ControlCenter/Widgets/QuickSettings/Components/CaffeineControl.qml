import QtQuick

QuickSettingsTile {
    id: root

    // Shared DND state owned by NotificationService (passed down from shell.qml).
    // The calendar/notification center DND switch binds to the exact same
    // property, so both toggles stay in sync two-way.
    property var notificationService: null

    isActive: root.notificationService ? root.notificationService.dndEnabled : false
    icon: isActive ? "bell-off" : "bell"
    label: "Do Not Disturb"
    subtitle: isActive ? "On" : "Off"
    onMenuClicked: clicked()
    onClicked: {
        if (root.notificationService)
            root.notificationService.dndEnabled = !root.notificationService.dndEnabled;

    }
}
