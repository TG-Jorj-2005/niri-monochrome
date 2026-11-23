import QtQuick
import qs.config

// Base surface: dark, 1px border, panel radius.
Rectangle {
    property bool elevated: false
    color: elevated ? Theme.surface2 : Theme.surface
    radius: Theme.radiusPanel
    border.width: Theme.borderWidth
    border.color: Theme.border
    antialiasing: true
    Rectangle { anchors.fill: parent; anchors.margins: -1; z: -1; radius: parent.radius + 1; color: "transparent"; border.width: 1; border.color: Qt.rgba(0,0,0,UserConfig.data.appearance.shadowStrength) }
    Rectangle { x: parent.radius; y: 1; width: Math.max(0, parent.width-parent.radius*2); height: 1; color: Qt.rgba(1,1,1,0.055); visible: UserConfig.data.appearance.glassEnabled }
}
