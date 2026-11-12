import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.ui
import qs.components.bar

// Floating, centered bottom bar — the primary persistent surface. One per monitor.
PanelWindow {
    id: bar
    required property var modelData          // QuickshellScreenInfo
    readonly property string monitorKey: MonitorService.keyFor(modelData)
    readonly property var profile: MonitorProfiles.profile(monitorKey).bar
    readonly property bool isFocusedOutput: NiriService.focusedOutput === modelData.name

    screen: modelData
    visible: profile.enabled
    anchors.bottom: true
    margins.bottom: profile.marginBottom
    // Width = widthPercent of the display, capped by maxWidth and by the minimum side margins.
    implicitWidth: Math.max(320, Math.min(profile.maxWidth, Math.round(modelData.width * profile.widthPercent / 100), modelData.width - profile.marginX * 2))
    implicitHeight: profile.height
    exclusiveZone: profile.reserveSpace ? profile.height + profile.marginBottom : 0
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: Constants.nsBar
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Screen-space x of the bar's left edge (centered by the compositor).
    readonly property real screenX: (modelData.width - width) / 2
    function anchorXFor(item) {
        const p = item.mapToItem(null, item.width / 2, 0)
        return screenX + p.x
    }
    function openPopover(name, item, payload) { ShellState.toggle(name, modelData.name, anchorXFor(item), payload) }

    Panel {
        id: surface
        anchors.fill: parent
        radius: bar.profile.radius
        color: Theme.surface

        // ---- LEFT: branding + workspaces ----
        Row {
            id: left
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Branding { visible: bar.profile.showBranding; anchors.verticalCenter: parent.verticalCenter; onClicked: NiriService.toggleOverview() }
            Divider { visible: bar.profile.showBranding; vertical: true; height: 14; anchors.verticalCenter: parent.verticalCenter }
            WorkspaceIndicator { output: bar.modelData.name; anchors.verticalCenter: parent.verticalCenter; spacing: 3 }
        }

        // ---- CENTER: focused window ----
        FocusedWindow {
            id: center
            output: bar.modelData.name
            isFocusedOutput: bar.isFocusedOutput
            maxChars: bar.profile.titleMaxChars
            showAppName: bar.profile.showAppName
            anchors.centerIn: parent
            maxWidth: Math.max(120, parent.width - left.width - right.width - 48)
        }

        // ---- RIGHT: system status ----
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            // Media (only when a player exists — keeps the bar uncluttered)
            IconButton { id: mediaBtn; visible: UserConfig.data.media.showIndicator && MediaService.hasPlayer; icon: MediaService.playing ? "pause" : "music"; iconSize: 13; implicitWidth: 26; implicitHeight: 26
                active: ShellState.isOpen("media", bar.modelData.name)
                onClicked: { bar.openPopover("media", mediaBtn) } onMiddleClicked: MediaService.toggle() }

            SystemTray { visible: bar.profile.showTray; bar: bar; anchors.verticalCenter: parent.verticalCenter; spacing: 1 }

            Divider { vertical: true; height: 14; anchors.verticalCenter: parent.verticalCenter; visible: bar.profile.showTray }

            IconButton { id: netBtn; icon: NetworkService.iconName(); iconSize: 14; implicitWidth: 26; implicitHeight: 26; tooltip: NetworkService.statusText()
                active: ShellState.isOpen("control", bar.modelData.name) && ShellState.anchorPayload === "network"
                onClicked: bar.openPopover("control", netBtn, "network") }
            IconButton { id: btBtn; icon: BluetoothService.iconName(); iconSize: 14; implicitWidth: 26; implicitHeight: 26; visible: BluetoothService.available
                active: ShellState.isOpen("control", bar.modelData.name) && ShellState.anchorPayload === "bluetooth"
                onClicked: bar.openPopover("control", btBtn, "bluetooth") }
            IconButton { id: audBtn; icon: AudioService.iconName(); iconSize: 14; implicitWidth: 26; implicitHeight: 26
                active: ShellState.isOpen("control", bar.modelData.name) && ShellState.anchorPayload === "audio"
                onClicked: { bar.openPopover("control", audBtn, "audio") } onMiddleClicked: AudioService.toggleMute()
                onWheel: d => AudioService.step(d > 0 ? 0.03 : -0.03) }
            BatteryIndicator { id: batBtn; anchors.verticalCenter: parent.verticalCenter
                active: ShellState.isOpen("control", bar.modelData.name) && ShellState.anchorPayload === "battery"
                onClicked: bar.openPopover("control", batBtn, "battery") }

            Divider { vertical: true; height: 14; anchors.verticalCenter: parent.verticalCenter }

            ClockIndicator { id: clockBtn; anchors.verticalCenter: parent.verticalCenter; showDate: bar.profile.showDate; showSeconds: bar.profile.showSeconds
                clockFormat: bar.profile.clockFormat; dateFormat: bar.profile.dateFormat
                active: ShellState.isOpen("calendar", bar.modelData.name)
                onClicked: bar.openPopover("calendar", clockBtn) }

            NotificationIndicator { id: bellBtn; anchors.verticalCenter: parent.verticalCenter; iconSize: 14; implicitWidth: 26; implicitHeight: 26
                active: ShellState.isOpen("notifications", bar.modelData.name)
                onClicked: { bar.openPopover("notifications", bellBtn) } onRightClicked: NotificationService.toggleDnd() }

            IconButton { id: powerBtn; icon: "power"; iconSize: 14; implicitWidth: 26; implicitHeight: 26; tooltip: "Power"
                active: ShellState.isOpen("power", bar.modelData.name)
                onClicked: ShellState.toggle("power", bar.modelData.name) }
        }
    }
}
