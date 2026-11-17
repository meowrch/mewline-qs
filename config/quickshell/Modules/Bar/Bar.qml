import QtQuick
import "Styles/Convex"
import qs.Core
import qs.Core.Services

Item {
    id: mainBar

    required property var notificationService
    property var mainPanelWidget: null
    property string activeBarStyle: "convex"
    // When false the active style is not instantiated, letting a host window
    // stay mapped without building a bar it will not display.
    property bool styleEnabled: true
    readonly property bool isCurrentConvex: activeBarStyle === "convex"
    // Use unified interface exposed by IBarStyle implementation
    readonly property QtObject currentStyleItem: convexLoader.item
    readonly property real leftWidth: currentStyleItem ? (currentStyleItem.leftWidth || 0) : 0
    readonly property real rightWidth: currentStyleItem ? (currentStyleItem.rightWidth || 0) : 0
    readonly property real centerX: currentStyleItem ? (currentStyleItem.centerX || 0) : 0
    readonly property real centerWidth: currentStyleItem ? (currentStyleItem.centerWidth || 0) : 0
    readonly property bool isOccupied: currentStyleItem ? (currentStyleItem.isOccupied || false) : false
    readonly property bool isExpanded: currentStyleItem ? (currentStyleItem.isExpanded || false) : false
    readonly property real currentHeight: (currentStyleItem && currentStyleItem.currentHeight > 0) ? currentStyleItem.currentHeight : 0
    readonly property bool isOverlayActive: currentStyleItem ? (currentStyleItem.isOverlayActive || false) : false
    readonly property bool isOpen: currentStyleItem ? (currentStyleItem.isOpen || false) : false
    readonly property bool needsFocus: currentStyleItem ? (currentStyleItem.needsFocus || false) : false
    readonly property real blockX: currentStyleItem ? (currentStyleItem.blockX || 0) : 0
    readonly property real blockY: currentStyleItem ? (currentStyleItem.blockY || 0) : 0
    readonly property real blockWidth: currentStyleItem ? (currentStyleItem.blockWidth || 0) : 0
    readonly property real blockHeight: currentStyleItem ? (currentStyleItem.blockHeight || 0) : 0

    function close() {
        if (currentStyleItem && typeof currentStyleItem.close === "function")
            currentStyleItem.close();

    }

    implicitWidth: currentStyleItem && currentStyleItem.implicitWidth > 0 ? currentStyleItem.implicitWidth : 0

    Loader {
        id: convexLoader

        anchors.fill: parent
        active: mainBar.isCurrentConvex && mainBar.styleEnabled
        visible: active
        sourceComponent: convexComp
        enabled: visible
    }

    Component {
        id: convexComp

        ConvexBar {
            notificationService: mainBar.notificationService
            mainPanelWidget: mainBar.mainPanelWidget
        }

    }

}
