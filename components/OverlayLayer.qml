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
    visible: active
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: Constants.nsOverlay
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Backdrop: click anywhere outside closes.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: ShellState.close()
        Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: (ShellState.open === "launcher" || ShellState.open === "power") ? 1 : 0
            Behavior on opacity { enabled: UserConfig.data.appearance.animations; NumberAnimation { duration: Theme.durNormal } } }
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

        Loader {
            id: content
            active: overlay.active
            sourceComponent: {
                switch (ShellState.open) {
                case "launcher": return launcherComp
                case "control": return controlComp
                case "notifications": return notifComp
                case "media": return mediaComp
                case "calendar": return calendarComp
                case "power": return powerComp
                case "tray": return trayComp
                default: return null
                }
            }
            onLoaded: { item.forceActiveFocus() }
            readonly property bool centered: ShellState.open === "launcher" || ShellState.open === "power"
            x: centered ? Math.round((overlay.width - width) / 2) : scope.placeX(width, ShellState.anchorX)
            y: centered ? Math.round(overlay.height * 0.30) : Math.round(overlay.barTop - 10 - height)
            // entrance animation
            opacity: 0
            transform: Translate { id: tr; y: 8 }
            onActiveChanged: if (active) { opacity = 0; tr.y = 8; anim.restart() }
            ParallelAnimation { id: anim
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: UserConfig.data.appearance.animations ? Theme.durNormal : 0; easing.type: Theme.easing }
                NumberAnimation { target: tr; property: "y"; to: 0; duration: UserConfig.data.appearance.animations ? Theme.durNormal : 0; easing.type: Theme.easing } }
        }
    }

    Component { id: launcherComp; Launcher { screenName: overlay.screenName } }
    Component { id: controlComp; ControlCenter { initialSection: ShellState.anchorPayload || "" } }
    Component { id: notifComp; NotificationCenter {} }
    Component { id: mediaComp; MediaControls {} }
    Component { id: calendarComp; CalendarPopover {} }
    Component { id: powerComp; PowerMenu {} }
    Component { id: trayComp; TrayMenu { item: ShellState.anchorPayload } }
}
