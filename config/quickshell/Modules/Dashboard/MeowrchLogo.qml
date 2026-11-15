import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core

// The meowrch Branding logo, recolored at runtime to match the active
// pawlette palette. Every colored fill keeps its original lightness but
// takes hue/saturation from Theme.accent, so the shading survives
// re-theming; pure black (the cat) and near-white highlights stay as-is.
// The result is served to the Image as a base64 data URL.
Item {
    id: root

    property real size: 36
    property color tint: Theme.accent
    property string svgText: ""

    implicitWidth: size
    implicitHeight: size

    readonly property string fallbackUrl: "file://" + Quickshell.shellDir + "/assets/meowrch/logo.svg"
    readonly property string themedUrl: {
        let svg = root.svgText;
        if (svg === "")
            return fallbackUrl;

        svg = svg.replace(/#[0-9a-fA-F]{6}/g, function(hex) {
            return root.recolor(hex);
        });
        // Qt.btoa is deprecated (and its array overload returned empty
        // output here), so encode base64 ourselves; the SVG is ASCII.
        let url = "data:image/svg+xml;base64," + root.b64(svg);
        return url;
    }

    function b64(input) {
        const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let out = "";
        for (let i = 0; i < input.length; i += 3) {
            let b0 = input.charCodeAt(i);
            let b1 = i + 1 < input.length ? input.charCodeAt(i + 1) : 0;
            let b2 = i + 2 < input.length ? input.charCodeAt(i + 2) : 0;
            out += chars.charAt(b0 >> 2);
            out += chars.charAt(((b0 & 3) << 4) | (b1 >> 4));
            out += i + 1 < input.length ? chars.charAt(((b1 & 15) << 2) | (b2 >> 6)) : "=";
            out += i + 2 < input.length ? chars.charAt(b2 & 63) : "=";
        }
        return out;
    }

    function recolor(hex) {
        let c = Qt.color(hex);
        // Keep the black cat and white highlights untouched; greys too.
        if (c.hslLightness <= 0.02 || c.hslLightness >= 0.98 || c.hslSaturation < 0.05)
            return hex;

        let t = Qt.color(root.tint);
        // An achromatic theme accent would flatten the artwork to grey.
        if (t.hslSaturation < 0.05)
            return hex;

        // hslHue comes back normalized (0..1) in this Qt build, so convert
        // to degrees for the HSL -> hex math below.
        let hue = t.hslHue > 1.0 ? t.hslHue : t.hslHue * 360;
        return root.fromHsl(hue, t.hslSaturation, c.hslLightness);
    }

    // Standard HSL -> RGB hex conversion.
    function fromHsl(h, s, l) {
        let c = l <= 0.5 ? l * (1 + s) : l + s - l * s;
        let m = 2 * l - c;
        let f = function(p, q, t) {
            if (t < 0)
                t += 1;
            if (t > 1)
                t -= 1;
            if (t < 1 / 6)
                return p + (q - p) * 6 * t;
            if (t < 1 / 2)
                return q;
            if (t < 2 / 3)
                return p + (q - p) * (2 / 3 - t) * 6;
            return p;
        };
        let r = f(m, c, h / 360 + 1 / 3);
        let g = f(m, c, h / 360);
        let b = f(m, c, h / 360 - 1 / 3);
        let toHex = function(v) {
            let x = Math.round(v * 255).toString(16);
            return x.length === 1 ? "0" + x : x;
        };
        return "#" + toHex(r) + toHex(g) + toHex(b);
    }

    Process {
        id: svgLoader

        command: ["cat", Quickshell.shellDir + "/assets/meowrch/logo.svg"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.svgText = text;
            }
        }

    }

    Image {
        anchors.fill: parent
        source: root.themedUrl
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    Component.onCompleted: svgLoader.running = true

}
