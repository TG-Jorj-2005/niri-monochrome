pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Resolves the effective per-monitor profile: global defaults + monitor overrides.
// Sections that can be overridden per monitor: bar, dock, wallpaper.
Singleton {
    id: profiles

    readonly property var overridable: ["bar", "dock", "wallpaper"]

    function overridesFor(key) {
        const m = UserConfig.data.monitors || {}
        return m[key] || {}
    }

    // Effective profile object for a monitor key.
    function profile(key) {
        const base = { bar: UserConfig.data.bar, dock: UserConfig.data.dock, wallpaper: UserConfig.data.wallpaper }
        if (Object.keys(overridesFor(key)).length === 0) return base
        const checked = UserConfig.validate(UserConfig.merge(UserConfig.data, overridesFor(key)))
        return { bar: checked.bar, dock: checked.dock, wallpaper: checked.wallpaper }
    }

    function section(key, name) { return profile(key)[name] }

    // Set an override "bar.height" for a monitor.
    function setOverride(key, path, value) {
        UserConfig.set(["monitors", key].concat(path.split(".")), value)
    }

    function clearOverride(key, path) {
        const next = UserConfig.deepClone(UserConfig.data.monitors || {})
        const parts = path.split(".")
        let cur = next[key]
        if (!cur) return
        for (let i = 0; i < parts.length - 1; i++) { cur = cur[parts[i]]; if (!cur) return }
        delete cur[parts[parts.length - 1]]
        UserConfig.set("monitors", next)
    }

    function clearMonitor(key) {
        const next = UserConfig.deepClone(UserConfig.data.monitors || {})
        delete next[key]
        UserConfig.set("monitors", next)
    }

    function hasOverride(key, path) {
        let cur = overridesFor(key)
        for (const p of path.split(".")) { if (!cur || !(p in cur)) return false; cur = cur[p] }
        return true
    }
}
