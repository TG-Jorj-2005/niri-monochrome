import QtQuick
import qs.config

// Rectangular switch. On = silver fill.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool checked)
    implicitWidth: 38
    implicitHeight: 20
    radius: Theme.radiusControl
    color: checked ? Theme.silver : Theme.surface2
    border.width: 1
    border.color: checked ? Theme.silver : (ma.containsMouse ? Theme.silverMuted : Theme.border)
    opacity: enabled ? 1 : 0.4
    Behavior on color { enabled: UserConfig.data.appearance.animations; ColorAnimation { duration: Theme.durFast } }
    Rectangle {
        width: 14; height: 14; radius: 3
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.inverse : Theme.silverMuted
        Behavior on x { enabled: UserConfig.data.appearance.animations; NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
