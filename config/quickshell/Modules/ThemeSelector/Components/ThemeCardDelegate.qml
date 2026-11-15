import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

// Mirror of WallpaperCardDelegate: rounded card, image/logo fill, bottom
// gradient with the centered name and an accent border while current.
Item {
    id: delegateRoot

    property var selectorRoot: null
    property var targetView: null
    required property int index
    required property string name
    required property string logo
    required property var variants
    readonly property bool isDynamicTile: name === "__dynamic__"
    readonly property bool isRandomTile: name === "__random__"
    readonly property bool isSpecial: isDynamicTile || isRandomTile
    readonly property string displayName: {
        if (isDynamicTile)
            return "Dynamic";

        if (isRandomTile)
            return "Random";

        return name.replace(/-/g, " ").replace(/_/g, " ");
    }
    readonly property color previewColor: {
        let keys = Object.keys(variants || {});
        if (keys.length > 0) {
            let c = variants[keys[0]];
            if (c)
                return c;

        }
        return Theme.bgAccent;
    }
    readonly property bool isCurrent: ListView.isCurrentItem || (targetView && targetView.currentIndex === index)

    width: selectorRoot ? selectorRoot.cardItemWidth : 0
    height: selectorRoot ? selectorRoot.cardItemHeight : 0
    z: isCurrent ? 5 : (hoverHandler.hovered ? 3 : 1)

    Rectangle {
        id: cardBg

        anchors.fill: parent
        radius: Constants.sizeLg
        color: Theme.bgSecondary

        Item {
            id: imageMaskContainer

            anchors.fill: parent
            anchors.margins: cardBorder.border.width
            layer.enabled: true

            // Special tiles keep the meowrch icon on a soft accent wash.
            Rectangle {
                anchors.fill: parent
                visible: delegateRoot.isSpecial
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0
                        color: Qt.rgba(delegateRoot.previewColor.r, delegateRoot.previewColor.g, delegateRoot.previewColor.b, 0.35)
                    }

                    GradientStop {
                        position: 1
                        color: Theme.bg
                    }

                }

            }

            Image {
                id: specialIcon

                visible: delegateRoot.isSpecial
                anchors.centerIn: parent
                source: {
                    if (delegateRoot.isDynamicTile)
                        return PawletteService.dynamicEnabled ? Quickshell.shellDir + "/assets/meowrch/dynamic-theme-on-logo.png" : Quickshell.shellDir + "/assets/meowrch/dynamic-theme-off-logo.png";

                    return Quickshell.shellDir + "/assets/meowrch/random.png";
                }
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                opacity: (specialIcon.status === Image.Ready && !delegateRoot.isRandomTile) || delegateRoot.isRandomTile ? 1 : 0.85
            }

            // Theme logo fills the card like a wallpaper preview.
            Image {
                id: logoImg

                visible: !delegateRoot.isSpecial
                anchors.fill: parent
                source: (!delegateRoot.isSpecial && delegateRoot.logo !== "") ? "file://" + delegateRoot.logo : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize: Qt.size(450, 270)
                mipmap: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // Logoless themes get their variant color as the preview fill.
            Rectangle {
                visible: !delegateRoot.isSpecial && delegateRoot.logo === "" || (!delegateRoot.isSpecial && logoImg.status !== Image.Ready && delegateRoot.logo !== "")
                anchors.fill: parent
                color: delegateRoot.previewColor
                opacity: 0.8
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.55

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 0.35
                        color: Qt.rgba(Theme.black.r, Theme.black.g, Theme.black.b, 0.35)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(Theme.black.r, Theme.black.g, Theme.black.b, 0.85)
                    }

                }

            }

            layer.effect: MultiEffect {
                maskEnabled: true
                // Keep a real 0..1 alpha ramp so the antialiased rounded
                // corners are not promoted to fully opaque.
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1

                maskSource: ShaderEffectSource {
                    visible: false
                    hideSource: true
                    smooth: true

                    sourceItem: Rectangle {
                        width: imageMaskContainer.width
                        height: imageMaskContainer.height
                        radius: Math.max(0, Constants.sizeLg - cardBorder.border.width)
                        antialiasing: true
                        color: Theme.white
                    }

                }

            }

        }

        // Dynamic tile state dot
        Rectangle {
            visible: delegateRoot.isDynamicTile
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Constants.sizeSm
            width: 14
            height: 14
            radius: 7
            color: PawletteService.dynamicEnabled ? Theme.accent : Theme.muted
            border.color: Theme.bg
            border.width: 2
            z: 11
        }

        ThemedText {
            id: nameText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Constants.sizeSm
            text: delegateRoot.displayName
            customSize: Constants.sizeSm
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: Theme.white
            font.bold: delegateRoot.isCurrent
            z: 11

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }

            }

        }

        Rectangle {
            id: cardBorder

            anchors.fill: parent
            radius: Constants.sizeLg
            color: "transparent"
            border.color: delegateRoot.isCurrent ? Theme.accent : (hoverHandler.hovered ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35) : Theme.border)
            border.width: delegateRoot.isCurrent ? 2 : 1
            z: 10

            Behavior on border.color {
                ColorAnimation {
                    duration: Constants.animFast
                }

            }

            Behavior on border.width {
                NumberAnimation {
                    duration: Constants.animFast
                }

            }

        }

    }

    HoverHandler {
        id: hoverHandler

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            if (delegateRoot.targetView)
                delegateRoot.targetView.currentIndex = delegateRoot.index;

            if (delegateRoot.selectorRoot) {
                delegateRoot.selectorRoot.ensureVisible(delegateRoot.index);
                delegateRoot.selectorRoot.activateIndex(delegateRoot.index);
            }
        }
    }

}
