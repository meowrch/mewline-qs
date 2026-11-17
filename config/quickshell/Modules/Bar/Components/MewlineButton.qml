import QtQuick
import QtQuick.Effects
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

    // The mewline cat silhouette, tinted with the palette accent so it
    // stays visible on any palette (dark themes get a light cat, light
    // themes a dark one).
    // visible is gated on the image being ready — mirrors the avatar recipe
    // in MeowrchInfoCard, whose layer chain is known to render reliably.
    Item {
        id: logoWrap

        anchors.centerIn: parent
        width: root.iconSize + Constants.sizeXs
        height: root.iconSize
        implicitWidth: root.iconSize + Constants.sizeXs
        implicitHeight: root.iconSize

        Image {
            id: catImg

            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: "file://" + Quickshell.shellDir + "/assets/meowrch/cat-silhouette.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1
                colorizationColor: Theme.accent
            }
        }

    }

}
