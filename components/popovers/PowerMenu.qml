import QtQuick
import qs.config
import qs.services
import qs.components.ui

// Centered power menu: Lock · Suspend · Logout · Reboot · Shutdown, with confirmation.
Panel {
    id: menu
    implicitWidth: 520
    implicitHeight: col.implicitHeight + 40
    border.color: Theme.silverMuted
    property string confirm: ""
    property int selected: 0
    focus: true

    readonly property var actions: [
        { id: "lock",     label: "Lock",      icon: "lock",    needsConfirm: false },
        { id: "suspend",  label: "Suspend",   icon: "moon",    needsConfirm: false },
        { id: "logout",   label: "Log out",   icon: "log-out", needsConfirm: true },
        { id: "reboot",   label: "Reboot",    icon: "reboot",  needsConfirm: true },
        { id: "shutdown", label: "Shut down", icon: "power",   needsConfirm: true }
    ]

    function run(a) {
        if (a.needsConfirm && UserConfig.data.controlCenter.confirmPower && confirm !== a.id) { confirm = a.id; return }
        ShellState.close()
        switch (a.id) {
        case "lock": LockService.lock(); break
        case "suspend": SystemService.suspend(); break
        case "logout": SystemService.logout(); break
        case "reboot": SystemService.reboot(); break
        case "shutdown": SystemService.shutdown(); break
        }
    }
    Keys.onLeftPressed: { selected = (selected + actions.length - 1) % actions.length; confirm = "" }
    Keys.onRightPressed: { selected = (selected + 1) % actions.length; confirm = "" }
    Keys.onTabPressed: { selected = (selected + 1) % actions.length; confirm = "" }
    Keys.onReturnPressed: run(actions[selected])
    Keys.onEnterPressed: run(actions[selected])
    Keys.onPressed: e => { const i = ["l","s","o","r","p"].indexOf(e.text.toLowerCase()); if (i >= 0) { selected = i; run(actions[i]); e.accepted = true } }

    Column {
        id: col
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 16
        Row { spacing: 8; MonoIcon { name: "power"; size: 14; color: Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
              SectionTitle { text: "POWER"; anchors.verticalCenter: parent.verticalCenter } }
        Row {
            spacing: 10
            Repeater {
                model: menu.actions
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: menu.selected === index
                    readonly property bool confirming: menu.confirm === modelData.id
                    width: (col.width - 40) / 5; height: 84
                    radius: Theme.radiusPanel
                    color: confirming ? Theme.silver : sel ? Theme.accentSubtle : ma.containsMouse ? Theme.elevated : Theme.surface2
                    border.width: 1; border.color: confirming ? Theme.silverBright : sel ? Theme.accent : Theme.border
                    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }
                    Column { anchors.centerIn: parent; spacing: 8
                        MonoIcon { name: parent.parent.modelData.icon; size: 22; anchors.horizontalCenter: parent.horizontalCenter; color: parent.parent.confirming ? Theme.inverse : Theme.silver }
                        Label { text: parent.parent.confirming ? "Confirm?" : parent.parent.modelData.label; font.pixelSize: Theme.fontSm; anchors.horizontalCenter: parent.horizontalCenter
                            color: parent.parent.confirming ? Theme.inverse : Theme.text; font.weight: Font.Medium } }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: menu.selected = parent.index
                        onClicked: menu.run(parent.modelData) }
                }
            }
        }
        Label { text: menu.confirm !== "" ? "Press again to confirm · Esc to cancel" : "← →  select   ·   Enter  run   ·   Esc  close"; secondary: true; font.pixelSize: Theme.fontXs; mono: true }
    }
}
