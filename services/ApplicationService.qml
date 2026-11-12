pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Installed desktop applications (DesktopEntries) + fuzzy search + launch + recents.
Singleton {
    id: apps

    readonly property var entries: DesktopEntries.applications.values
    property var visible: []        // entries not marked NoDisplay, sorted by name
    property string lastError: ""

    function rebuild() {
        const list = []
        for (const e of DesktopEntries.applications.values) {
            if (!e || e.noDisplay) continue
            list.push(e)
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        visible = list
    }
    Connections { target: DesktopEntries; function onApplicationsChanged() { apps.rebuild() } }
    Component.onCompleted: rebuild()

    function byId(id) {
        if (!id) return null
        const direct = DesktopEntries.byId(id) || DesktopEntries.byId(id.replace(/\.desktop$/, ""))
        if (direct) return direct
        return DesktopEntries.heuristicLookup(id.replace(/\.desktop$/, ""))
    }
    function entryId(e) { return e ? e.id : "" }

    // Lookup for a niri app_id (wayland app id) → DesktopEntry (may be null).
    function forAppId(appId) {
        if (!appId) return null
        return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId)
    }

    // ---- Fuzzy matching: subsequence match with contiguity/prefix bonuses ----
    function score(query, text) {
        if (!query) return 1
        const q = query.toLowerCase(), t = text.toLowerCase()
        if (t === q) return 1000
        if (t.startsWith(q)) return 800 - t.length
        const idx = t.indexOf(q)
        if (idx >= 0) return 600 - idx - (t.length - q.length) * 0.1
        // subsequence
        let ti = 0, s = 0, streak = 0
        for (let qi = 0; qi < q.length; qi++) {
            const pos = t.indexOf(q[qi], ti)
            if (pos < 0) return 0
            streak = (pos === ti) ? streak + 1 : 0
            s += 10 + streak * 5 - (pos - ti) * 0.5
            if (pos === 0 || t[pos - 1] === " " || t[pos - 1] === "-") s += 8
            ti = pos + 1
        }
        return Math.max(1, s)
    }

    function search(query, limit) {
        const q = (query || "").trim()
        const out = []
        for (const e of visible) {
            let s = score(q, e.name) * 1.0
            if (s === 0 && e.genericName) s = score(q, e.genericName) * 0.7
            if (s === 0 && e.comment && UserConfig.data.launcher.showDescriptions) s = score(q, e.comment) * 0.5
            if (s === 0 && e.keywords) for (const k of e.keywords) { const ks = score(q, k) * 0.6; if (ks > s) s = ks }
            if (s > 0) out.push({ entry: e, score: s })
        }
        if (q === "") {
            // No query: recents first, then alphabetical.
            const recent = StateStore.get("recentApps", [])
            out.sort((a, b) => {
                const ra = recent.indexOf(a.entry.id), rb = recent.indexOf(b.entry.id)
                if (ra !== -1 || rb !== -1) return (ra === -1 ? 999 : ra) - (rb === -1 ? 999 : rb)
                return a.entry.name.localeCompare(b.entry.name)
            })
        } else out.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
        return out.slice(0, limit || 8).map(x => x.entry)
    }

    // ---- Launch ----
    signal launchFailed(string name, string reason)
    signal launched(string name)

    function launch(entry) {
        if (!entry) { launchFailed("?", "No such application"); return false }
        const cmd = entry.command
        if (!cmd || cmd.length === 0) { launchFailed(entry.name, "Desktop entry has no Exec command"); return false }
        const exe = cmd[0]
        // Check the executable exists before pretending it started.
        const p = checker.createObject(apps, { entry: entry, command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1", "nm-check", exe] })
        p.running = true
        return true
    }
    Component {
        id: checker
        Process {
            property var entry
            onExited: code => {
                if (code === 0) {
                    try {
                        if (entry.runInTerminal) {
                            Quickshell.execDetached({ command: [UserConfig.data.launcher.terminal, "-e"].concat(entry.command) })
                        } else entry.execute()
                        apps.remember(entry)
                        apps.launched(entry.name)
                    } catch (e) { apps.launchFailed(entry.name, String(e)) }
                } else apps.launchFailed(entry.name, "Executable not found: " + entry.command[0])
                destroy()
            }
        }
    }

    function remember(entry) {
        if (!UserConfig.data.launcher.rememberRecent) return
        const limit = UserConfig.data.launcher.recentLimit
        let r = StateStore.get("recentApps", []).filter(id => id !== entry.id)
        r.unshift(entry.id)
        StateStore.set("recentApps", r.slice(0, limit))
    }
    function clearRecent() { StateStore.set("recentApps", []) }
}
