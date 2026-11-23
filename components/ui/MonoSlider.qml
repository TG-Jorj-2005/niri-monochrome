import QtQuick
import qs.config

// Horizontal slider with an accented fill and handle.
Item {
    id: root
    property real value: 0          // 0..1
    property real from: 0
    property real to: 1
    property alias pressed: ma.pressed
    signal moved(real value)
    implicitHeight: 24
    implicitWidth: 160
    activeFocusOnTab: true
    property real dragValue: value
    function commit(v) { moved(Math.max(from, Math.min(to, v))) }
    Keys.onPressed: e => {
        let v = value
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Down) v -= (to-from)*0.05
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Up) v += (to-from)*0.05
        else if (e.key === Qt.Key_Home) v = from
        else if (e.key === Qt.Key_End) v = to
        else return
        commit(v); e.accepted = true
    }
    Rectangle { anchors.fill: parent; radius: Theme.radiusControl; color: "transparent"; border.width: 1; border.color: Theme.accent; visible: root.activeFocus }
    property real frac: Math.max(0, Math.min(1, ((ma.pressed ? dragValue : value) - from) / Math.max(0.00001, to - from)))
    Behavior on frac { enabled: Theme.motionEnabled && !ma.pressed; NumberAnimation { duration: 90; easing.type: Theme.easing } }
    opacity: enabled ? 1 : 0.4

    Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1; color: ma.containsMouse ? Theme.silverMuted : Theme.border }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.frac * parent.width; height: 3; radius: 1; color: Theme.accentFill(ma.containsMouse, ma.pressed) }
    Rectangle {
        x: root.frac * (parent.width - width); anchors.verticalCenter: parent.verticalCenter
        width: 10; height: 16; radius: 2
        color: Theme.accentFill(ma.containsMouse, ma.pressed)
        border.width: 1; border.color: Theme.background
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        preventStealing: true
        function update(mx) { const f = Math.max(0, Math.min(1, mx / width)); root.dragValue = root.from + f * (root.to - root.from); root.commit(root.dragValue) }
        onPressed: mouse => { root.forceActiveFocus(Qt.MouseFocusReason); update(mouse.x) }
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
        onWheel: w => { const step = (root.to - root.from) * 0.05; root.commit(root.value + (w.angleDelta.y > 0 ? step : -step)) }
    }
}
