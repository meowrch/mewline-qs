import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Core
import qs.Core.Services

Item {
    id: root

    property bool hasFrame: true
    property bool isShellReady: false
    property int barHeight: Constants.size4Xl
    property string activeBarStyle: "convex"
    property int bezelSize: DisplayProfileService.gameModeActive ? 0 : Constants.sizeXs
    property int innerRadius: Constants.size4Xl
    property real fsTransitionProg: 1
    property bool enableTransitionAnim: false
    property real expandOffset: (hasFrame && isShellReady && fsTransitionProg > 0.01) ? 0 : 28
    property real topBezelProg: 0

    anchors.fill: parent
    anchors.topMargin: barHeight
    opacity: (hasFrame && isShellReady) ? fsTransitionProg : 0
    visible: opacity > 0.001
    layer.enabled: false

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Theme.bg
            fillRule: ShapePath.OddEvenFill

            PathSvg {
                path: {
                    let W = Math.round(root.width);
                    let H = Math.round(root.height);
                    let b = root.bezelSize * root.fsTransitionProg;
                    let r = root.innerRadius;
                    let off = root.expandOffset;
                    let topBezel = (root.barHeight * root.topBezelProg) * root.fsTransitionProg;
                    let inX = b - off;
                    let inY = topBezel - off;
                    let inW = W - 2 * b + 2 * off;
                    let inH = H - topBezel - b + 2 * off;
                    if (W <= 0 || H <= 0)
                        return "";

                    let k = r * 0.552285;
                    // Outer contour is a plain rectangle on both platforms.
                    // Neither compositor rounds this surface in practice:
                    // Hyprland leaves layer-shell windows alone, and picom
                    // skips its own rounded-corners for XShape-shaped dock
                    // windows (the QML mask), so corner-radius rules in
                    // picom.conf never fire. Carving the corners in the path
                    // (r=innerRadius in d575019, then decoration:rounding=10)
                    // only pushed the fill away from the screen corner and
                    // left a wallpaper gap; the frame corner is filled square
                    // and the inner hole arc does the rounding.
                    let outer = `M 0 0 L ${W} 0 L ${W} ${H} L 0 ${H} Z `;
                    let inner = `M ${inX} ${inY + r} ` + `L ${inX} ${inY + inH - r} ` + `C ${inX} ${inY + inH - r + k}, ${inX + r - k} ${inY + inH}, ${inX + r} ${inY + inH} ` + `L ${inX + inW - r} ${inY + inH} ` + `C ${inX + inW - r + k} ${inY + inH}, ${inX + inW} ${inY + inH - r + k}, ${inX + inW} ${inY + inH - r} ` + `L ${inX + inW} ${inY + r} ` + `C ${inX + inW} ${inY + r - k}, ${inX + inW - r + k} ${inY}, ${inX + inW - r} ${inY} ` + `L ${inX + r} ${inY} ` + `C ${inX + r - k} ${inY}, ${inX} ${inY + r - k}, ${inX} ${inY + r} Z`;
                    return outer + inner;
                }
            }

        }

    }

    Behavior on expandOffset {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: (root.hasFrame) ? Easing.OutCubic : Easing.InCubic
        }

    }

}
