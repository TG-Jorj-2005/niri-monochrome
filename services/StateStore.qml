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
        for (const p of path.split(".")) { if (cur === undefined || cur === null || !(p in cur)) return fallback; cur = cur[p] }
        return cur
    }
    function set(path, value) {
        const parts = path.split(".")
        const next = JSON.parse(JSON.stringify(data))
        let cur = next
        for (let i = 0; i < parts.length - 1; i++) { if (typeof cur[parts[i]] !== "object" || cur[parts[i]] === null) cur[parts[i]] = {}; cur = cur[parts[i]] }
        cur[parts[parts.length - 1]] = JSON.parse(JSON.stringify(value))
        data = next
        save()
    }

    FileView {
        id: file
        path: store.path
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { const p = JSON.parse(text()); if (p && typeof p === "object") store.data = Object.assign({ wallpaper: {}, recentApps: [] }, p) }
            catch (e) { console.warn("[StateStore] state.json invalid, starting fresh") }
            store.loaded = true
        }
        onLoadFailed: { store.loaded = true }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: mkdir.running = true }
    function save() { saveTimer.restart() }
    Process { id: mkdir; command: ["mkdir", "-p", Constants.stateDir]; onExited: file.setText(JSON.stringify(store.data, null, 1) + "\n") }
}
