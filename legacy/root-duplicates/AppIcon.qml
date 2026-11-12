import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// Monochrome application icon from theme. Desaturated by default.
Item {
    id: root
    property string icon: ""
    property real size: 32
    property bool grayscale: true
    implicitWidth: size
    implicitHeight: size

    readonly property string resolved: icon === "" ? "" : (icon.startsWith("/") || icon.startsWith("file:") ? icon : Quickshell.iconPath(icon, true))
    readonly property bool hasIcon: resolved !== ""

    IconImage {
        id: img
        anchors.fill: parent
        source: root.resolved
        asynchronous: true
        visible: root.hasIcon && !root.grayscale
        mipmap: true
    }
    MultiEffect {
        anchors.fill: parent
        source: img
        visible: root.hasIcon && root.grayscale
        saturation: -1.0
        contrast: 0.05
    }
    // Fallback: small rectangle placeholder
    Rectangle {
        visible: !root.hasIcon
        anchors.centerIn: parent
        width: root.size * 0.6; height: width
        radius: 3
        color: "transparent"
        border.width: 1
        border.color: Theme.muted
    }
}
