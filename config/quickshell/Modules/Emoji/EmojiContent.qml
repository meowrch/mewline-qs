import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property var widget: null
    property string searchText: ""
    property alias initialFocusItem: searchField
    property int preferredContentWidth: 640
    readonly property int searchBarHeight: Constants.size4Xl
    readonly property int layoutSpacing: Constants.sizeSm
    readonly property int cellSize: 56
    readonly property int gridColumns: Math.max(1, Math.floor((preferredContentWidth - Constants.size3Xl * 2) / (cellSize + 4)))
    readonly property int visibleRows: 4
    readonly property int gridHeight: visibleRows * cellSize + (visibleRows - 1) * 4
    property var allEmojis: []
    readonly property var filtered: {
        let query = root.searchText.trim().toLowerCase();
        if (query === "")
            return root.allEmojis;

        return root.allEmojis.filter(function (emoji) {
            return emoji.name.toLowerCase().indexOf(query) !== -1;
        });
    }
    property int selectedIndex: -1
    readonly property bool hasSelection: selectedIndex >= 0 && selectedIndex < root.filtered.length

    function closeWidget() {
        if (root.widget && typeof root.widget.close === "function")
            root.widget.close();
        else if (root.widget && root.widget.isOpen !== undefined)
            root.widget.isOpen = false;
        else
            AppState.activeWidget = "";
    }

    function resetEmoji() {
        root.searchText = "";
        root.selectedIndex = -1;
        emojiListProc.running = true;
        searchField.forceActiveFocus();
    }

    function copySelected(char_) {
        // Session-aware clipboard write; the argument pattern keeps the
        // emoji out of shell parsing (same trick as ClipboardService).
        copyProc.command = ["sh", "-c", CompositorService.isX11 ? "printf '%s' \"$1\" | xclip -selection clipboard" : "printf '%s' \"$1\" | wl-copy", "mewline-emoji", char_];
        copyProc.startDetached();
        OsdService.displayMessage("Emoji", "Copied " + char_, "face-smile", true);
        root.closeWidget();
    }

    function moveSelection(delta) {
        let count = root.filtered.length;
        if (count === 0)
            return ;

        let next = root.selectedIndex + delta;
        if (next < 0)
            next = 0;

        if (next > count - 1)
            next = count - 1;

        root.selectedIndex = next;
        emojiView.positionViewAtIndex(root.selectedIndex, GridView.Contain);
    }

    onSearchTextChanged: {
        root.selectedIndex = -1;
    }

    implicitWidth: preferredContentWidth
    implicitHeight: searchBarHeight + layoutSpacing + gridHeight
    width: parent && parent.width > 0 ? parent.width : implicitWidth
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    Component.onCompleted: root.resetEmoji();

    Process {
        id: emojiListProc

        command: ["python3", Quickshell.shellDir + "/Scripts/system/get_emojis.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    if (Array.isArray(data))
                        root.allEmojis = data;

                } catch (e) {
                    console.error("Emoji list parse error:", e);
                }
            }
        }

    }

    Process {
        id: copyProc

    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.layoutSpacing

        Item {
            id: topSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: Constants.size4Xl
            visible: !SettingsService.barConvexMode
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.gridHeight
            clip: true

            GhostEmptyState {
                anchors.centerIn: parent
                visible: opacity > 0.001
                opacity: root.filtered.length === 0 ? 1 : 0
                text: root.searchText === "" ? "Emoji list is loading..." : "No results found"
                isAnimating: visible

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                        easing.type: Easing.OutCubic
                    }

                }

            }

            GridView {
                id: emojiView

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filtered
                cellWidth: root.cellSize
                cellHeight: root.cellSize
                currentIndex: root.selectedIndex
                highlightMoveDuration: Constants.animFast
                visible: root.filtered.length > 0
                // GridView sections are unavailable in this Quickshell build
                // (verified with a minimal case) — the catalogue arrives
                // pre-sorted by category from get_emojis.py instead.
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Left) {
                        root.moveSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        root.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        root.moveSelection(root.gridColumns);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-root.gridColumns);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.hasSelection)
                            root.copySelected(root.filtered[root.selectedIndex].char);

                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        root.closeWidget();
                        event.accepted = true;
                    }
                }

                highlight: Rectangle {
                    width: root.cellSize
                    height: root.cellSize
                    radius: Constants.sizeXs
                    color: Theme.bgSecondary
                }

                delegate: Item {
                    id: emojiCell
                    width: emojiView.cellWidth
                    height: emojiView.cellHeight

                    required property var modelData
                    readonly property bool selected: emojiView.currentIndex === index

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Constants.sizeMd
                        color: hover.hovered || parent.selected ? Theme.bgSecondary : "transparent"
                    }

                    Text {
                        // Color emoji glyphs ignore this color; monochrome
                        // symbols (arrows, stars, trigrams) tint with the
                        // accent so they stay visible on the dark drawer.
                        color: Theme.accent
                        anchors.centerIn: parent
                        text: emojiCell.modelData.char
                        font.pixelSize: 30
                    }

                    HoverHandler {
                        id: hover

                        onHoveredChanged: {
                            if (hovered)
                                emojiView.currentIndex = index;

                        }
                        onPointChanged: {
                            emojiView.currentIndex = index;
                        }
                    }

                    ThemedTooltip {
                        visible: hover.hovered
                        timeout: 0
                        text: emojiCell.modelData.name
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.copySelected(emojiCell.modelData.char)
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

            }

        }

        Item {
            id: bottomSearchContainer

            Layout.fillWidth: true
            Layout.preferredHeight: Constants.size4Xl
            visible: SettingsService.barConvexMode
        }

    }

    RowLayout {
        id: searchRow

        parent: SettingsService.barConvexMode ? bottomSearchContainer : topSearchContainer
        anchors.fill: parent
        spacing: Constants.sizeXs

        ThemedSearchBar {
            id: searchField

            Layout.fillWidth: true
            preferredHeight: Constants.size4Xl
            placeholderText: "Search emoji..."
            // The list reacts to text changes directly; the signal stays
            // unused but keeps the component contract.
            onSearchRequested: (text) => {
                root.searchText = text;
            }
            // Arrows always drive the grid; Return copies the selection.
            textField.Keys.priority: Keys.BeforeItem
            textField.Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left) {
                    root.moveSelection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.moveSelection(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.moveSelection(root.gridColumns);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.moveSelection(-root.gridColumns);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.hasSelection)
                        root.copySelected(root.filtered[root.selectedIndex].char);

                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.closeWidget();
                    event.accepted = true;
                }
            }
        }

        SvgIconButton {
            icon: "clipboard"
            iconColor: Theme.accent
            iconSize: Constants.sizeXl
            disabled: root.filtered.length === 0
            onClicked: {
                if (root.hasSelection)
                    root.copySelected(root.filtered[root.selectedIndex].char);

            }
        }

    }

}
