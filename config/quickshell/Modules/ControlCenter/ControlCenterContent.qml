import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.ControlCenter.Widgets.PerformanceWidget
import qs.Modules.ControlCenter.Widgets.QuickSettings

ColumnLayout {
    id: root

    property var widget: null
    property var notificationService: null
    // Page the embedded QuickSettings opens on: 0 main tiles, 1 wifi networks,
    // 2 bluetooth devices. Hosts bind it per widget id so wifiMenu and
    // bluetoothMenu land straight on their device list.
    property int initialPage: 0
    readonly property bool isWidgetOpen: widget ? (widget.isOpen !== undefined ? widget.isOpen : true) : true

    // This instance is reused across open/close cycles and between widget ids,
    // so the initial page is applied on construction, on every initialPage
    // change while the menu is open (id switches reuse the open panel), and by
    // QuickSettings itself on the open transition.
    function applyInitialPage() {
        if (root.isWidgetOpen && quickSettings)
            quickSettings.activePageIndex = root.initialPage;

    }

    Component.onCompleted: root.applyInitialPage()
    onInitialPageChanged: root.applyInitialPage()

    function resetViews() {
        if (quickSettings && typeof quickSettings.resetView === "function")
            quickSettings.resetView();

    }

    spacing: Constants.sizeLg
    implicitWidth: Math.max(500, quickSettings.implicitWidth)
    Layout.fillWidth: true
    Layout.fillHeight: true

    Connections {
        function onFullyClosed() {
            root.resetViews();
        }

        target: root.widget
        ignoreUnknownSignals: true
    }

    QuickSettings {
        id: quickSettings

        Layout.fillWidth: true
        Layout.fillHeight: true
        quickSettingsOpen: root.isWidgetOpen
        initialPage: root.initialPage
        notificationService: root.notificationService
        extraExpandedHeight: performanceWidget.implicitHeight + root.spacing
    }

    PerformanceWidget {
        id: performanceWidget

        Layout.fillWidth: true
        visible: quickSettings.activePageIndex === 0
    }

}
