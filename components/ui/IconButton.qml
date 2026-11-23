import QtQuick
import qs.config

// Square icon-only button used in the bar, popovers and toasts.
Rectangle {
    id: root
    property string icon: "info"
    property real iconSize: 16
    property bool active: false
    property string tooltip: ""
    property alias hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(int delta)
    implicitWidth: 30
    activeFocusOnTab: true
    property bool keyPressed: false
    scale: (ma.pressed || keyPressed) && Theme.motionEnabled ? 1 - 0.035 * Theme.motionIntensity : 1
    Behavior on scale { NumberAnimation { duration: Theme.motionEnabled ? 100 : 0; easing.type: Theme.easing } }
    Keys.onPressed: e => { if ((e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !e.isAutoRepeat) { keyPressed = true; e.accepted = true } }
    Keys.onReleased: e => { if (keyPressed && (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { keyPressed = false; if (enabled) clicked(); e.accepted = true } }
    onActiveFocusChanged: if (!activeFocus) keyPressed = false
    Rectangle { anchors.fill: parent; anchors.margins: -2; radius: parent.radius + 2; color: "transparent"; border.width: 1; border.color: Theme.accent; visible: parent.activeFocus }
    implicitHeight: 30
    radius: Theme.radiusControl
    color: active ? Theme.accentFill(ma.containsMouse, ma.pressed || keyPressed)
                  : ma.pressed || keyPressed ? Theme.pressed : ma.containsMouse ? Theme.accentSubtle : "transparent"
    opacity: enabled ? 1 : 0.4
    Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }
    MonoIcon { anchors.centerIn: parent; name: root.icon; size: root.iconSize
        color: root.active ? Theme.textOnAccent(root.color) : (ma.containsMouse ? Theme.accentHover : Theme.silver) }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onPressed: root.forceActiveFocus(Qt.MouseFocusReason)
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else if (mouse.button === Qt.MiddleButton) root.middleClicked(); else root.clicked() }
        onWheel: w => root.wheel(w.angleDelta.y)
    }
}
