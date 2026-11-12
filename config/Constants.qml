pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string appName: "NIRI MONOCHROME"
    readonly property string tagline: "Designed for Focus."
    readonly property string version: "2.0.0"
    readonly property string configName: "niri-monochrome"
    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/niri-monochrome"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/niri-monochrome"
    readonly property string niriConfigDir: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/niri"
    readonly property string defaultWallpaperDir: home + "/Pictures/Wallpapers"
    // Layer-shell namespaces (used by niri layer-rules).
    readonly property string nsBar: "nm-bar"
    readonly property string nsDock: "nm-dock"
    readonly property string nsOverlay: "nm-overlay"
    readonly property string nsToast: "nm-toast"
    readonly property string nsWallpaper: "nm-wallpaper"
    readonly property string nsTrigger: "nm-dock-trigger"
}
