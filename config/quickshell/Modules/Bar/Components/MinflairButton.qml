import QtQuick
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar

BarButton {
    id: root

    property int iconSize: Constants.size2Xl + 4

    widgetId: "dashboard"
    implicitWidth: logoWrap.implicitWidth
    implicitHeight: logoWrap.implicitHeight
    height: implicitHeight

    // Static meowrch logo instead of the spinning minflair star. Wrapped in
    // an Item because Image derives implicitWidth/implicitHeight from the
    // bitmap (read-only), and the button needs a fixed square layout box.
    Item {
        id: logoWrap

        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        implicitWidth: root.iconSize
        implicitHeight: root.iconSize

        Image {
            anchors.fill: parent
            // Vector logo from the meowrch Branding repo: stays crisp at
            // any bar height, unlike the 1000px raster fallback.
            source: "file://" + Quickshell.shellDir + "/assets/meowrch/logo.svg"
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
        }

    }

}
