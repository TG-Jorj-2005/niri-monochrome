import QtQuick
import Quickshell.Services.UPower
import qs.config
import qs.services
import qs.components.ui

// Compact popover anchored to the status indicator that opened it.
// Sections: Network · Bluetooth · Audio · Brightness · Battery · DND · Power.
PopoverFrame {
    id: cc
    property string initialSection: ""
    title: "Control Center"
    icon: "settings"
    implicitWidth: UserConfig.data.controlCenter.width
    property string expanded: initialSection
    readonly property string monitorKey: MonitorService.keyForName(ShellState.screenName)
    headerExtra: [ IconButton { icon: "settings"; iconSize: 14; implicitWidth: 24; implicitHeight: 24; onClicked: { ShellState.close(); ShellState.settingsOpen = true } } ]

    function toggleSection(s) { expanded = (expanded === s ? "" : s) }
    Component.onCompleted: { SystemService.probeNotificationOwner(); NotificationService.refreshMako(); BatteryService.refreshProfiles(); BrightnessService.refresh(); BrightnessService.watchers++; if (initialSection === "network" && NetworkService.wifiDevice) NetworkService.setScanning(true) }
    Component.onDestruction: { BrightnessService.watchers--; NetworkService.setScanning(false) }

    // ---- Quick toggles row ----
    Row {
        width: parent.width
        spacing: 8
        readonly property real cell: (width - 24) / 4
        QuickTile { width: parent.cell; icon: NetworkService.iconName(); label: "Wi‑Fi"; sub: NetworkService.statusText(); on: NetworkService.wifiEnabled; tileEnabled: NetworkService.available
            onToggled: { NetworkService.setWifiEnabled(!NetworkService.wifiEnabled) } onExpand: { cc.toggleSection("network") } expanded: cc.expanded === "network" }
        QuickTile { width: parent.cell; icon: BluetoothService.iconName(); label: "Bluetooth"; sub: BluetoothService.statusText(); on: BluetoothService.enabled; tileEnabled: BluetoothService.available
            onToggled: { BluetoothService.setEnabled(!BluetoothService.enabled) } onExpand: { cc.toggleSection("bluetooth") } expanded: cc.expanded === "bluetooth" }
        QuickTile { width: parent.cell; icon: NotificationService.dnd ? "bell-off" : "bell"; label: "Do Not Disturb"; sub: NotificationService.dnd ? "On" : "Off"; on: NotificationService.dnd
            onToggled: { NotificationService.toggleDnd() } hasExpand: false }
        QuickTile { width: parent.cell; icon: "power"; label: "Power"; sub: BatteryService.present ? Math.round(BatteryService.percentage) + "%" : "AC"; on: false
            onToggled: { ShellState.close(); ShellState.show("power", ShellState.screenName) } onExpand: { cc.toggleSection("battery") } expanded: cc.expanded === "battery" }
    }

    // ---- Second row: night light · microphone · wallpaper · settings ----
    Row {
        width: parent.width
        spacing: 8
        readonly property real cell: (width - 24) / 4
        QuickTile { width: parent.cell; icon: "moon"; label: "Night light"; sub: NightLightService.status === "unavailable" ? "wlsunset missing" : NightLightService.status === "error" ? "error" : NightLightService.enabled ? "On" : "Off"
            on: NightLightService.enabled; tileEnabled: NightLightService.available; hasExpand: false; onToggled: { NightLightService.toggle() } }
        QuickTile { width: parent.cell; icon: AudioService.micMuted ? "mic-off" : "mic"; label: "Microphone"; sub: AudioService.source ? (AudioService.micMuted ? "Muted" : Math.round(AudioService.micVolume * 100) + "%") : "none"
            on: AudioService.source !== null && !AudioService.micMuted; tileEnabled: AudioService.source !== null; hasExpand: false; onToggled: { AudioService.toggleMicMute() } }
        QuickTile { width: parent.cell; icon: "image"; label: "Wallpaper"; sub: WallpaperService.paused(cc.monitorKey) ? "Paused" : WallpaperService.pinned(cc.monitorKey) ? "Pinned" : "Rotating"
            on: false; hasExpand: true; onToggled: { WallpaperService.next(cc.monitorKey) } onExpand: { cc.toggleSection("wallpaper") } expanded: cc.expanded === "wallpaper" }
        QuickTile { width: parent.cell; icon: NetworkService.vpnActive ? "shield" : "lock"; label: "VPN"; sub: NetworkService.vpnActive ? NetworkService.vpnName : "Not connected"
            on: NetworkService.vpnActive; tileEnabled: NetworkService.available; hasExpand: false; onToggled: { NetworkService.openEditor(); ShellState.close() } }
    }

    // ---- Audio ----
    Column {
        width: parent.width; spacing: 6
        Row { width: parent.width; spacing: 10
            IconButton { icon: AudioService.iconName(); iconSize: 16; implicitWidth: 28; implicitHeight: 28; onClicked: AudioService.toggleMute() }
            MonoSlider { width: parent.width - 28 - 10 - 44 - 10; anchors.verticalCenter: parent.verticalCenter; value: AudioService.volume; to: 1.0; enabled: AudioService.sink !== null
                onMoved: v => AudioService.setVolume(v) }
            Label { text: Math.round(AudioService.volume * 100) + "%"; mono: true; width: 44; horizontalAlignment: Text.AlignRight; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter; secondary: AudioService.muted }
        }
        Row { width: parent.width; spacing: 10; visible: BrightnessService.available && UserConfig.data.controlCenter.showBrightness
            IconButton { icon: BrightnessService.brightness > 0.5 ? "sun" : "sun-dim"; iconSize: 16; implicitWidth: 28; implicitHeight: 28; onClicked: cc.toggleSection("audio") }
            MonoSlider { width: parent.width - 28 - 10 - 44 - 10; anchors.verticalCenter: parent.verticalCenter; value: BrightnessService.brightness; onMoved: v => BrightnessService.set(v) }
            Label { text: Math.round(BrightnessService.brightness * 100) + "%"; mono: true; width: 44; horizontalAlignment: Text.AlignRight; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
        }
        Row { spacing: 6; Label { text: AudioService.sinkName; secondary: true; font.pixelSize: Theme.fontXs; width: cc.width - 80 }
              MonoButton { text: cc.expanded === "audio" ? "Hide devices" : "Devices"; flat: true; implicitHeight: 22; padding: 6; onClicked: cc.toggleSection("audio") } }
    }

    // ---- Expanded sections ----
    Loader {
        width: parent.width
        active: cc.expanded !== ""
        visible: active
        sourceComponent: {
            switch (cc.expanded) {
            case "network": return netComp
            case "bluetooth": return btComp
            case "audio": return audioComp
            case "battery": return batComp
            case "wallpaper": return wallComp
            default: return null
            }
        }
    }

    Component {
        id: netComp
        Column {
            spacing: 4
            Component.onCompleted: NetworkService.setScanning(true)
            Component.onDestruction: NetworkService.setScanning(false)
            Divider { width: parent.width }
            Row { width: parent.width; SectionTitle { text: "WI‑FI NETWORKS"; anchors.verticalCenter: parent.verticalCenter }
                Item { width: parent.width - 200; height: 1 }
                MonoButton { text: "Editor"; flat: true; implicitHeight: 22; padding: 6; onClicked: { NetworkService.openEditor(); ShellState.close() } } }
            Label { visible: !NetworkService.available; text: "NetworkManager is not available"; secondary: true; font.pixelSize: Theme.fontSm }
            Label { visible: NetworkService.available && !NetworkService.wifiEnabled; text: "Wi‑Fi is off"; secondary: true; font.pixelSize: Theme.fontSm }
            Label { visible: NetworkService.wifiEnabled && NetworkService.networks.length === 0; text: "Scanning…"; secondary: true; font.pixelSize: Theme.fontSm }
            property var passwordFor: null
            Repeater {
                model: NetworkService.wifiEnabled ? NetworkService.networks.slice(0, 8) : []
                delegate: Column {
                    id: nrow
                    required property var modelData
                    width: parent.width
                    Rectangle {
                        width: parent.width; height: 32; radius: Theme.radiusControl
                        color: ma.containsMouse ? Theme.hover : "transparent"
                        Row { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            MonoIcon { name: nrow.modelData.signalStrength > 0.66 ? "wifi" : nrow.modelData.signalStrength > 0.33 ? "wifi-medium" : "wifi-low"; size: 14; color: nrow.modelData.connected ? Theme.silverBright : Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: nrow.modelData.name; font.pixelSize: Theme.fontSm; width: cc.width - 150; font.weight: nrow.modelData.connected ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                            MonoIcon { visible: nrow.modelData.security !== 0 && !nrow.modelData.connected; name: "lock"; size: 11; color: Theme.textDisabled; anchors.verticalCenter: parent.verticalCenter } }
                        Label { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Theme.fontXs; secondary: true
                            text: nrow.modelData.connected ? "connected" : nrow.modelData.stateChanging ? "…" : nrow.modelData.known ? "saved" : "" }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = nrow.modelData
                                if (n.connected) NetworkService.disconnect(n)
                                else if (n.known || n.security === 0) NetworkService.connectKnown(n)
                                else parent.parent.parent.passwordFor = (parent.parent.parent.passwordFor === n ? null : n)
                            } }
                    }
                    Row { visible: parent.parent.passwordFor === nrow.modelData; width: parent.width; spacing: 6; height: visible ? 36 : 0
                        MonoTextField { id: pw; width: parent.width - 80; implicitHeight: 32; placeholder: "Password"; password: true; Component.onCompleted: input.forceActiveFocus()
                            onAccepted: NetworkService.connectWithPassword(nrow.modelData.name, text) }
                        MonoButton { text: "Join"; implicitHeight: 32; onClicked: NetworkService.connectWithPassword(nrow.modelData.name, pw.text) } }
                }
            }
            Label { visible: NetworkService.lastError !== ""; text: NetworkService.lastError; font.pixelSize: Theme.fontXs; color: Theme.silverBright; width: parent.width; wrapMode: Text.Wrap }
        }
    }
    Component {
        id: btComp
        Column {
            spacing: 4
            Component.onCompleted: BluetoothService.setDiscovering(true)
            Component.onDestruction: BluetoothService.setDiscovering(false)
            Divider { width: parent.width }
            Row { width: parent.width; SectionTitle { text: "BLUETOOTH DEVICES"; anchors.verticalCenter: parent.verticalCenter }
                Item { width: parent.width - 220; height: 1 }
                MonoButton { text: "Manager"; flat: true; implicitHeight: 22; padding: 6; onClicked: { BluetoothService.openManager(); ShellState.close() } } }
            Label { visible: !BluetoothService.available; text: "No Bluetooth adapter"; secondary: true; font.pixelSize: Theme.fontSm }
            Label { visible: BluetoothService.available && !BluetoothService.enabled; text: "Bluetooth is off"; secondary: true; font.pixelSize: Theme.fontSm }
            Label { visible: BluetoothService.enabled && BluetoothService.pairedDevices.length === 0 && BluetoothService.discoveredDevices.length === 0; text: BluetoothService.discovering ? "Searching…" : "No devices"; secondary: true; font.pixelSize: Theme.fontSm }
            Repeater {
                model: BluetoothService.enabled ? BluetoothService.pairedDevices.concat(BluetoothService.discoveredDevices.slice(0, 6)) : []
                delegate: Rectangle {
                    id: brow
                    required property var modelData
                    width: parent.width; height: 32; radius: Theme.radiusControl
                    color: ma.containsMouse ? Theme.hover : "transparent"
                    Row { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        MonoIcon { name: brow.modelData.connected ? "bluetooth-connected" : "bluetooth"; size: 14; color: brow.modelData.connected ? Theme.silverBright : Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: brow.modelData.name || brow.modelData.address; font.pixelSize: Theme.fontSm; width: cc.width - 170; font.weight: brow.modelData.connected ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter } }
                    Row { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Label { visible: brow.modelData.batteryAvailable; text: Math.round(brow.modelData.battery * 100) + "%"; mono: true; font.pixelSize: Theme.fontXs; secondary: true; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: brow.modelData.connected ? "connected" : brow.modelData.pairing ? "pairing…" : brow.modelData.paired ? "paired" : "new"; font.pixelSize: Theme.fontXs; secondary: true; anchors.verticalCenter: parent.verticalCenter }
                        IconButton { visible: brow.modelData.paired; icon: "x"; iconSize: 12; implicitWidth: 22; implicitHeight: 22; onClicked: BluetoothService.forget(brow.modelData) } }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1
                        onClicked: { if (brow.modelData.paired) BluetoothService.toggleConnect(brow.modelData); else BluetoothService.pair(brow.modelData) } }
                }
            }
        }
    }
    Component {
        id: audioComp
        Column {
            spacing: 4
            Divider { width: parent.width }
            SectionTitle { text: "OUTPUT" }
            Repeater { model: AudioService.sinks
                delegate: DeviceRow { required property var modelData; node: modelData; current: AudioService.sink === modelData; onPicked: AudioService.setDefaultSink(modelData) } }
            Label { visible: AudioService.sinks.length === 0; text: "No output devices"; secondary: true; font.pixelSize: Theme.fontSm }
            SectionTitle { text: "INPUT" }
            Repeater { model: AudioService.sources
                delegate: DeviceRow { required property var modelData; node: modelData; current: AudioService.source === modelData; onPicked: AudioService.setDefaultSource(modelData) } }
            Label { visible: AudioService.sources.length === 0; text: "No input devices"; secondary: true; font.pixelSize: Theme.fontSm }
            Row { width: parent.width; spacing: 10; visible: AudioService.source !== null
                IconButton { icon: AudioService.micMuted ? "mic-off" : "mic"; iconSize: 15; implicitWidth: 28; implicitHeight: 28; onClicked: AudioService.toggleMicMute() }
                MonoSlider { width: parent.width - 28 - 10 - 44 - 10; anchors.verticalCenter: parent.verticalCenter; value: AudioService.micVolume; onMoved: v => AudioService.setMicVolume(v) }
                Label { text: Math.round(AudioService.micVolume * 100) + "%"; mono: true; width: 44; horizontalAlignment: Text.AlignRight; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter } }
        }
    }
    Component {
        id: batComp
        Column {
            spacing: 6
            Divider { width: parent.width }
            SectionTitle { text: "POWER" }
            Row { spacing: 10
                MonoIcon { name: BatteryService.iconName(); size: 18; color: Theme.silver; anchors.verticalCenter: parent.verticalCenter }
                Column { anchors.verticalCenter: parent.verticalCenter
                    Label { text: BatteryService.present ? Math.round(BatteryService.percentage) + "%  ·  " + BatteryService.stateText() : "Running on AC power"; font.pixelSize: Theme.fontSm }
                    Label { text: BatteryService.onBattery ? "Source: battery" : "Source: mains"; secondary: true; font.pixelSize: Theme.fontXs } } }
            Row { spacing: 6; visible: UserConfig.data.controlCenter.showPowerProfile
                Repeater { model: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
                    delegate: MonoButton { required property var modelData; text: BatteryService.profileName(modelData); implicitHeight: 26; padding: 8
                        active: BatteryService.profilesAvailable && BatteryService.profile === modelData; enabled: BatteryService.profilesAvailable && (modelData !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)
                        onClicked: BatteryService.setProfile(modelData) } } }
            Label { visible: !BatteryService.profilesAvailable && UserConfig.data.controlCenter.showPowerProfile; text: "Power profile switching unavailable"; secondary: true; font.pixelSize: Theme.fontXs }
            Row { spacing: 6
                MonoButton { icon: "lock"; text: "Lock"; implicitHeight: 28; onClicked: { ShellState.close(); LockService.lock() } }
                MonoButton { icon: "moon"; text: "Suspend"; implicitHeight: 28; onClicked: { ShellState.close(); SystemService.suspend() } }
                MonoButton { icon: "power"; text: "Power menu"; implicitHeight: 28; onClicked: { ShellState.close(); ShellState.show("power", ShellState.screenName) } } }
        }
    }

    Component {
        id: wallComp
        Column {
            spacing: 6
            readonly property var st: WallpaperService.state(cc.monitorKey)
            readonly property var list: WallpaperService.collections[cc.monitorKey] || []
            Divider { width: parent.width }
            SectionTitle { text: "WALLPAPER · " + ShellState.screenName }
            Label { text: list.length === 0 ? "No images in the collection" : WallpaperService.fileName(WallpaperService.current(cc.monitorKey)) + "  ·  " + list.length + " images" + (st.paused ? "  ·  paused" : st.pinned ? "  ·  pinned" : "  ·  next in " + WallpaperService.remainingMinutes(cc.monitorKey) + " min"); font.pixelSize: Theme.fontSm; secondary: true; width: parent.width }
            Row { spacing: 6
                MonoButton { icon: "chevron-left"; implicitHeight: 28; enabled: list.length > 1; onClicked: WallpaperService.previous(cc.monitorKey) }
                MonoButton { icon: st.paused ? "play" : "pause"; text: st.paused ? "Resume" : "Pause"; implicitHeight: 28; enabled: list.length > 1; onClicked: WallpaperService.togglePaused(cc.monitorKey) }
                MonoButton { icon: "chevron-right"; implicitHeight: 28; enabled: list.length > 1; onClicked: WallpaperService.next(cc.monitorKey) }
                MonoButton { icon: "pin"; text: st.pinned ? "Unpin" : "Pin"; implicitHeight: 28; active: !!st.pinned; enabled: list.length > 0
                    onClicked: { if (st.pinned) WallpaperService.unpin(cc.monitorKey); else WallpaperService.select(cc.monitorKey, WallpaperService.current(cc.monitorKey), true) } }
                MonoButton { icon: "settings"; text: "Collection"; implicitHeight: 28; flat: true; onClicked: { ShellState.close(); ShellState.settingsOpen = true } } }
        }
    }

    Divider { width: parent.width }
    SectionTitle { text: "SCREENSHOT" }
    Row {
        spacing: 6
        MonoButton { icon: "image"; text: "Area"; implicitHeight: 28; onClicked: ScreenshotService.take("region") }
        MonoButton { icon: "monitor"; text: "Screen"; implicitHeight: 28; onClicked: ScreenshotService.take("screen") }
        MonoButton { icon: "app"; text: "Window"; implicitHeight: 28; onClicked: ScreenshotService.take("window") }
    }
    MonoButton { icon: "image"; text: "Annotate clipboard"; enabled: ScreenshotService.editorAvailable; implicitHeight: 28; onClicked: ScreenshotService.editClipboard() }
    Label { visible: ScreenshotService.lastError !== ""; text: ScreenshotService.lastError; width: parent.width; wrapMode: Text.Wrap; secondary: true; font.pixelSize: Theme.fontXs }

    component QuickTile: Rectangle {
        id: tile
        property string icon: "info"
        property string label: ""
        property string sub: ""
        property bool on: false
        property bool tileEnabled: true
        property bool hasExpand: true
        property bool expanded: false
        signal toggled()
        signal expand()
        height: 66
        radius: Theme.radiusControl
        color: on ? Theme.silver : tma.containsMouse ? Theme.hover : Theme.surface2
        border.width: 1; border.color: expanded ? Theme.silver : on ? Theme.silver : Theme.border
        opacity: tileEnabled ? 1 : 0.45
        Behavior on color { enabled: UserConfig.data.appearance.animations; ColorAnimation { duration: Theme.durFast } }
        Column { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 4
            MonoIcon { name: tile.icon; size: 16; color: tile.on ? Theme.inverse : Theme.silver }
            Label { text: tile.label; font.pixelSize: Theme.fontXs; font.weight: Font.DemiBold; color: tile.on ? Theme.inverse : Theme.text; width: tile.width - 30; elide: Text.ElideNone; wrapMode: Text.NoWrap; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 9 }
            Label { text: tile.sub; font.pixelSize: Theme.fontXs; color: tile.on ? Qt.rgba(0,0,0,0.6) : Theme.silverMuted; width: tile.width - 36 } }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; enabled: tile.tileEnabled; cursorShape: Qt.PointingHandCursor; onClicked: tile.toggled() }
        Rectangle { visible: tile.hasExpand; width: 18; height: 18; radius: 3; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
            color: ema.containsMouse ? (tile.on ? Qt.rgba(0,0,0,0.15) : Theme.pressed) : "transparent"
            MonoIcon { anchors.centerIn: parent; name: tile.expanded ? "chevron-down" : "chevron-up"; size: 12; color: tile.on ? Theme.inverse : Theme.silverMuted }
            MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; enabled: tile.tileEnabled; onClicked: tile.expand() } }
    }
    component DeviceRow: Rectangle {
        property var node
        property bool current: false
        signal picked()
        width: parent.width; height: 28; radius: Theme.radiusControl
        color: current ? Theme.elevated : dma.containsMouse ? Theme.hover : "transparent"
        Row { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            MonoIcon { name: current ? "check" : "dot"; size: 12; color: current ? Theme.silverBright : Theme.textDisabled; anchors.verticalCenter: parent.verticalCenter }
            Label { text: AudioService.label(node); font.pixelSize: Theme.fontSm; width: cc.width - 80; anchors.verticalCenter: parent.verticalCenter; color: current ? Theme.text : Theme.textSecondary } }
        MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: picked() }
    }
}
