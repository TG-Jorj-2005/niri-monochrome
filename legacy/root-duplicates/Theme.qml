pragma Singleton
import QtQuick
import Quickshell

// NIRI MONOCHROME — Design tokens.
Singleton {
    // Palette
    readonly property color background:   "#080808"
    readonly property color surface:      "#111111"
    readonly property color surface2:     "#191919"
    readonly property color elevated:     "#222222"
    readonly property color border:       "#393939"
    readonly property color muted:        "#777777"
    readonly property color silver:       "#BDBDBD"
    readonly property color silverBright: "#D6D6D6"
    readonly property color text:         "#EEEEEE"
    readonly property color textDim:      "#999999"
    readonly property color inverse:      "#080808"
    readonly property color hover:        "#1E1E1E"
    readonly property color pressed:      "#2A2A2A"
    readonly property color scrim:        Qt.rgba(0, 0, 0, 0.55)

    // Geometry
    readonly property int radius: 10
    readonly property int radiusSmall: 5

    // Typography
    readonly property var _fam: Qt.fontFamilies()
    function _pick(list, fb) { for (const f of list) if (_fam.indexOf(f) !== -1) return f; return fb }
    readonly property string sans: _pick(["Inter", "Noto Sans", "Cantarell"], "sans-serif")
    readonly property string mono: _pick(["JetBrains Mono", "Noto Sans Mono"], "monospace")

    // Motion
    readonly property int animFast: 140
    readonly property int animNormal: 170
    readonly property int easing: Easing.OutCubic
}
