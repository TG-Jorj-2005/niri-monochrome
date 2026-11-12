pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Per-monitor wallpaper collections with automatic rotation.
// State per monitor key: { current, order:[...], pos, paused, nextAt, pinned }
Singleton {
    id: wp

    readonly property var imageExt: ["png", "jpg", "jpeg", "webp", "bmp", "avif", "jxl", "tif", "tiff"]
    property var collections: ({})      // key -> [absolute paths]
    property var scanning: ({})
    signal collectionChanged(string key)
    signal wallpaperChanged(string key, string path)

    function loadFailed(key, path) {
        const list = collections[key] || []
        if (list.indexOf(path) < 0) return
        collections = Object.assign({}, collections, { [key]: list.filter(p => p !== path) })
        ensureOrder(key)
        collectionChanged(key)
    }
    function profileFor(key) { return MonitorProfiles.profile(key).wallpaper }
    function state(key) { return StateStore.get(["wallpaper", key], {}) }
    function setState(key, patch) { StateStore.set(["wallpaper", key], Object.assign({}, state(key), patch)) }

    function current(key) {
        const s = state(key)
        if (s.current && (collections[key] || []).indexOf(s.current) !== -1) return s.current
        const list = collections[key] || []
        return list.length > 0 ? list[0] : ""
    }
    function paused(key) { return !!state(key).paused }
    function pinned(key) { return !!state(key).pinned }

    // ---- Directory scanning (async, no shell) ----
    function scan(key) {
        const dir = profileFor(key).directory
        if (!dir) return
        if (scanning[key]) return
        scanning = Object.assign({}, scanning, { [key]: true })
        const args = ["find", "-L", dir, "-maxdepth", "1", "-type", "f", "("]
        imageExt.forEach((e, i) => { if (i > 0) args.push("-o"); args.push("-iname", "*." + e) })
        args.push(")", "-print0")
        const p = scanner.createObject(wp, { key: key, command: args })
        p.running = true
    }
    Component {
        id: scanner
        Process {
            property string key
            stdout: StdioCollector { id: col }
            onExited: code => {
                const files = col.text.split("\0").filter(f => f.length > 0).sort()
                wp.scanning = Object.assign({}, wp.scanning, { [key]: false })
                wp.collections = Object.assign({}, wp.collections, { [key]: files })
                if (code !== 0 && files.length === 0) Log.warn("WallpaperService", "scan failed for", key)
                wp.ensureOrder(key)
                wp.collectionChanged(key)
                destroy()
            }
        }
    }
    function rescanAll() { for (const k in collections) scan(k) }

    // ---- Order / rotation ----
    function shuffled(list) {
        const a = list.slice()
        for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); const t = a[i]; a[i] = a[j]; a[j] = t }
        return a
    }
    function ensureOrder(key) {
        const list = collections[key] || []
        const s = state(key)
        const prof = profileFor(key)
        let order = Array.isArray(s.order) ? s.order.filter(p => list.indexOf(p) !== -1) : []
        const missing = list.filter(p => order.indexOf(p) === -1)
        if (missing.length > 0) order = order.concat(prof.shuffle ? shuffled(missing) : missing)
        if (!prof.shuffle) order = list.slice()
        let cur = s.current
        if (!cur || list.indexOf(cur) === -1) cur = order.length > 0 ? order[0] : ""
        const patch = { order: order, current: cur }
        if (!s.nextAt) patch.nextAt = Date.now() + prof.interval * 60000
        setState(key, patch)
        if (cur && cur !== s.current) wallpaperChanged(key, cur)
    }
    function advance(key, dir) {
        const list = collections[key] || []
        if (list.length === 0) return
        const s = state(key)
        const prof = profileFor(key)
        let order = Array.isArray(s.order) && s.order.length === list.length ? s.order : list.slice()
        let idx = order.indexOf(s.current)
        if (list.length === 1) { setState(key, { current: list[0], nextAt: Date.now() + prof.interval * 60000 }); return }
        idx = idx === -1 ? 0 : idx + dir
        if (idx >= order.length) {
            // Reshuffle but avoid repeating the last image immediately.
            if (prof.shuffle) { let n = shuffled(order); if (n[0] === s.current) { n.push(n.shift()) } order = n }
            idx = 0
        } else if (idx < 0) idx = order.length - 1
        const next = order[idx]
        setState(key, { order: order, current: next, nextAt: Date.now() + prof.interval * 60000 })
        wallpaperChanged(key, next)
    }
    function next(key) { advance(key, 1) }
    function previous(key) { advance(key, -1) }
    function setPaused(key, p) { setState(key, { paused: !!p, nextAt: Date.now() + profileFor(key).interval * 60000 }) }
    function togglePaused(key) { setPaused(key, !paused(key)) }
    // Permanent selection: pin an image (rotation stops until unpinned).
    function select(key, path, pin) {
        if (!path) return
        setState(key, { current: path, pinned: !!pin, paused: !!pin || paused(key), nextAt: Date.now() + profileFor(key).interval * 60000 })
        wallpaperChanged(key, path)
    }
    function unpin(key) { setState(key, { pinned: false, paused: false }) }

    // One clock for all monitors: checks wall-clock deadlines (suspend-safe, no burst after resume).
    Timer {
        interval: 30000; repeat: true; running: true
        onTriggered: {
            const now = Date.now()
            for (const key in wp.collections) {
                const s = wp.state(key)
                const prof = wp.profileFor(key)
                if (!prof.enabled || s.paused || s.pinned) continue
                if ((wp.collections[key] || []).length < 2) continue
                if (!s.nextAt || now >= s.nextAt) {
                    if (s.nextAt && now - s.nextAt > prof.interval * 60000 * 2) wp.setState(key, { nextAt: now + prof.interval * 60000 }) // resumed after a long sleep: just reschedule
                    else wp.advance(key, 1)
                }
            }
        }
    }

    function nextAllFocused() { const s = MonitorService.focusedScreen(); if (s) next(MonitorService.keyFor(s)) }
    function remainingMinutes(key) { const s = state(key); return s.nextAt ? Math.max(0, Math.round((s.nextAt - Date.now()) / 60000)) : 0 }
    function fileName(path) { return path ? path.split("/").pop() : "" }
}
