pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Which overlay surface is open, on which monitor, anchored where.
// Overlay surfaces: "launcher", "control", "notifications", "media", "calendar", "power", "tray"
Singleton {
    id: st
    property string open: ""
    property string screenName: ""
    property real anchorX: -1        // screen-relative x of the anchor center (-1 = centered)
    property var anchorPayload: null
    property bool dockKeyboard: false  // dock opened from the keyboard (per focused screen)
    property string dockScreen: ""
    property bool settingsOpen: false
    property int settingsSection: 0

    signal requestFocusReset()

    function isOpen(name, screen) { return open === name && screenName === screen }

    function show(name, screen, x, payload) {
        hideDock()
        open = name
        screenName = screen || (MonitorService.focusedScreen() ? MonitorService.focusedScreen().name : "")
        anchorX = (x === undefined || x === null) ? -1 : x
        anchorPayload = payload === undefined ? null : payload
    }
    function toggle(name, screen, x, payload) {
        const target = screen || (MonitorService.focusedScreen() ? MonitorService.focusedScreen().name : "")
        if (open === name && screenName === target) close()
        else show(name, target, x, payload)
    }
    function close() { open = ""; anchorPayload = null }

    function toggleDock(screen) {
        const target = screen || (MonitorService.focusedScreen() ? MonitorService.focusedScreen().name : "")
        if (dockKeyboard && dockScreen === target) { dockKeyboard = false }
        else { dockScreen = target; dockKeyboard = true; close() }
    }
    function hideDock() { dockKeyboard = false }
    Connections { target: Quickshell; function onScreensChanged() {
        if (st.open && !MonitorService.screenByName(st.screenName)) st.close()
        if (st.dockKeyboard && !MonitorService.screenByName(st.dockScreen)) st.hideDock()
    } }
}
