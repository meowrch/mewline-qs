import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.ThemeSelector.Components

Item {
    id: root

    property var widget: null
    property string searchText: ""
    property alias initialFocusItem: searchField
    property int visibleCards: 4
    readonly property int cardItemWidth: 240
    readonly property int cardItemHeight: 162
    readonly property int searchBarHeight: 38
    readonly property int cardSpacing: Constants.sizeLg
    readonly property int layoutSpacing: Constants.sizeLg
    readonly property int variantsRowHeight: 72
    property bool variantsOpen: false
    property string variantsTheme: ""
    property var variantsColors: ({})

    implicitWidth: (visibleCards * cardItemWidth) + Math.max(0, (visibleCards - 1) * cardSpacing)
    implicitHeight: searchBarHeight + layoutSpacing + cardItemHeight + (variantsOpen ? layoutSpacing * 0.6 + variantsRowHeight : 0)
    width: implicitWidth
    height: implicitHeight
    focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: (event) => {
        return root.handleKey(event);
    }
    Component.onCompleted: {
        resetSelector();
    }

    function resetSelector() {
        scrollAnim.stop();
        themeView.contentX = 0;
        searchField.text = "";
        root.closeVariants();
        root.rebuildModel();
        searchField.forceActiveFocus();
        PawletteService.refreshThemes();
    }

    function closeVariants() {
        root.variantsOpen = false;
        root.variantsTheme = "";
        root.variantsColors = {};
    }

    function openVariants(theme) {
        root.variantsTheme = theme.name;
        root.variantsColors = theme.variants || {};
        root.variantsOpen = true;
        variantView.currentIndex = 0;
    }

    function applyTheme(name, variant) {
        PawletteService.applyTheme(name, variant);
        root.closePopup();
    }

    function rebuildModel() {
        filteredModel.clear();
        let query = searchField.text.toLowerCase();
        filteredModel.append({
            "name": "__dynamic__",
            "logo": "",
            "variants": {}
        });
        filteredModel.append({
            "name": "__random__",
            "logo": "",
            "variants": {}
        });
        let themes = PawletteService.themes || [];
        for (let i = 0; i < themes.length; i++) {
            let theme = themes[i];
            if (query !== "" && theme.name.toLowerCase().indexOf(query) === -1)
                continue;

            filteredModel.append({
                "name": theme.name,
                "logo": theme.logo || "",
                "variants": theme.variants || {}
            });
        }
        if (filteredModel.count > 2)
            themeView.currentIndex = 2;
        else
            themeView.currentIndex = -1;
    }

    function selectIndex(idx) {
        if (filteredModel.count === 0)
            return ;

        // Wrap around so arrows can cycle the list in one direction.
        let count = filteredModel.count;
        let newIdx = ((idx % count) + count) % count;
        themeView.currentIndex = newIdx;
        root.ensureVisible(newIdx);
    }

    function ensureVisible(index) {
        if (index < 0 || index >= filteredModel.count)
            return ;

        let spacing = root.cardSpacing;
        let step = root.cardItemWidth + spacing;
        let cardsPerView = root.visibleCards;
        let maxScroll = Math.max(0, (filteredModel.count - cardsPerView) * step);
        let currentX = themeView.contentX;
        let firstVisibleIndex = Math.floor((currentX + 5) / step);
        let lastVisibleIndex = firstVisibleIndex + cardsPerView - 1;
        let targetX = currentX;
        if (index < firstVisibleIndex)
            targetX = index * step;
        else if (index > lastVisibleIndex)
            targetX = (index - cardsPerView + 1) * step;
        targetX = Math.max(0, Math.min(targetX, maxScroll));
        if (Math.abs(targetX - currentX) > 1) {
            scrollAnim.stop();
            scrollAnim.from = currentX;
            scrollAnim.to = targetX;
            scrollAnim.start();
        }
    }

    function activateIndex(idx) {
        if (idx < 0 || idx >= filteredModel.count)
            return ;

        let theme = filteredModel.get(idx);
        if (theme.name === "__dynamic__") {
            PawletteService.toggleDynamic();
            root.closePopup();
            return ;
        }
        if (theme.name === "__random__") {
            PawletteService.applyRandom();
            root.closePopup();
            return ;
        }
        let variantCount = Object.keys(theme.variants || {}).length;
        if (variantCount === 0)
            root.applyTheme(theme.name, "default");
        else
            root.openVariants(theme);
    }

    function applyVariant(idx) {
        if (!root.variantsTheme)
            return ;

        let names = Object.keys(root.variantsColors);
        if (idx < 0 || idx >= names.length)
            return ;

        root.applyTheme(root.variantsTheme, names[idx]);
    }

    function closePopup() {
        if (root.widget && root.widget.close !== undefined)
            root.widget.close();
        else
            AppState.activeWidget = "";
    }

    function handleAction(action) {
        if (root.variantsOpen) {
            if (action === "right") {
                variantView.currentIndex = Math.min(variantModel.count - 1, variantView.currentIndex + 1);
            } else if (action === "left") {
                variantView.currentIndex = Math.max(0, variantView.currentIndex - 1);
            } else if (action === "enter") {
                root.applyVariant(variantView.currentIndex);
            } else if (action === "up" || action === "esc") {
                root.closeVariants();
            }
            return ;
        }
        if (action === "right") {
            root.selectIndex(themeView.currentIndex + 1);
        } else if (action === "left") {
            root.selectIndex(themeView.currentIndex - 1);
        } else if (action === "down") {
            let dIdx = themeView.currentIndex >= 0 ? themeView.currentIndex : 0;
            if (dIdx >= 2 && dIdx < filteredModel.count) {
                let dTheme = filteredModel.get(dIdx);
                if (Object.keys(dTheme.variants || {}).length > 0)
                    root.openVariants(dTheme);

            }
        } else if (action === "enter") {
            root.activateIndex(themeView.currentIndex >= 0 ? themeView.currentIndex : 0);
        } else if (action === "esc") {
            root.closePopup();
        }
    }

    function handleKey(event) {
        if (root.variantsOpen) {
            if (event.key === Qt.Key_Left) {
                variantView.currentIndex = Math.max(0, variantView.currentIndex - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                variantView.currentIndex = Math.min(variantModel.count - 1, variantView.currentIndex + 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applyVariant(variantView.currentIndex);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                root.closeVariants();
                event.accepted = true;
            }
            return ;
        }
        if (event.key === Qt.Key_Right) {
            root.selectIndex(themeView.currentIndex + 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.selectIndex(themeView.currentIndex - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            // Drop into the accent variants of the selected theme.
            let idx = themeView.currentIndex >= 0 ? themeView.currentIndex : 0;
            if (idx >= 2 && idx < filteredModel.count) {
                let theme = filteredModel.get(idx);
                if (Object.keys(theme.variants || {}).length > 0)
                    root.openVariants(theme);

            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            root.selectIndex(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.selectIndex(filteredModel.count - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            let idx = themeView.currentIndex >= 0 ? themeView.currentIndex : 0;
            root.activateIndex(idx);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.closePopup();
            event.accepted = true;
        }
    }

    Connections {
        function onThemesRefreshed() {
            root.rebuildModel();
        }

        target: PawletteService
    }

    NumberAnimation {
        id: scrollAnim

        target: themeView
        property: "contentX"
        duration: Constants.animSlow
        easing.type: Easing.OutQuint
    }

    ListModel {
        id: filteredModel
    }

    ListModel {
        id: variantModel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.layoutSpacing

        Item {
            id: topSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            visible: !SettingsService.barConvexMode
        }

        Item {
            id: themeContainer

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.cardItemHeight

            GhostEmptyState {
                anchors.centerIn: parent
                visible: filteredModel.count <= 2 && !PawletteService.themesLoading
                text: PawletteService.installed ? "No themes match the search" : "pawlette not installed or has no themes"
                isAnimating: visible
            }

            ListView {
                id: themeView

                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: root.cardSpacing
                clip: true
                model: filteredModel
                currentIndex: -1
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                visible: filteredModel.count > 0

                add: Transition {
                    NumberAnimation {
                        properties: "opacity"
                        from: 0
                        to: 1
                        duration: Constants.animNormal
                        easing.type: Easing.OutQuint
                    }

                }

                populate: Transition {
                    NumberAnimation {
                        properties: "opacity"
                        from: 0
                        to: 1
                        duration: Constants.animNormal
                        easing.type: Easing.OutQuint
                    }

                }

                delegate: ThemeCardDelegate {
                    selectorRoot: root
                    targetView: themeView
                }

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

            }

        }

        Item {
            id: variantsContainer

            Layout.fillWidth: true
            Layout.preferredHeight: root.variantsOpen ? root.variantsRowHeight : 0
            visible: root.variantsOpen
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }

            }

            ListView {
                id: variantView

                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: root.cardSpacing
                clip: true
                currentIndex: 0
                highlightFollowsCurrentItem: false
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                model: variantModel

                // Variant "cards" follow the wallpaper card language: a rounded
                // rectangle filled with the accent color and the variant name
                // on a bottom gradient.
                delegate: Item {
                    id: variantCard

                    required property string name
                    required property int index
                    readonly property bool isCurrent: ListView.isCurrentItem
                    readonly property bool isApplied: PawletteService.lastAppliedTheme === root.variantsTheme && PawletteService.lastAppliedVariant === variantCard.name
                    readonly property color fillColor: root.variantsColors[variantCard.name] ? root.variantsColors[variantCard.name] : Theme.bgSecondary
                    readonly property string displayName: variantCard.name === "default" ? "Default" : variantCard.name.replace(/-/g, " ").replace(/_/g, " ")

                    width: 160
                    height: root.variantsRowHeight

                    Rectangle {
                        id: variantBg

                        anchors.fill: parent
                        radius: Constants.sizeMd
                        color: variantCard.fillColor
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * 0.6

                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "transparent"
                                }

                                GradientStop {
                                    position: 1
                                    color: Qt.rgba(Theme.black.r, Theme.black.g, Theme.black.b, 0.75)
                                }

                            }

                        }

                        ThemedText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Constants.sizeXs
                            text: variantCard.displayName
                            customSize: Constants.sizeXs
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: variantCard.isApplied ? Theme.accent : Theme.white
                            font.bold: variantCard.isApplied
                            z: 11
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Constants.sizeMd
                            color: "transparent"
                            border.color: variantCard.isApplied ? Theme.accent : (variantCard.isCurrent ? Theme.accent : Theme.border)
                            border.width: variantCard.isApplied || variantCard.isCurrent ? 2 : 1
                            z: 10
                        }

                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            variantView.currentIndex = variantCard.index;
                            root.applyVariant(variantCard.index);
                        }
                    }

                }

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

            }

        }

        Item {
            id: bottomSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: 38
            visible: SettingsService.barConvexMode
        }

    }

    ThemedSearchBar {
        id: searchField

        parent: SettingsService.barConvexMode ? bottomSearchContainer : topSearchContainer
        anchors.fill: parent
        preferredHeight: 38
        placeholderText: "Search themes..."
        customSize: Constants.sizeMd
        onSearchRequested: (text) => {
            return root.rebuildModel();
        }
        textField.Keys.priority: Keys.BeforeItem
        textField.Keys.onPressed: (event) => {
            return root.handleKey(event);
        }
    }

    onVariantsColorsChanged: {
        variantModel.clear();
        let names = Object.keys(root.variantsColors);
        for (let i = 0; i < names.length; i++) {
            variantModel.append({
                "name": names[i]
            });
        }
    }

}
