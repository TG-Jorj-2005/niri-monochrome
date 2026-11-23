pragma Singleton
import QtQuick
import Quickshell

// Centralized design tokens for NIRI MONOCHROME.
// Everything visual (colors, radii, spacing, fonts, motion) comes from here.
Singleton {
    id: theme

    // ---- Palette ----
    readonly property color background:  "#111214"
    readonly property color surface2:    "#1B1D1F"
    readonly property color surface: UserConfig.data.appearance.glassEnabled
        ? Qt.rgba(0, 0, 0, UserConfig.data.appearance.panelOpacity)
        : surface2
    readonly property color elevated:    "#25282A"
    readonly property color border:      "#303336"
    readonly property color silverMuted: "#777D80"
    readonly property color silver:      "#BDBDBD"
    readonly property color silverBright:"#D6D6D6"
    readonly property color text:        "#DADDE0"
    readonly property color textSecondary:"#9BA1A4"
    readonly property color textDisabled:"#777D80"
    readonly property color accent: UserConfig.data.appearance.accentColor
    // Use the palette’s hover color for the default accent and derive it for overrides.
    readonly property color accentHover: Qt.colorEqual(accent, UserConfig.defaults.appearance.accentColor)
        ? "#9EB3B8" : Qt.tint(accent, Qt.rgba(1, 1, 1, 0.25))
    readonly property color accentPressed: Qt.tint(accent, Qt.rgba(0, 0, 0, 0.2))
    readonly property color accentSubtle: Qt.rgba(accent.r, accent.g, accent.b, 32 / 255)

    function accentFill(hovered, pressed) {
        return pressed ? accentPressed : hovered ? accentHover : accent
    }

    function textOnAccent(fill) {
        const linear = c => c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
        const luminance = 0.2126 * linear(fill.r) + 0.7152 * linear(fill.g) + 0.0722 * linear(fill.b)
        return luminance > 0.179 ? "black" : "white"
    }

    // Derived helpers
    readonly property color inverse:    "#111214"          // text drawn on a silver surface
    readonly property color hover:       elevated
    readonly property color pressed:     background
    readonly property color scrim:       Qt.rgba(0, 0, 0, 0.55)
    readonly property color shadow:      Qt.rgba(0, 0, 0, 0.6)
    readonly property color danger:      "#D6D6D6"          // monochrome: emphasis, not red

    // ---- Geometry ----
    readonly property int grid: 8
    readonly property int radiusBar: 10
    readonly property int radiusPanel: UserConfig.data.appearance.panelRadius
    readonly property int radiusControl: 5
    readonly property int borderWidth: 1

    // ---- Typography ----
    readonly property var _families: Qt.fontFamilies()
    function pick(list, fallback) {
        for (const f of list) if (_families.indexOf(f) !== -1) return f
        return fallback
    }
    readonly property string fontSans: pick(["Inter", "Geist", "Geist Sans", "Adwaita Sans", "Noto Sans", "Cantarell"], "sans-serif")
    readonly property string fontMono: pick(["JetBrains Mono", "Adwaita Mono", "Noto Sans Mono", "DejaVu Sans Mono"], "monospace")
    readonly property int fontXs: 11
    readonly property int fontSm: 12
    readonly property int fontMd: 13
    readonly property int fontLg: 15
    readonly property int fontXl: 20
    readonly property int fontClock: 72

    // ---- Motion ----
    readonly property bool motionEnabled: UserConfig.data.appearance.animations && !UserConfig.data.appearance.reduceMotion && UserConfig.data.appearance.animationIntensity > 0
    readonly property real motionIntensity: motionEnabled ? UserConfig.data.appearance.animationIntensity : 0
    readonly property int durFast: motionEnabled ? 140 : 0
    readonly property int durNormal: motionEnabled ? 190 : 0
    readonly property int durSlow: motionEnabled ? 240 : 0
    readonly property int easing: Easing.OutCubic
}
