pragma Singleton
import QtQuick
import Quickshell

// Centralized design tokens for NIRI MONOCHROME.
// Everything visual (colors, radii, spacing, fonts, motion) comes from here.
Singleton {
    id: theme

    // ---- Palette (confirmed design identity) ----
    readonly property color background:  "#080808"
    readonly property color surface:     "#111111"
    readonly property color surface2:    "#191919"
    readonly property color elevated:    "#222222"
    readonly property color border:      "#393939"
    readonly property color silverMuted: "#777777"
    readonly property color silver:      "#BDBDBD"
    readonly property color silverBright:"#D6D6D6"
    readonly property color text:        "#EEEEEE"
    readonly property color textSecondary:"#A0A0A0"
    readonly property color textDisabled:"#666666"
    // Derived helpers
    readonly property color inverse:    "#080808"          // text drawn on a silver surface
    readonly property color hover:       "#1E1E1E"
    readonly property color pressed:     "#2A2A2A"
    readonly property color scrim:       Qt.rgba(0, 0, 0, 0.55)
    readonly property color shadow:      Qt.rgba(0, 0, 0, 0.6)
    readonly property color danger:      "#D6D6D6"          // monochrome: emphasis, not red

    // ---- Geometry ----
    readonly property int grid: 8
    readonly property int radiusBar: 10
    readonly property int radiusPanel: 10
    readonly property int radiusControl: 5
    readonly property int borderWidth: 1

    // ---- Typography ----
    readonly property var _families: Qt.fontFamilies()
    function pick(list, fallback) {
        for (const f of list) if (_families.indexOf(f) !== -1) return f
        return fallback
    }
    readonly property string fontSans: pick(["Geist", "Geist Sans", "Inter", "Adwaita Sans", "Noto Sans", "Cantarell"], "sans-serif")
    readonly property string fontMono: pick(["JetBrains Mono", "Adwaita Mono", "Noto Sans Mono", "DejaVu Sans Mono"], "monospace")
    readonly property int fontXs: 11
    readonly property int fontSm: 12
    readonly property int fontMd: 13
    readonly property int fontLg: 15
    readonly property int fontXl: 20
    readonly property int fontClock: 72

    // ---- Motion ----
    readonly property int durFast: 140
    readonly property int durNormal: 170
    readonly property int durSlow: 260
    readonly property int easing: Easing.OutCubic
}
