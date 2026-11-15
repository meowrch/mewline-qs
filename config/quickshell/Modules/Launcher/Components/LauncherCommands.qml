import QtQuick

// Launcher quick commands: applications shipped with Minflair that are opened
// through AppState instead of their .desktop entry. They are rendered as plain
// text rows (no icon) and matched by name and keywords.
QtObject {
    id: root

    readonly property var items: [{
        "name": "Settings",
        "subtitle": "Minflair",
        "widgetId": "minflair_settings",
        "keywords": ["config", "configuration", "settings", "ajustes", "configuracion", "preferences"]
    }]
}
