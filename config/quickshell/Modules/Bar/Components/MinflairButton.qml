import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar

BarButton {
    id: root

    property int iconSize: Constants.size2Xl + 4

    widgetId: "dashboard"
    implicitWidth: logo.implicitWidth
    implicitHeight: logo.implicitHeight
    height: implicitHeight

    // Static meowrch logo instead of the spinning minflair star.
    Image {
        id: logo

        anchors.centerIn: parent
        source: "file://" + Quickshell.shellDir + "/assets/meowrch/meowrch-logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        // Square layout box so the pill width stays stable while loading.
        implicitWidth: root.iconSize
        implicitHeight: root.iconSize
    }

}
