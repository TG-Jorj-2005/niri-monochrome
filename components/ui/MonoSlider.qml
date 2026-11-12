import QtQuick
import qs.config

// Horizontal slider: thin track, silver fill, rectangular handle.
Item {
    id: root
    property real value: 0          // 0..1
    property real from: 0
    property real to: 1
    property alias pressed: ma.pressed
    signal moved(real value)
    implicitHeight: 24
    implicitWidth: 160
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    opacity: enabled ? 1 : 0.4

    Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1; color: Theme.border }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.frac * parent.width; height: 3; radius: 1; color: ma.containsMouse || ma.pressed ? Theme.silverBright : Theme.silver }
    Rectangle {
        x: root.frac * (parent.width - width); anchors.verticalCenter: parent.verticalCenter
        width: 10; height: 16; radius: 2
        color: ma.pressed ? Theme.silverBright : Theme.silver
        border.width: 1; border.color: Theme.background
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        preventStealing: true
        function update(mx) { const f = Math.max(0, Math.min(1, mx / width)); root.value = root.from + f * (root.to - root.from); root.moved(root.value) }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
        onWheel: w => { const step = (root.to - root.from) * 0.05; root.value = Math.max(root.from, Math.min(root.to, root.value + (w.angleDelta.y > 0 ? step : -step))); root.moved(root.value) }
    }
}
