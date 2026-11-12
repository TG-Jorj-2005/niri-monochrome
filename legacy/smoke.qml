import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Bluetooth

ShellRoot {
    id: root
    Component.onCompleted: {
        console.info("screens:", Quickshell.screens.length, Quickshell.screens.map(s => s.name + "|" + s.model + "|" + s.serialNumber + "|" + s.width + "x" + s.height + "@" + s.devicePixelRatio).join(","))
        console.info("apps:", DesktopEntries.applications.values.length, "icon firefox:", Quickshell.iconPath("firefox"), "hasTheme wifi:", Quickshell.hasThemeIcon("network-wireless-symbolic"))
        console.info("stateDir:", Quickshell.stateDir, "dataDir:", Quickshell.dataDir, "configDir:", Quickshell.configDir)
        console.info("upower:", UPower.displayDevice.percentage, UPower.displayDevice.state, UPower.onBattery, "profiles:", PowerProfiles.profile)
        console.info("net backend:", Networking.backend, "wifi:", Networking.wifiEnabled, "devices:", Networking.devices.values.length)
        console.info("bt adapter:", Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.name + " enabled=" + Bluetooth.defaultAdapter.enabled : "none", "devices:", Bluetooth.devices.values.length)
        console.info("mpris players:", Mpris.players.values.length)
    }
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
    Timer { interval: 800; running: true; onTriggered: {
        const s = Pipewire.defaultAudioSink
        console.info("pw ready:", Pipewire.ready, "sink:", s ? s.description + " vol=" + s.audio.volume + " muted=" + s.audio.muted : "none", "nodes:", Pipewire.nodes.values.length)
        const d = Networking.devices.values[0]; if (d) console.info("net dev0:", d.name, d.type, d.connected, d.state, d.networks ? d.networks.values.length : -1)
        popup.visible = true
    } }
    Socket {
        id: niri
        path: Quickshell.env("NIRI_SOCKET")
        connected: true
        onConnectionStateChanged: { console.info("niri socket connected:", connected); if (connected) write('"EventStream"\n') }
        parser: SplitParser { onRead: data => { const o = JSON.parse(data); const k = Object.keys(o)[0]; console.info("niri event:", k, JSON.stringify(o[k]).substring(0, 120)) } }
    }
    IpcHandler { target: "test"; function ping(): string { return "pong" } }
    PanelWindow {
        id: bar
        screen: Quickshell.screens[0]
        anchors.bottom: true
        implicitWidth: 800
        implicitHeight: 54
        margins.bottom: 14
        exclusiveZone: 68
        color: "transparent"
        WlrLayershell.namespace: "nm-smoke"
        WlrLayershell.layer: WlrLayer.Top
        Rectangle { anchors.fill: parent; radius: 10; color: "#111111"; border.color: "#393939"; border.width: 1
            Text { id: lbl; anchors.centerIn: parent; text: "NIRI MONOCHROME smoke"; color: "#BDBDBD"; font.family: "Inter"; font.pixelSize: 13 }
            Image { id: ico; x: 10; y: 11; width: 32; height: 32; source: Quickshell.iconPath("firefox"); visible: false }
            MultiEffect { source: ico; anchors.fill: ico; saturation: -1.0 }
        }
        Component.onCompleted: console.info("bar window created; dpr", devicePixelRatio)
    }
    PopupWindow {
        id: popup
        anchor.window: bar
        anchor.item: lbl
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.bottom: 10
        implicitWidth: 300; implicitHeight: 200
        color: "transparent"
        grabFocus: true
        onVisibleChanged: console.info("popup visible:", visible)
        Rectangle { anchors.fill: parent; radius: 10; color: "#111111"; border.color: "#393939"; Text { anchors.centerIn: parent; text: "popup"; color: "#eee" } }
    }
    Timer { interval: 3500; running: true; onTriggered: { console.info("smoke done"); Qt.quit() } }
}
