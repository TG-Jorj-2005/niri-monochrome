import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Fullscreen overlay power menu with confirmation. Opened via Mod+X / IPC.
Scope {
    id: powerMenu
    required property var modelData
    property bool visible_: false
    property string confirm: ""
    property int selected: 0

    readonly property var actions: [
        { id: "lock",     label: "Lock",      icon: "lock",    key: "L", needsConfirm: false },
        { id: "suspend",  label: "Suspend",   icon: "moon",    key: "S", needsConfirm: false },
        { id: "logout",   label: "Log out",   icon: "log-out", key: "O", needsConfirm: true },
        { id: "reboot",   label: "Reboot",    icon: "reboot",  key: "R", needsConfirm: true },
        { id: "shutdown", label: "Shut down", icon: "power",   key: "P", needsConfirm: true }
    ]

    Process {
        id: proc
    }

    function run(a) {
        if (!a) return
        if (a.needsConfirm && confirm !== a.id) {
            confirm = a.id
            return
        }
        powerMenu.close()
        switch (a.id) {
        case "lock":
            proc.command = ["swaylock", "-f"]
            proc.running = true
            break
        case "suspend":
            proc.command = ["systemctl", "suspend"]
            proc.running = true
            break
        case "logout":
            proc.command = ["niri", "msg", "action", "quit", "--skip-confirmation"]
            proc.running = true
            break
        case "reboot":
            proc.command = ["systemctl", "reboot"]
            proc.running = true
            break
        case "shutdown":
            proc.command = ["systemctl", "poweroff"]
            proc.running = true
            break
        }
    }

    function open() {
        confirm = ""
        selected = 0
        visible_ = true
    }
    function close() {
        confirm = ""
        visible_ = false
    }
    function toggle() {
        if (visible_) close(); else open()
    }

    // Overlay window
    PanelWindow {
        id: overlay
        screen: powerMenu.modelData
        visible: powerMenu.visible_
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "nm-power"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: powerMenu.visible_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) menuPanel.forceActiveFocus()

        // Scrim — click to close
        MouseArea {
            anchors.fill: parent
            onClicked: powerMenu.close()
            Rectangle { anchors.fill: parent; color: Theme.scrim }
        }

        // Center card
        Rectangle {
            id: menuPanel
            anchors.centerIn: parent
            width: 540
            height: col.implicitHeight + 40
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
            focus: true
            antialiasing: true

            // Entrance animation
            opacity: powerMenu.visible_ ? 1 : 0
            transform: Translate { y: powerMenu.visible_ ? 0 : 8 }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
            Behavior on transform { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

            // Keyboard navigation
            Keys.onLeftPressed: { powerMenu.selected = (powerMenu.selected + powerMenu.actions.length - 1) % powerMenu.actions.length; powerMenu.confirm = "" }
            Keys.onRightPressed: { powerMenu.selected = (powerMenu.selected + 1) % powerMenu.actions.length; powerMenu.confirm = "" }
            Keys.onTabPressed: { powerMenu.selected = (powerMenu.selected + 1) % powerMenu.actions.length; powerMenu.confirm = "" }
            Keys.onReturnPressed: powerMenu.run(powerMenu.actions[powerMenu.selected])
            Keys.onEnterPressed: powerMenu.run(powerMenu.actions[powerMenu.selected])
            Keys.onEscapePressed: powerMenu.close()
            Keys.onPressed: e => {
                const i = ["l","s","o","r","p"].indexOf(e.text.toLowerCase())
                if (i >= 0) {
                    powerMenu.selected = i
                    powerMenu.run(powerMenu.actions[i])
                    e.accepted = true
                }
            }

            Column {
                id: col
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 16

                // Header
                Row {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    MonoIcon {
                        name: "power"
                        size: 15
                        color: Theme.silver
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "POWER MENU"
                        font.family: Theme.sans
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                        color: Theme.silver
                        anchors.verticalCenter: parent.verticalCenter
                        renderType: Text.NativeRendering
                    }
                }

                // Action buttons
                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: powerMenu.actions
                        delegate: Rectangle {
                            id: btnCell
                            required property var modelData
                            required property int index
                            readonly property bool sel: powerMenu.selected === index
                            readonly property bool confirming: powerMenu.confirm === modelData.id
                            width: (col.width - 40) / 5
                            height: 84
                            radius: Theme.radiusSmall
                            color: confirming ? Theme.silver : (sel || btnMa.containsMouse ? Theme.elevated : Theme.surface2)
                            border.width: 1
                            border.color: confirming ? Theme.silverBright : (sel ? Theme.silver : Theme.border)
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                MonoIcon {
                                    name: btnCell.modelData.icon
                                    size: 22
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: btnCell.confirming ? Theme.inverse : (btnCell.sel ? Theme.text : Theme.silver)
                                }
                                Text {
                                    text: btnCell.confirming ? "Confirm?" : btnCell.modelData.label
                                    font.family: Theme.sans
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: btnCell.confirming ? Theme.inverse : (btnCell.sel ? Theme.text : Theme.textDim)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    text: btnCell.modelData.key
                                    font.family: Theme.mono
                                    font.pixelSize: 10
                                    color: btnCell.confirming ? Theme.inverse : Theme.muted
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                id: btnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: { powerMenu.selected = btnCell.index; powerMenu.confirm = "" }
                                onClicked: powerMenu.run(btnCell.modelData)
                            }
                        }
                    }
                }

                // Footer hint
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: powerMenu.confirm !== "" ? "Press again or Enter to confirm · Esc to cancel" : "← → select · ↵ run · [L S O R P] shortcuts · esc close"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.muted
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
