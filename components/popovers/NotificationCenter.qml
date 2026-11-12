import QtQuick
import qs.config
import qs.services
import qs.components.ui

// Persistent notification history grouped by application, with DND and clearing.
PopoverFrame {
    id: nc
    title: "Notifications"
    icon: "bell"
    implicitWidth: 400
    headerExtra: [
        MonoButton { text: NotificationService.dnd ? "DND on" : "DND off"; icon: NotificationService.dnd ? "bell-off" : "bell"; iconSize: 12; implicitHeight: 22; padding: 6; active: NotificationService.dnd; onClicked: NotificationService.toggleDnd() },
        MonoButton { visible: NotificationService.usingMako; text: "Dismiss"; icon: "x"; iconSize: 12; implicitHeight: 22; padding: 6; flat: true; onClicked: NotificationService.dismissAll() },
        MonoButton { text: "Clear all"; icon: "trash"; iconSize: 12; implicitHeight: 22; padding: 6; flat: true; enabled: NotificationService.history.length > 0; onClicked: NotificationService.clearHistory() }
    ]
    Component.onCompleted: markTimer.start()
    Timer { id: markTimer; interval: 1200; onTriggered: NotificationService.markAllRead() }

    Flickable {
        width: parent.width
        height: Math.min(460, list.implicitHeight)
        contentHeight: list.implicitHeight
        clip: true
        interactive: contentHeight > height
        Column {
            id: list
            width: parent.width
            spacing: 10
            Item { visible: NotificationService.history.length === 0; width: parent.width; height: 90
                Column { anchors.centerIn: parent; spacing: 6
                    MonoIcon { name: "inbox"; size: 22; color: Theme.textDisabled; anchors.horizontalCenter: parent.horizontalCenter }
                    Label { text: NotificationService.usingMako ? "mako handles notifications (Mod+N dismiss · Mod+Shift+N DND). History needs the shell server." : SystemService.notificationOwnedByOther ? "Another notification daemon is active (pid " + SystemService.notificationOwnerPid + ")" : NotificationService.serverEnabled ? "No notifications" : "Notification server disabled in Settings"; secondary: true; font.pixelSize: Theme.fontSm; anchors.horizontalCenter: parent.horizontalCenter; width: 340; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter } } }
            Repeater {
                model: NotificationService.grouped()
                delegate: Column {
                    id: group
                    required property var modelData
                    width: parent.width
                    spacing: 4
                    Row { width: parent.width; spacing: 8
                        AppIcon { icon: group.modelData.icon || group.modelData.desktopEntry; size: 16; anchors.verticalCenter: parent.verticalCenter; fallbackGlyph: "app" }
                        Label { text: group.modelData.app; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100 }
                        Label { text: group.modelData.items.length; mono: true; font.pixelSize: Theme.fontXs; secondary: true; anchors.verticalCenter: parent.verticalCenter }
                        IconButton { icon: "x"; iconSize: 12; implicitWidth: 22; implicitHeight: 22; onClicked: NotificationService.clearApp(group.modelData.app) } }
                    Repeater {
                        model: group.modelData.items
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            width: group.width; height: body.implicitHeight + 20
                            radius: Theme.radiusControl
                            color: cma.containsMouse ? Theme.hover : Theme.surface2
                            border.width: 1; border.color: card.modelData.read ? Theme.border : Theme.silverMuted
                            Column { id: body; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; rightMargin: 34 } spacing: 2
                                Row { width: parent.width; spacing: 8
                                    Label { text: card.modelData.summary; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; width: parent.width - 60 }
                                    Label { text: NotificationService.timeLabel(card.modelData.time); mono: true; font.pixelSize: Theme.fontXs; secondary: true } }
                                Label { visible: text !== ""; text: NotificationService.plain(card.modelData.body); font.pixelSize: Theme.fontSm; secondary: true; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; textFormat: Text.PlainText } }
                            IconButton { icon: "x"; iconSize: 11; implicitWidth: 20; implicitHeight: 20; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6; onClicked: NotificationService.removeHistory(card.modelData.id) }
                            MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; z: -1 }
                        }
                    }
                }
            }
        }
    }
    Label { text: "History: " + NotificationService.history.length + " · kept " + UserConfig.data.notifications.historyRetentionDays + " days"; font.pixelSize: Theme.fontXs; mono: true; color: Theme.textDisabled }
}
