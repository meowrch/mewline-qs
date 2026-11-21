import QtQuick
import qs.Core.Components
import qs.Modules.Clipboard
import qs.Modules.Emoji
import qs.Modules.Launcher
import qs.Modules.Settings
import qs.Modules.ThemeSelector
import qs.Modules.WallpaperSelector

Item {
    id: root

    // Bar & media sockets
    WidgetLoader {
        widgetId: "dashboard"
    }

    WidgetLoader {
        widgetId: "controlCenter"
    }

    // Virtual ids: no window of their own — ConvexRightHost renders the
    // control-center host straight on the wifi (page 1) / bluetooth (page 2)
    // device lists when these widgets are active. The loaders exist only to
    // provide the /tmp/quickshell_* sockets for the sxhkd binds.
    WidgetLoader {
        widgetId: "wifiMenu"
    }

    WidgetLoader {
        widgetId: "bluetoothMenu"
    }

    WidgetLoader {
        widgetId: "notificationsCenter"
    }

    WidgetLoader {
        widgetId: "music"
    }

    WidgetLoader {
        widgetId: "calendar"
    }

    WidgetLoader {
        widgetId: "systemUsage"
    }

    // Application & drawer widgets
    WidgetLoader {
        widgetId: "launcher"

        sourceComponent: Component {
            Launcher {
            }

        }

    }

    WidgetLoader {
        widgetId: "clipboard"

        sourceComponent: Component {
            Clipboard {
            }

        }

    }

    WidgetLoader {
        widgetId: "emoji"

        sourceComponent: Component {
            Emoji {
            }

        }

    }

    WidgetLoader {
        widgetId: "wallpaper"

        sourceComponent: Component {
            WallpaperSelector {
            }

        }

    }

    WidgetLoader {
        widgetId: "pawlette"

        sourceComponent: Component {
            ThemeSelector {
            }

        }

    }

    WidgetLoader {
        widgetId: "powerMenu"
    }

    // Standalone application windows
    WidgetLoader {
        widgetId: "mewline_settings"
        exclusive: false

        sourceComponent: Component {
            Settings {
            }

        }

    }

}
