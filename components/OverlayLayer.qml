import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.ui
import qs.components.popovers

// Per-monitor transparent overlay that hosts popovers, the launcher and the power menu.
// Only mapped while something is open; takes exclusive keyboard focus for Escape/typing.
PanelWindow {
    id: overlay
    required property var modelData
    readonly property string screenName: modelData.name
    readonly property bool active: ShellState.open !== "" && ShellState.screenName === screenName
    readonly property var barProfile: MonitorProfiles.profile(MonitorService.keyFor(modelData)).bar
    readonly property real barTop: modelData.height - (barProfile.enabled ? barProfile.marginBottom + barProfile.height : 0)

    screen: modelData
    property string displayed: ""
    property real reveal: active ? 1 : 0
    onActiveChanged: if (active) displayed = ShellState.open
    Connections { target: ShellState; function onOpenChanged() { if (overlay.active) overlay.displayed = ShellState.open } }
    Behavior on reveal { NumberAnimation { duration: overlay.active ? Theme.durNormal : Theme.durFast; easing.type: Theme.easing } }
    visible: active || reveal > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: Constants.nsOverlay
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Backdrop: click anywhere outside closes.
    MouseArea {
        anchors.fill: parent
        enabled: overlay.active
        acceptedButtons: Qt.AllButtons
        onPressed: ShellState.close()
        Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: overlay.reveal * (overlay.displayed === "launcher" || overlay.displayed === "power" || overlay.displayed === "shortcuts" ? 1 : 0)
 }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ShellState.close()

        // Popover placement helper
        function placeX(w, anchorX) {
            const margin = 12
            if (anchorX < 0) return Math.round((overlay.width - w) / 2)
            return Math.round(Math.max(margin, Math.min(overlay.width - w - margin, anchorX - w / 2)))
        }

        // Consume presses in panel padding after child controls have had first chance.
        // This sits below the Loader, so outside clicks still reach the backdrop.
        MouseArea {
            x: content.x; y: content.y
            width: content.width; height: content.height
            enabled: overlay.active
            acceptedButtons: Qt.AllButtons
        }

        Loader {
            id: content
            active: overlay.active || overlay.reveal > 0.001
            sourceComponent: {
                switch (overlay.displayed) {
                case "launcher": return launcherComp
                case "control": return controlComp
                case "notifications": return notifComp
                case "media": return mediaComp
                case "calendar": return calendarComp
                case "power": return powerComp
                case "tray": return trayComp
                case "shortcuts": return shortcutsComp
                default: return null
                }
            }
            onLoaded: { item.forceActiveFocus() }
            readonly property bool centered: overlay.displayed === "launcher" || overlay.displayed === "power" || overlay.displayed === "shortcuts"
            x: centered ? Math.round((overlay.width - width) / 2) : scope.placeX(width, ShellState.anchorX)
            width: Math.min(item ? item.implicitWidth : 380, overlay.width-24)
            height: Math.min(item ? item.implicitHeight : 1, overlay.height-24)
            y: Math.max(12, Math.min(overlay.height-height-12, centered ? Math.round((overlay.height-height)/2) : Math.round(overlay.barTop-10-height)))
            opacity: overlay.reveal
            transform: Translate { y: 8 * Theme.motionIntensity * (1-overlay.reveal) }

        }
    }

    Component { id: launcherComp; Launcher { screenName: overlay.screenName } }
    Component { id: controlComp; ControlCenter { initialSection: ShellState.anchorPayload || "" } }
    Component { id: notifComp; NotificationCenter {} }
    Component { id: mediaComp; MediaControls {} }
    Component { id: calendarComp; CalendarPopover {} }
    Component { id: powerComp; PowerMenu {} }
    Component { id: shortcutsComp; ShortcutCheatSheet {} }
    Component { id: trayComp; TrayMenu { item: ShellState.anchorPayload } }
}
