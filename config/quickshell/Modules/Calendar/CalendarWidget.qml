import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Notifications.Components
import qs.Modules.NotificationCenter.Components

Item {
    id: root

    property var widget: null
    // Mewline-style popup: notification history on the left, big clock +
    // calendar on the right. The service is injected by the host (convex
    // center panel, island bar, gaming overlay).
    property var notificationService: null
    readonly property int notifPanelWidth: 318
    readonly property int datePanelWidth: 346
    property real calendarWidth: notifPanelWidth + datePanelWidth + Constants.sizeLg * 2
    readonly property bool isVisibleOnScreen: widget !== null && widget.isOpen !== undefined ? widget.isOpen : true
    readonly property var today: SystemInfoService.currentTime
    property int viewMonth: new Date().getMonth()
    property int viewYear: new Date().getFullYear()
    readonly property bool isCurrentMonth: viewMonth === today.getMonth() && viewYear === today.getFullYear()
    // NotificationCenter-style grouping of the notification history
    readonly property int historyCount: notificationService && notificationService.historyList ? notificationService.historyList.count : 0
    readonly property var groupedModel: buildGroups()
    property var expandedGroups: ({
    })
    property bool isClearingAll: false

    function shiftMonth(delta) {
        let m = viewMonth + delta;
        let y = viewYear;
        while (m < 0) {
            m += 12;
            y--;
        }
        while (m > 11) {
            m -= 12;
            y++;
        }
        viewMonth = m;
        viewYear = y;
    }

    function goToToday() {
        const d = new Date();
        viewMonth = d.getMonth();
        viewYear = d.getFullYear();
    }

    function buildGroups() {
        if (!notificationService || !notificationService.historyList)
            return [];

        let groups = [];
        let groupsByKey = ({
        });
        let total = notificationService.historyList.count;
        for (let i = 0; i < total; i++) {
            let row = notificationService.historyList.get(i);
            let nd = row ? row.notifData : null;
            if (!nd)
                continue;

            let appName = (nd.appName || "").trim();
            if (appName === "")
                appName = "Other";

            let key = appName.toLowerCase();
            let group = groupsByKey[key];
            if (!group) {
                group = {
                    "key": key,
                    "appName": appName,
                    "iconData": nd,
                    "latest": nd,
                    "items": []
                };
                groupsByKey[key] = group;
                groups.push(group);
            }
            group.items.push(nd);
            if (!group.iconData.appIcon) {
                if (nd.appIcon)
                    group.iconData = nd;
                else if (!group.iconData.image && nd.image)
                    group.iconData = nd;
            }
            if ((nd.timestamp || 0) > (group.latest.timestamp || 0))
                group.latest = nd;

        }
        return groups;
    }

    function toggleGroup(key) {
        if (!key)
            return ;

        let next = Object.assign({
        }, expandedGroups);
        if (next[key])
            delete next[key];
        else
            next[key] = true;
        expandedGroups = next;
    }

    function clearGroup(group) {
        if (!group || !group.items || !notificationService)
            return ;

        let ids = [];
        for (let i = 0; i < group.items.length; i++) {
            if (group.items[i].notificationId)
                ids.push(group.items[i].notificationId);

        }
        if (ids.length > 0)
            notificationService.removeNotifications(ids);

    }

    function startClearAllAnimation() {
        if (isClearingAll || !notificationService || root.historyCount === 0)
            return ;

        isClearingAll = true;
    }

    onIsVisibleOnScreenChanged: {
        if (!isVisibleOnScreen)
            goToToday();

    }
    implicitWidth: calendarWidth
    implicitHeight: mainRow.implicitHeight
    width: implicitWidth
    height: implicitHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            root.shiftMonth(event.angleDelta.y > 0 ? -1 : 1);
        }
    }

    RowLayout {
        id: mainRow

        anchors.fill: parent
        spacing: Constants.sizeLg

        // LEFT PANEL: NOTIFICATIONS
        ColumnLayout {
            id: notifColumn

            Layout.preferredWidth: root.notifPanelWidth
            Layout.fillHeight: true
            spacing: Constants.sizeSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeXs

                ThemedText {
                    text: "Do Not Disturb"
                    customSize: Constants.sizeSm
                    color: Theme.muted
                }

                Switch {
                    id: dndSwitch

                    enabled: root.notificationService !== null
                    implicitWidth: Constants.size4Xl
                    implicitHeight: Constants.sizeXl + 2

                    Binding {
                        target: dndSwitch
                        property: "checked"
                        value: root.notificationService ? root.notificationService.dndEnabled : false
                        when: root.notificationService !== null
                    }

                    onToggled: {
                        if (root.notificationService)
                            root.notificationService.dndEnabled = checked;

                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    indicator: Rectangle {
                        implicitWidth: Constants.size4Xl
                        implicitHeight: Constants.sizeXl + 2
                        radius: height / 2
                        color: dndSwitch.checked ? Theme.accent : Theme.bgSecondary
                        border.width: 1
                        border.color: dndSwitch.checked ? Theme.accent : Theme.border

                        Behavior on color {
                            ColorAnimation {
                                duration: Constants.animFast
                            }

                        }

                        Rectangle {
                            id: knob

                            x: dndSwitch.checked ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: Constants.sizeLg
                            height: Constants.sizeLg
                            radius: width / 2
                            color: dndSwitch.checked ? Theme.white : Theme.muted

                            Behavior on x {
                                NumberAnimation {
                                    duration: Constants.animFast
                                    easing.type: Easing.OutQuad
                                }

                            }

                        }

                    }

                }

                Item {
                    Layout.fillWidth: true
                }

                SvgIconButton {
                    icon: "trash"
                    iconSize: Constants.sizeSm
                    iconColor: Theme.accent
                    textIcon: "Clear"
                    textIconSize: Constants.sizeSm
                    onClicked: root.startClearAllAnimation()
                    disabled: root.historyCount === 0 || root.isClearingAll
                    useCustomWidth: true
                }

            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    id: emptyState

                    anchors.centerIn: parent
                    spacing: Constants.sizeSm
                    visible: opacity > 0
                    opacity: (root.historyCount === 0 && !root.isClearingAll) ? 1 : 0

                    SvgIcon {
                        icon: "bell"
                        iconSize: Constants.size5Xl
                        iconColor: Theme.muted
                        Layout.alignment: Qt.AlignHCenter
                        flat: true
                    }

                    ThemedText {
                        text: "All caught up!"
                        font.bold: true
                        color: Theme.fg
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ThemedText {
                        text: "No new notifications at the moment."
                        customSize: Constants.sizeXs + 2
                        color: Theme.muted
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Constants.animNormal
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Item {
                    id: listContainer

                    anchors.fill: parent
                    visible: root.groupedModel.length > 0 || root.isClearingAll
                    opacity: root.isClearingAll ? 0 : 1
                    x: root.isClearingAll ? 40 : 0
                    scale: root.isClearingAll ? 0.94 : 1
                    transformOrigin: Item.Center

                    ListView {
                        id: historyView

                        anchors.fill: parent
                        interactive: true
                        model: root.groupedModel
                        spacing: Constants.sizeXs

                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: Constants.animNormal
                                easing.type: Easing.OutQuint
                            }

                        }

                        delegate: NotificationGroupDelegate {
                            expanded: root.expandedGroups[modelData.key] === true
                            currentTime: root.today
                            groupData: modelData
                            notificationService: root.notificationService
                            onClearGroupRequested: root.clearGroup(modelData)
                            onToggleRequested: root.toggleGroup(modelData.key)
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutCubic
                            onRunningChanged: {
                                if (!running && root.isClearingAll) {
                                    if (root.notificationService)
                                        root.notificationService.clearHistory();

                                    root.isClearingAll = false;
                                }
                            }
                        }

                    }

                }

            }

        }

        // SEPARATOR
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.topMargin: Constants.sizeSm
            Layout.bottomMargin: Constants.sizeSm
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
        }

        // RIGHT PANEL: CLOCK + CALENDAR
        ColumnLayout {
            id: dateColumn

            Layout.preferredWidth: root.datePanelWidth
            Layout.fillHeight: true
            spacing: Constants.sizeSm

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.size3Xs

                ThemedText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(root.today, "HH:mm")
                    customSize: 58
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                    color: Theme.fg
                }

                ThemedText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(root.today, "dd-MM-yy")
                    customSize: Constants.sizeMd
                    color: Theme.muted
                }

            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.size2Xs

                Item {
                    Layout.fillWidth: true
                }

                NavArrow {
                    backward: true
                    onActivated: root.shiftMonth(-1)
                }

                ThemedText {
                    text: Qt.locale().monthName(root.viewMonth)
                    font.bold: true
                    customSize: Constants.sizeMd
                    color: root.isCurrentMonth ? Theme.fg : Theme.accent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.isCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !root.isCurrentMonth
                        onClicked: root.goToToday()
                    }

                }

                NavArrow {
                    onActivated: root.shiftMonth(1)
                }

                Item {
                    Layout.preferredWidth: Constants.sizeSm
                }

                NavArrow {
                    backward: true
                    onActivated: root.shiftMonth(-12)
                }

                ThemedText {
                    text: root.viewYear
                    font.bold: true
                    customSize: Constants.sizeMd
                    color: root.isCurrentMonth ? Theme.fg : Theme.accent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.isCurrentMonth ? Qt.ArrowCursor : Qt.PointingHandCursor
                        enabled: !root.isCurrentMonth
                        onClicked: root.goToToday()
                    }

                }

                NavArrow {
                    onActivated: root.shiftMonth(12)
                }

                Item {
                    Layout.fillWidth: true
                }

            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale()

                delegate: ThemedText {
                    text: model.shortName
                    horizontalAlignment: Text.AlignHCenter
                    customSize: Constants.sizeXs + 2
                    color: Theme.muted
                }

            }

            MonthGrid {
                id: grid

                Layout.fillWidth: true
                month: root.viewMonth
                year: root.viewYear
                locale: Qt.locale()

                delegate: Item {
                    id: cell

                    readonly property bool inMonth: model.month === root.viewMonth
                    readonly property bool isToday: model.day === root.today.getDate() && model.month === root.today.getMonth() && model.year === root.today.getFullYear()

                    implicitWidth: 40
                    implicitHeight: 36

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: width / 2
                        color: cell.isToday ? Theme.accent : (cellArea.containsMouse && cell.inMonth ? Theme.bgSecondary : "transparent")
                    }

                    ThemedText {
                        anchors.centerIn: parent
                        text: model.day
                        customSize: Constants.sizeSm
                        font.bold: cell.isToday
                        opacity: cell.inMonth ? 1 : 0.3
                        color: cell.isToday ? Theme.bg : Theme.fg
                    }

                    MouseArea {
                        id: cellArea

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                }

            }

        }

    }

    component NavArrow: Rectangle {
        id: navArrow

        property bool backward: false

        signal activated()

        implicitWidth: Constants.size2Xl
        implicitHeight: Constants.size2Xl
        radius: Constants.sizeSm
        color: arrowArea.containsMouse ? Theme.bgSecondary : "transparent"

        SvgIcon {
            anchors.centerIn: parent
            icon: navArrow.backward ? "chevron-left" : "chevron-right"
            iconSize: Constants.sizeSm
            iconColor: Theme.accent
            flat: true
        }

        MouseArea {
            id: arrowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navArrow.activated()
        }

    }

}
