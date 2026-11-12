import QtQuick
import qs.config
import qs.services
import qs.components.ui

IconButton {
    id: root
    icon: NotificationService.dnd ? "bell-off" : "bell"
    // Unread dot
    Rectangle { visible: NotificationService.unreadCount > 0 && !root.active; width: 6; height: 6; radius: 1; color: Theme.silverBright; x: parent.width - 9; y: 6 }
}
