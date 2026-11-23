import QtQuick
import qs.config

// Rectangular button with an optional icon and an accented active state.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property real iconSize: 16
    property bool active: false
    property bool flat: false
    property bool danger: false
    property int padding: 12
    property alias hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()
    signal wheel(int delta)

    activeFocusOnTab: true
    property bool keyPressed: false
    scale: (ma.pressed || keyPressed) && Theme.motionEnabled ? 1 - 0.035 * Theme.motionIntensity : 1
    Behavior on scale { NumberAnimation { duration: Theme.motionEnabled ? 100 : 0; easing.type: Theme.easing } }
    Keys.onPressed: e => { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !e.isAutoRepeat) { keyPressed = true; e.accepted = true } }
    Keys.onReleased: e => { if (keyPressed && (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { keyPressed = false; if (enabled) clicked(); e.accepted = true } }
    onActiveFocusChanged: if (!activeFocus) keyPressed = false
    Rectangle { anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2; color: "transparent"; border.width: 1; border.color: Theme.accent; visible: parent.activeFocus }
    implicitHeight: 32
    implicitWidth: row.implicitWidth + padding * 2
    radius: Theme.radiusControl
    color: !enabled ? "transparent"
         : active ? Theme.accentFill(ma.containsMouse, ma.pressed || keyPressed)
         : ma.pressed || keyPressed ? Theme.pressed : ma.containsMouse ? Theme.accentSubtle
         : flat ? "transparent" : Theme.surface2
    border.width: flat || active ? 0 : 1
    border.color: ma.containsMouse ? Theme.accent : Theme.border
    opacity: enabled ? 1 : 0.45
    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        MonoIcon { visible: root.icon !== ""; name: root.icon; size: root.iconSize; anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Theme.textOnAccent(root.color) : (ma.containsMouse ? Theme.accentHover : Theme.silver) }
        Label { visible: root.text !== ""; text: root.text; anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Theme.textOnAccent(root.color) : (ma.containsMouse ? Theme.text : Theme.silver); font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: root.forceActiveFocus(Qt.MouseFocusReason)
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else root.clicked() }
        onWheel: w => root.wheel(w.angleDelta.y)
    }
}
