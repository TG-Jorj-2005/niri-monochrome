import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Networking

// Floating centered bottom bar — one per monitor.
PanelWindow {
    id: bar
    required property var modelData
    readonly property bool isFocused: NiriService.focusedOutput === modelData.name

    signal powerRequested()

    screen: modelData
    anchors.bottom: true
    margins.bottom: 14
    implicitWidth: Math.min(modelData.width - 48, 1600)
    implicitHeight: 54
    exclusiveZone: 68    // height + margin
    color: "transparent"
    WlrLayershell.namespace: "nm-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Bar surface
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.border
        antialiasing: true

        // ======== LEFT: NIRI logo + workspaces ========
        Row {
            id: leftSection
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // NIRI wordmark
            Rectangle {
                implicitWidth: niriLabel.implicitWidth + 16
                implicitHeight: 26
                radius: Theme.radiusSmall
                color: niriMa.containsMouse ? Theme.hover : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: niriLabel
                    anchors.centerIn: parent
                    text: "NIRI"
                    font.family: Theme.sans
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 2.5
                    color: niriMa.containsMouse ? Theme.text : Theme.silver
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: niriMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriService.toggleOverview()
                }
            }

            // Divider
            Rectangle { width: 1; height: 18; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

            // Workspace indicators
            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: NiriService.workspacesOn(bar.modelData.name)
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool active: modelData.is_active
                        readonly property bool urgent: modelData.is_urgent
                        width: 26; height: 26
                        radius: Theme.radiusSmall
                        color: active ? (wsMa.containsMouse ? Theme.silverBright : Theme.silver)
                             : wsMa.containsMouse ? Theme.hover : "transparent"
                        border.width: urgent && !active ? 1 : 0
                        border.color: Theme.silverBright
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Text {
                            anchors.centerIn: parent
                            text: String(index + 1)
                            font.family: Theme.mono
                            font.pixelSize: 12
                            font.weight: active ? Font.Bold : Font.Medium
                            color: active ? Theme.inverse
                                 : urgent ? Theme.silverBright
                                 : wsMa.containsMouse ? Theme.text : Theme.muted
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NiriService.focusWorkspaceById(modelData.id)
                            onWheel: w => NiriService.action([w.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up"])
                        }
                    }
                }
                // Offline state
                Text {
                    visible: !NiriService.connected
                    text: "niri —"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.muted
                    renderType: Text.NativeRendering
                }
            }
        }

        // ======== CENTER: Focused window ========
        Row {
            anchors.centerIn: parent
            spacing: 8
            readonly property var win: bar.isFocused ? NiriService.focusedWindow : null
            readonly property var entry: win ? DesktopEntries.byId(win.app_id) || (win.app_id ? DesktopEntries.heuristicLookup(win.app_id) : null) : null
            readonly property string appName: entry ? entry.name : (win ? (win.app_id || "") : "")
            readonly property string title: win ? (win.title || "") : ""
            readonly property string display: {
                if (!win) return ""
                let t = title
                if (t.length > 64) t = t.substring(0, 63) + "…"
                if (appName && t && !t.toLowerCase().includes(appName.toLowerCase()))
                    return appName + "  ·  " + t
                return t || appName
            }

            AppIcon {
                visible: parent.win !== null
                icon: parent.entry ? parent.entry.icon : ""
                size: 18
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, bar.width - leftSection.width - rightSection.width - 80)
                text: parent.win ? parent.display : "Desktop"
                color: parent.win ? Theme.text : Theme.muted
                font.family: Theme.sans
                font.pixelSize: 13
                font.weight: parent.win ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        // ======== RIGHT: System status ========
        Row {
            id: rightSection
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Network indicator
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: netText.implicitWidth + 12
                implicitHeight: 26
                radius: Theme.radiusSmall
                color: "transparent"

                readonly property bool wifiOn: Networking.wifiEnabled
                readonly property var devs: Networking.devices.values
                readonly property var wifiDev: devs ? devs.find(d => d && d.type === DeviceType.Wifi) : null
                readonly property bool wifiConnected: wifiDev ? wifiDev.connected : false
                readonly property var nets: wifiDev && wifiDev.networks ? wifiDev.networks.values : []
                readonly property var activeNet: nets ? nets.find(n => n.connected) : null
                readonly property bool wiredConnected: devs ? devs.some(d => d && d.type !== DeviceType.Wifi && d.connected) : false

                Text {
                    id: netText
                    anchors.centerIn: parent
                    text: parent.wifiConnected ? (parent.activeNet ? parent.activeNet.name : "WIFI")
                        : parent.wiredConnected ? "ETH"
                        : parent.wifiOn ? "NET·—" : "NET·OFF"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: (parent.wifiConnected || parent.wiredConnected) ? Theme.silver : Theme.muted
                    renderType: Text.NativeRendering
                }
            }

            // Bluetooth indicator
            Rectangle {
                visible: Bluetooth.defaultAdapter !== null
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: btText.implicitWidth + 12
                implicitHeight: 26
                radius: Theme.radiusSmall
                color: "transparent"

                readonly property bool on: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                readonly property int count: on ? Bluetooth.devices.values.filter(d => d && d.connected).length : 0

                Text {
                    id: btText
                    anchors.centerIn: parent
                    text: !parent.on ? "BT·OFF" : parent.count > 0 ? "BT·" + parent.count : "BT"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: parent.on ? Theme.silver : Theme.muted
                    renderType: Text.NativeRendering
                }
            }

            // Volume indicator (click to toggle mute, wheel to change volume)
            Rectangle {
                id: volBox
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: volText.implicitWidth + 12
                implicitHeight: 26
                radius: Theme.radiusSmall
                color: volMa.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

                readonly property var sink: Pipewire.defaultAudioSink
                readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
                readonly property real vol: sink && sink.audio ? sink.audio.volume : 0

                Text {
                    id: volText
                    anchors.centerIn: parent
                    text: volBox.muted ? "VOL·MUTE" : "VOL·" + Math.round(volBox.vol * 100) + "%"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: volBox.muted ? Theme.muted : Theme.silver
                    renderType: Text.NativeRendering
                }

                MouseArea {
                    id: volMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (volBox.sink && volBox.sink.audio)
                            volBox.sink.audio.muted = !volBox.sink.audio.muted
                    }
                    onWheel: w => {
                        if (volBox.sink && volBox.sink.audio) {
                            volBox.sink.audio.muted = false
                            volBox.sink.audio.volume = Math.max(0, Math.min(1.5, volBox.sink.audio.volume + (w.angleDelta.y > 0 ? 0.03 : -0.03)))
                        }
                    }
                }
            }

            // Divider
            Rectangle { width: 1; height: 18; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

            // Battery indicator
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: UPower.displayDevice && UPower.displayDevice.isPresent
                implicitWidth: batText.implicitWidth + 12
                implicitHeight: 26
                radius: Theme.radiusSmall
                color: "transparent"

                readonly property var dev: UPower.displayDevice
                readonly property real pct: dev ? dev.percentage * 100 : 0
                readonly property bool charging: dev ? (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge) : false
                readonly property bool full: dev ? dev.state === UPowerDeviceState.FullyCharged : false

                Text {
                    id: batText
                    anchors.centerIn: parent
                    text: (parent.charging ? "BAT·⚡" : "BAT·") + Math.round(parent.pct) + "%"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: (!parent.charging && !parent.full && parent.pct <= 15) ? Theme.silverBright : Theme.silver
                    renderType: Text.NativeRendering
                }
            }

            // System Tray items (StatusNotifierItems)
            Row {
                id: trayRow
                visible: SystemTray.items.length > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Rectangle { width: 1; height: 18; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

                Repeater {
                    model: SystemTray.items
                    delegate: Rectangle {
                        id: trayCell
                        required property var modelData
                        width: 24; height: 24
                        radius: Theme.radiusSmall
                        color: trayMa.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        AppIcon {
                            anchors.centerIn: parent
                            size: 16
                            icon: trayCell.modelData.icon
                        }

                        MouseArea {
                            id: trayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                const it = trayCell.modelData
                                if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && it.onlyMenu)) {
                                    if (it.hasMenu) it.displayMenu()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    it.secondaryActivate()
                                } else {
                                    it.activate()
                                }
                            }
                            onWheel: w => trayCell.modelData.scroll(w.angleDelta.y, false)
                        }
                    }
                }
            }

            // Divider
            Rectangle { width: 1; height: 18; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

            // Clock + Date
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                SystemClock { id: clock; precision: SystemClock.Minutes }
                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: Theme.mono
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                    font.family: Theme.sans
                    font.pixelSize: 12
                    color: Theme.muted
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.NativeRendering
                }
            }

            // Divider
            Rectangle { width: 1; height: 18; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }

            // Power button
            Rectangle {
                id: pwrBtn
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 26
                implicitHeight: 26
                radius: Theme.radiusSmall
                color: pwrMa.containsMouse ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                MonoIcon {
                    name: "power"
                    size: 14
                    color: pwrMa.containsMouse ? Theme.text : Theme.silver
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: pwrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.powerRequested()
                }
            }
        }
    }
}
