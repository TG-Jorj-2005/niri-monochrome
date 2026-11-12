pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// NetworkManager via Quickshell.Networking (+ nmcli for things the API does not expose).
Singleton {
    id: net

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d && d.type === DeviceType.Wifi) || null
    readonly property var wiredDevices: devices.filter(d => d && d.type !== DeviceType.Wifi)
    readonly property bool wiredConnected: wiredDevices.some(d => d.connected)
    readonly property bool wifiConnected: wifiDevice ? wifiDevice.connected : false
    readonly property bool connected: wifiConnected || wiredConnected

    readonly property var networks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values.slice().sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []
    readonly property var activeNetwork: networks.find(n => n.connected) || null
    readonly property string ssid: activeNetwork ? activeNetwork.name : ""
    readonly property real signal: activeNetwork ? activeNetwork.signalStrength : 0

    function setWifiEnabled(on) { Networking.wifiEnabled = on }
    function setScanning(on) { if (wifiDevice) wifiDevice.scannerEnabled = on }

    function iconName() {
        if (!available) return "wifi-off"
        if (wifiConnected) {
            if (signal >= 0.66) return "wifi"
            if (signal >= 0.33) return "wifi-medium"
            return "wifi-low"
        }
        if (wiredConnected) return "ethernet"
        return "wifi-off"
    }
    function statusText() {
        if (!available) return "NetworkManager unavailable"
        if (wifiConnected) return ssid
        if (wiredConnected) return "Wired"
        if (!wifiEnabled) return "Wi‑Fi off"
        return "Disconnected"
    }

    // Connect with a password through nmcli (the Networking API handles known networks).
    property string lastError: ""
    signal connectFinished(bool ok, string message)
    function connectWithPassword(ssidName, password) {
        if (!ssidName) return
        const p = nmcliComp.createObject(net, { command: ["nmcli", "device", "wifi", "connect", ssidName, "password", password] })
        p.running = true
    }
    function connectKnown(network) { if (network) network.connect() }
    function disconnect(network) { if (network) network.disconnect() }
    function forget(network) { if (network) network.forget() }
    Component {
        id: nmcliComp
        Process {
            stdout: StdioCollector { id: out }
            stderr: StdioCollector { id: err }
            onExited: code => {
                const msg = (err.text + out.text).trim()
                net.lastError = code === 0 ? "" : msg
                net.connectFinished(code === 0, msg)
                destroy()
            }
        }
    }
    function openEditor() { Quickshell.execDetached({ command: ["nm-connection-editor"] }) }
}
