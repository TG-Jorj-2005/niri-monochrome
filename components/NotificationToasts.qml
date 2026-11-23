import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.components.ui

// Top-right stack of temporary notification cards (one window per monitor; shown on the focused output).
PanelWindow {
    id: toasts
    required property var modelData
    readonly property bool onFocusedOutput: NiriService.focusedOutput === modelData.name || (NiriService.focusedOutput === "" && Quickshell.screens[0] === modelData)
    readonly property var items: onFocusedOutput ? NotificationService.toasts : []
    screen: modelData
    visible: items.length > 0
    anchors { top: true; right: true }
    margins { top: 16; right: 16 }
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: Constants.nsToast
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: column
        width: parent.width
        spacing: 8
        Repeater {
            model: toasts.items
            delegate: Panel {
                id: card
                required property var modelData
                readonly property var n: modelData
                readonly property int timeout: NotificationService.timeoutFor(n)
                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                width: column.width
                height: content.implicitHeight + 24
                border.color: critical ? Theme.silverBright : Theme.silverMuted
                color: Theme.surface
                opacity: 0
                transform: Translate { id: tr; x: 24 }
                Component.onCompleted: { opacity = 1; tr.x = 0 }
                Behavior on opacity { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
                Behavior on x { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }

                Timer { interval: card.timeout; running: card.timeout > 0 && !hover.hovered; onTriggered: card.n.expire() }
                HoverHandler { id: hover }

                Column {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 6
                    Row { width: parent.width; spacing: 8
                        AppIcon { icon: card.n.appIcon || card.n.desktopEntry; size: 16; anchors.verticalCenter: parent.verticalCenter; fallbackGlyph: "bell" }
                        Label { text: (card.n.appName || card.n.desktopEntry || "Notification").toUpperCase(); font.pixelSize: Theme.fontXs; font.letterSpacing: 1; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 110 }
                        Label { text: Qt.formatTime(new Date(), "HH:mm"); mono: true; font.pixelSize: Theme.fontXs; secondary: true; anchors.verticalCenter: parent.verticalCenter }
                        IconButton { icon: "x"; iconSize: 12; implicitWidth: 22; implicitHeight: 22; anchors.verticalCenter: parent.verticalCenter; onClicked: card.n.dismiss() } }
                    Row { width: parent.width; spacing: 10
                        Image { visible: card.n.image !== ""; source: card.n.image; width: visible ? 44 : 0; height: 44; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(88, 88) }
                        Column { width: parent.width - (card.n.image !== "" ? 54 : 0); spacing: 2
                            Label { text: NotificationService.plain(card.n.summary); font.weight: Font.DemiBold; width: parent.width; textFormat: Text.PlainText }
                            Label { visible: text !== ""; text: NotificationService.plain(card.n.body); secondary: true; font.pixelSize: Theme.fontSm; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 5; elide: Text.ElideRight; textFormat: Text.PlainText } } }
                    Row { visible: card.n.actions.length > 0; spacing: 6; topPadding: 2
                        Repeater { model: card.n.actions
                            delegate: MonoButton { required property var modelData; text: modelData.text; implicitHeight: 26; padding: 10; onClicked: { modelData.invoke(); card.n.dismiss() } } } }
                }
                // timeout progress line
                Rectangle { visible: card.timeout > 0; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 1; height: 2; radius: 1; color: Theme.accent
                    width: parent.width - 2
                    NumberAnimation on width { from: card.width - 2; to: 0; duration: card.timeout; running: card.timeout > 0 && !hover.hovered } }
            }
        }
    }
}
