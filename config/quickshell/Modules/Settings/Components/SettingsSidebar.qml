import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

AppSidebar {
    id: sidebarRoot

    property int activeTab: 0

    signal tabClicked(int index)

    title: "SETTINGS"
    subtitle: "PREFERENCES & CUSTOMIZATION"

    // Section 1: DESKTOP
    SidebarSectionLabel {
        text: "DESKTOP"
    }

    // Appearance (Tab 0)
    SidebarNavItem {
        iconName: "color-palette"
        labelText: "Appearance"
        isActive: sidebarRoot.activeTab === 0
        onRowClicked: sidebarRoot.tabClicked(0)
    }

    // Wallpaper (Tab 3)
    SidebarNavItem {
        iconName: "picture"
        labelText: "Wallpaper"
        isActive: sidebarRoot.activeTab === 3
        onRowClicked: sidebarRoot.tabClicked(3)
    }

    // Desktop Bar (Tab 1)
    SidebarNavItem {
        iconName: "bar"
        labelText: "Desktop Bar"
        isActive: sidebarRoot.activeTab === 1
        onRowClicked: sidebarRoot.tabClicked(1)
    }

    // Section 2: ABOUT
    SidebarSectionLabel {
        text: "ABOUT"
        sectionTopMargin: Constants.sizeSm
    }

    // About System (Tab 2 - System Info)
    SidebarNavItem {
        iconName: "info"
        labelText: "About System"
        isActive: sidebarRoot.activeTab === 2
        onRowClicked: sidebarRoot.tabClicked(2)
    }

    Item {
        Layout.preferredHeight: Constants.sizeMd
    }

}
