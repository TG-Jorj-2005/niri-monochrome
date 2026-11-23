import QtQuick
import qs.config

// Rectangular switch with an accented enabled state.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool checked)
    activeFocusOnTab: true
    Keys.onPressed: e => { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !e.isAutoRepeat) { toggled(!checked); e.accepted = true } }
    Rectangle { anchors.fill: parent; anchors.margins: -3; radius: height / 2; color: "transparent"; border.width: 1; border.color: Theme.accent; visible: root.activeFocus }
    implicitWidth: 38
    implicitHeight: 20
    radius: height / 2
    color: checked ? Theme.accentFill(ma.containsMouse, ma.pressed) : ma.containsMouse ? Theme.accentSubtle : Theme.surface2
    border.width: 1
    border.color: checked || ma.containsMouse ? Theme.accent : Theme.border
    opacity: enabled ? 1 : 0.4
    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionEnabled ? 180 : 0 } }
    Rectangle {
        width: 14; height: 14; radius: 7
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.textOnAccent(root.color) : Theme.silverMuted
        Behavior on x { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.motionEnabled ? 180 : 0; easing.type: Theme.easing } }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: { root.forceActiveFocus(Qt.MouseFocusReason); root.toggled(!root.checked) } }
}
