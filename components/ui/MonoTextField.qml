import QtQuick
import qs.config

// Minimal text input with placeholder and optional leading icon.
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property bool mono: false
    signal accepted()
    implicitHeight: 40
    radius: Theme.radiusControl
    color: Theme.surface2
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border
    Behavior on border.color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }
    MonoIcon { id: ico; visible: root.icon !== ""; name: root.icon; size: 16; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.silverMuted }
    TextInput {
        id: input
        anchors.left: root.icon !== "" ? ico.right : parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.icon !== "" ? 10 : 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.family: root.mono ? Theme.fontMono : Theme.fontSans
        font.pixelSize: Theme.fontLg
        selectionColor: Theme.accent
        selectedTextColor: Theme.textOnAccent(Theme.accent)
        clip: true
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        renderType: Text.NativeRendering
        onAccepted: root.accepted()
        Text { visible: input.text === ""; text: root.placeholder; color: Theme.textSecondary; font: input.font; anchors.verticalCenter: parent.verticalCenter; renderType: Text.NativeRendering }
    }
}
