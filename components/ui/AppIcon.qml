import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config

// Application icon (from the icon theme), desaturated to keep the shell monochrome.
Item {
    id: root
    property string icon: ""           // icon name or path
    property real size: 32
    property bool grayscale: UserConfig.data.appearance.grayscaleAppIcons
    property real dim: 1.0             // 0..1 brightness multiplier (running/inactive states)
    property string fallbackGlyph: "app"
    implicitWidth: size
    implicitHeight: size

    readonly property string resolved: icon === "" ? "" : (icon.startsWith("/") || icon.startsWith("file:") || icon.startsWith("data:") ? icon : Quickshell.iconPath(icon, true))
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
        brightness: (root.dim - 1.0) * 0.6
        contrast: 0.05
    }
    MonoIcon {
        anchors.centerIn: parent
        visible: !root.hasIcon
        name: root.fallbackGlyph
        size: root.size * 0.7
        color: Theme.silverMuted
    }
}
