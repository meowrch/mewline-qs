import QtQuick
import qs.Core
import qs.Core.Services
pragma Singleton

QtObject {
    id: root

    property var _styles: ({
        "convex": {
            "hasFrame": true,
            "hasExpandableHost": false,
            "usesFloatingPopups": true,
            "isPill": false
        },
        "gaming": {
            "hasFrame": false,
            "hasExpandableHost": false,
            "usesFloatingPopups": true,
            "isPill": false
        }
    })

    function styleOf(style) {
        return _styles[style] || _styles["convex"];
    }

    function barHeight(style) {
        if (style === "gaming")
            return Constants.gamingBarHeight;

        return 40; // convex
    }

    function barMarginTop(style) {
        return 0;
    }

    function barMarginSide(style) {
        return 0;
    }

    function isPill(style) {
        return false;
    }

    function isExpandable(style) {
        return false;
    }

}
