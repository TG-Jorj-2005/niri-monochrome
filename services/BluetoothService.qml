pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ via Quickshell.Bluetooth.
Singleton {
    id: bt
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property var devices: Bluetooth.devices.values.filter(d => d && (d.paired || d.connected || d.name))
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var pairedDevices: devices.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || (a.name || "").localeCompare(b.name || ""))
    readonly property var discoveredDevices: devices.filter(d => !d.paired && d.name)
    readonly property int connectedCount: connectedDevices.length

    function setEnabled(on) { if (adapter) adapter.enabled = on }
    function setDiscovering(on) { if (adapter) adapter.discovering = on }
    function toggleConnect(d) { if (!d) return; if (d.connected) d.disconnect(); else d.connect() }
    function pair(d) { if (d) d.pair() }
    function forget(d) { if (d) d.forget() }

    function iconName() {
        if (!available || !enabled) return "bluetooth-off"
        return connectedCount > 0 ? "bluetooth-connected" : "bluetooth"
    }
    function statusText() {
        if (!available) return "No adapter"
        if (!enabled) return "Off"
        if (connectedCount === 1) return connectedDevices[0].name || "1 device"
        if (connectedCount > 1) return connectedCount + " devices"
        return "On"
    }
    function openManager() { Quickshell.execDetached({ command: ["blueman-manager"] }) }
}
