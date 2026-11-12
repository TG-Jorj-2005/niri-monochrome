pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Lightweight runtime state persisted at ~/.local/state/niri-monochrome/state.json
// (wallpaper positions, recent applications, dock keyboard state, ...).
Singleton {
    id: store
    readonly property string path: Constants.stateDir + "/state.json"
    property var data: ({ wallpaper: {}, recentApps: [], version: 1 })
    property bool loaded: false

    function get(path, fallback) {
        let cur = data
        for (const p of (Array.isArray(path) ? path : path.split("."))) { if (cur === undefined || cur === null || typeof cur !== "object" || !(p in cur)) return fallback; cur = cur[p] }
        return cur
    }
    function set(path, value) {
        const parts = (Array.isArray(path) ? path : path.split("."))
        const next = JSON.parse(JSON.stringify(data))
        let cur = next
        for (let i = 0; i < parts.length - 1; i++) { if (typeof cur[parts[i]] !== "object" || cur[parts[i]] === null) cur[parts[i]] = {}; cur = cur[parts[i]] }
        cur[parts[parts.length - 1]] = JSON.parse(JSON.stringify(value))
        data = next
        save()
    }

    function normalize(p) {
        const out = p && typeof p === "object" && !Array.isArray(p) ? p : {}
        if (!out.wallpaper || typeof out.wallpaper !== "object" || Array.isArray(out.wallpaper)) out.wallpaper = {}
        for (const key of Object.keys(out.wallpaper)) {
            const s = out.wallpaper[key]
            if (!s || typeof s !== "object" || Array.isArray(s)) { delete out.wallpaper[key]; continue }
            if (!Array.isArray(s.order)) s.order = []
            s.order = s.order.filter(v => typeof v === "string")
            if (typeof s.current !== "string") s.current = ""
        }
        out.recentApps = Array.isArray(out.recentApps) ? out.recentApps.filter(v => typeof v === "string").slice(0, 50) : []
        return out
    }
    FileView {
        id: file
        path: store.path
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { const p = JSON.parse(text()); store.data = store.normalize(p) }
            catch (e) { Log.warn("StateStore", "state.json invalid, starting fresh") }
            store.loaded = true
        }
        onLoadFailed: { store.loaded = true }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: mkdir.running = true }
    function save() { saveTimer.restart() }
    Process { id: mkdir; command: ["mkdir", "-p", Constants.stateDir]; onExited: file.setText(JSON.stringify(store.data, null, 1) + "\n") }
}
