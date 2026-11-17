import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Core
import qs.Core.Services

Item {
    id: root

    property alias server: notificationServer
    property alias activeList: activeListModel
    property alias historyList: historyListModel
    property bool dndEnabled: false
    property int unreadCount: historyListModel.count
    property var notificationObjects: ({
    })
    property var notificationGroups: ({
    })
    property var groupRepresentationIds: ({
    })
    property string _lastSavedPayload: ""
    property bool _historyRestored: false

    // History survives shell restarts: the last 50 notifications are kept in
    // a state-dir JSON file and rebuilt (without popups or actions — the
    // sender is gone) when the shell comes back up.
    FileView {
        id: historyFile

        path: Quickshell.stateDir + "/notification_history.json"
        onLoaded: root.restoreHistory()
        // First run: the file does not exist yet — unblock saving and seed it.
        onLoadFailed: root._historyRestored = true
    }

    // FileView.setText does not flush in this Quickshell build, so the
    // history is written through a shell redirect (same pattern the settings
    // saver uses).
    Process {
        id: historySaveProc
    }

    function saveHistoryIfChanged() {
        if (!root._historyRestored)
            return ;

        let entries = [];
        for (let i = 0; i < historyListModel.count && entries.length < 50; i++) {
            let nd = historyListModel.get(i).notifData;
            if (!nd)
                continue;

            entries.push({
                "id": String(nd.notificationId),
                "summary": nd.summary,
                "body": nd.body,
                "appName": nd.appName,
                "appIcon": nd.appIcon,
                "urgency": nd.urgency,
                "timestamp": nd.timestamp
            });
        }
        let payload = JSON.stringify(entries);
        if (payload === root._lastSavedPayload)
            return ;

        root._lastSavedPayload = payload;
        historySaveProc.command = ["sh", "-c",
            'umask 077; mkdir -p "$1"; cat > "$1/.nh.tmp" <<\'MH_EOF\'\n' + payload + '\nMH_EOF\nmv -f "$1/.nh.tmp" "$1/notification_history.json"',
            "sh", Quickshell.stateDir];
        historySaveProc.startDetached();
    }

    function restoreHistory() {
        try {
            let raw = historyFile.text();
            root._historyRestored = true;
            if (!raw || raw.trim() === "")
                return ;

            let entries = JSON.parse(raw);
            for (let i = 0; i < entries.length && historyListModel.count < 50; i++) {
                let e = entries[i];
                if (!e || !e.id || notificationObjects[e.id])
                    continue;

                let nd = notificationDataComponent.createObject(root, {
                    "notificationId": String(e.id),
                    "summary": e.summary || "",
                    "body": e.body || "",
                    "appName": e.appName || "System",
                    "appIcon": e.appIcon || "",
                    "urgency": e.urgency || 0,
                    "timestamp": e.timestamp || new Date().getTime(),
                    "popup": false,
                    "progress": 0
                });
                notificationObjects[e.id] = nd;
                historyListModel.append({
                    "id": e.id,
                    "notifData": nd
                });
            }
        } catch (e) {
            console.log("[Notifications] history restore failed:", e);
        }
        root._historyRestored = true;
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.saveHistoryIfChanged()
    }

    Component.onCompleted: historyFile.reload()

    function pruneActiveNotifications() {
        let maxCount = 1;
        while (activeListModel.count > maxCount) {
            let oldItem = activeListModel.get(maxCount);
            if (oldItem && oldItem.notifData)
                oldItem.notifData.popup = false;

            activeListModel.remove(maxCount);
        }
    }

    function notify(summary, body, icon = "", appName = "System", urgency = NotificationUrgency.Normal) {
        let timestamp = new Date().getTime();
        let nd = notificationDataComponent.createObject(root, {
            "notificationId": timestamp.toString(),
            "summary": summary,
            "body": body,
            "appName": appName,
            "appIcon": icon,
            "urgency": urgency,
            "timestamp": timestamp,
            "isDnd": root.dndEnabled
        });
        notificationObjects[timestamp] = nd;
        historyListModel.insert(0, {
            "id": timestamp,
            "notifData": nd
        });
        if (!dndEnabled) {
            activeListModel.insert(0, {
                "id": timestamp,
                "notifData": nd
            });
            pruneActiveNotifications();
        }
    }

    function dismissNotification(id) {
        let nd = notificationObjects[id];
        if (nd)
            nd.close();

        removeNotification(id);
    }

    function getGroupKey(notification) {
        let appsToGroup = ["whatsapp", "telegram", "discord", "slack"];
        let app = (notification.appName || "").toLowerCase();
        for (let i = 0; i < appsToGroup.length; i++) {
            if (app.includes(appsToGroup[i]))
                return appsToGroup[i];

        }
        return "";
    }

    function copyObject(obj) {
        let copy = {
        };
        for (let k in obj) {
            copy[k] = obj[k];
        }
        return copy;
    }

    function removeNotification(id) {
        for (let groupKey in groupRepresentationIds) {
            if (groupRepresentationIds[groupKey] == id) {
                let groups = copyObject(notificationGroups);
                groups[groupKey] = [];
                notificationGroups = groups;
                let reps = copyObject(groupRepresentationIds);
                delete reps[groupKey];
                groupRepresentationIds = reps;
                break;
            }
        }
        if (notificationObjects[id]) {
            notificationObjects[id].destroy(1000);
            delete notificationObjects[id];
        }
        for (var i = 0; i < activeListModel.count; i++) {
            if (activeListModel.get(i).id == id) {
                activeListModel.remove(i);
                break;
            }
        }
        for (var j = 0; j < historyListModel.count; j++) {
            if (historyListModel.get(j).id == id) {
                historyListModel.remove(j);
                break;
            }
        }
    }

    function removeNotifications(ids) {
        if (!ids)
            return ;

        for (let i = 0; i < ids.length; i++) {
            if (ids[i])
                removeNotification(ids[i]);

        }
    }

    function clearHistory() {
        notificationGroups = {
        };
        groupRepresentationIds = {
        };
        for (let id in notificationObjects) {
            notificationObjects[id].destroy();
        }
        notificationObjects = {
        };
        historyListModel.clear();
        activeListModel.clear();
    }

    function removeHistoryItem(index) {
        if (index >= 0 && index < historyListModel.count) {
            let id = historyListModel.get(index).id;
            removeNotification(id);
        }
    }

    function handleNotificationUpdate(notification) {
        let groupKey = getGroupKey(notification);
        if (!groupKey) {
            root.updateNotificationData(notification);
            return ;
        }
        let groups = copyObject(notificationGroups);
        if (!groups[groupKey])
            groups[groupKey] = [];

        let msgIndex = -1;
        for (let i = 0; i < groups[groupKey].length; i++) {
            if (groups[groupKey][i].id == notification.id) {
                msgIndex = i;
                break;
            }
        }
        let msgData = {
            "id": notification.id,
            "summary": notification.summary ? notification.summary : "",
            "body": notification.body ? notification.body : "",
            "timestamp": new Date().getTime()
        };
        if (msgIndex >= 0)
            groups[groupKey][msgIndex] = msgData;
        else
            groups[groupKey].push(msgData);
        notificationGroups = groups;
        let reps = copyObject(groupRepresentationIds);
        let repId = reps[groupKey];
        if (!repId || repId == notification.id) {
            reps[groupKey] = notification.id;
            groupRepresentationIds = reps;
            root.updateNotificationData(notification);
        } else {
            if (!notification.alreadyDismissed) {
                notification.alreadyDismissed = true;
                notification.dismiss();
            }
            let repData = notificationObjects[repId];
            if (repData) {
                let displayNames = {
                    "whatsapp": "WhatsApp",
                    "telegram": "Telegram",
                    "discord": "Discord",
                    "slack": "Slack"
                };
                let displayName = displayNames[groupKey] || repData.appName;
                let combinedBody = groups[groupKey].map((m) => {
                    return (m.summary ? m.summary + ": " : "") + m.body;
                }).join("\n");
                let combinedSummary = displayName + " (" + groups[groupKey].length + ")";
                repData.summary = combinedSummary;
                repData.body = combinedBody;
                repData.appName = displayName;
                repData.timestamp = new Date().getTime();
                let historyIndex = -1;
                for (let i = 0; i < historyListModel.count; i++) {
                    if (historyListModel.get(i).id == repId) {
                        historyIndex = i;
                        break;
                    }
                }
                if (historyIndex > 0)
                    historyListModel.move(historyIndex, 0, 1);

                if (!dndEnabled) {
                    let activeIndex = -1;
                    for (let i = 0; i < activeListModel.count; i++) {
                        if (activeListModel.get(i).id == repId) {
                            activeIndex = i;
                            break;
                        }
                    }
                    repData.popup = true;
                    repData.startProgress();
                    if (activeIndex > 0)
                        activeListModel.move(activeIndex, 0, 1);
                    else if (activeIndex === -1)
                        activeListModel.insert(0, {
                        "id": repId,
                        "notifData": repData
                    });
                    pruneActiveNotifications();
                }
            }
        }
    }

    function updateNotificationData(notification) {
        let nd = notificationObjects[notification.id];
        if (!nd) {
            nd = notificationDataComponent.createObject(root, {
                "notification": notification,
                "isDnd": root.dndEnabled
            });
            notificationObjects[notification.id] = nd;
        } else {
            if (nd.notification !== notification) {
                nd.notification = notification;
                nd.summary = notification.summary;
                nd.body = notification.body;
                nd.appIcon = notification.appIcon;
                nd.appName = notification.appName;
                nd.image = notification.image;
                nd.urgency = notification.urgency;
            }
            if ((!nd.isDnd || nd.urgency === 2) && !nd.closed) {
                nd.popup = true;
                nd.startProgress();
            }
        }
        if (!nd.isTransient) {
            let historyUpdated = false;
            for (let i = 0; i < historyListModel.count; i++) {
                if (historyListModel.get(i).id == notification.id) {
                    if (i > 0)
                        historyListModel.move(i, 0, 1);

                    historyUpdated = true;
                    break;
                }
            }
            if (!historyUpdated)
                historyListModel.insert(0, {
                "id": notification.id,
                "notifData": nd
            });

        }
        if ((!dndEnabled || nd.urgency === 2) && nd.popup) {
            let activeUpdated = false;
            for (let i = 0; i < activeListModel.count; i++) {
                if (activeListModel.get(i).id == notification.id) {
                    if (i > 0)
                        activeListModel.move(i, 0, 1);

                    activeUpdated = true;
                    break;
                }
            }
            if (!activeUpdated)
                activeListModel.insert(0, {
                "id": notification.id,
                "notifData": nd
            });

            pruneActiveNotifications();
        }
        while (historyListModel.count > 50)removeHistoryItem(historyListModel.count - 1)
    }

    onDndEnabledChanged: {
        for (let id in notificationObjects) {
            notificationObjects[id].isDnd = root.dndEnabled;
            if (root.dndEnabled && notificationObjects[id].urgency !== 2)
                notificationObjects[id].popup = false;

        }
        if (root.dndEnabled) {
            for (let i = activeListModel.count - 1; i >= 0; i--) {
                if (activeListModel.get(i).notifData.urgency !== 2)
                    activeListModel.remove(i);

            }
        }
    }

    Component {
        id: notificationDataComponent

        NotificationData {
        }

    }

    Connections {
        function onGameModeActiveChanged() {
            if (DisplayProfileService.gameModeActive)
                root.dndEnabled = true;
            else
                root.dndEnabled = false;
        }

        target: DisplayProfileService
    }

    Connections {
        property int _prevLevel: -1

        function onBatteryLevelChanged() {
            let status = SystemInfoService.batteryStatus;
            let level = SystemInfoService.batteryLevel;
            if (!SystemInfoService.hasBattery || level <= 0 || level === _prevLevel)
                return ;

            if (_prevLevel !== -1 && status === "Discharging") {
                let threshold = 0;
                if (level <= 5 && _prevLevel > 5)
                    threshold = 5;
                else if (level <= 10 && _prevLevel > 10)
                    threshold = 10;
                else if (level <= 20 && _prevLevel > 20)
                    threshold = 20;
                if (threshold > 0) {
                    OsdService.displayMessage("Low Battery", level + "%", "warning", false);
                    if (threshold <= 10)
                        root.notify("Low Battery", "Battery level: " + level + "%", "warning", "System", NotificationUrgency.Critical);

                }
            }
            _prevLevel = level;
        }

        target: SystemInfoService
    }

    ListModel {
        id: activeListModel
    }

    ListModel {
        id: historyListModel
    }

    NotificationServer {
        id: notificationServer

        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        onNotification: (notification) => {
            if (notification.tracked)
                return ;

            notification.tracked = true;
            notification.closed.connect((reason) => {
                let nd = root.notificationObjects[notification.id];
                if (nd && nd.notification !== notification)
                    return ;

                if (nd)
                    nd.popup = false;

            });
            notification.summaryChanged.connect(() => {
                root.handleNotificationUpdate(notification);
            });
            notification.bodyChanged.connect(() => {
                root.handleNotificationUpdate(notification);
            });
            root.handleNotificationUpdate(notification);
        }
    }

}
