pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.services

// Monitor identity + per-monitor profile resolution.
// Stable key = "make|model|serial" from niri outputs (falls back to the connector name).
Singleton {
    id: mon

    readonly property var screens: Quickshell.screens
    property var keys: ({})          // connector -> stable key
    // true once niri reported its outputs (or after a fallback timeout) so keys are stable.
    property bool ready: false
    Timer { id: readyFallback; interval: 4000; running: true; onTriggered: { if (!mon.ready) { console.warn("[MonitorService] niri outputs not received, using connector-based keys"); mon.ready = true } } }

    function keyFor(screen) {
        if (!screen) return "default"
        return keys[screen.name] || screen.name
    }
    function keyForName(name) { return keys[name] || name }

    function rebuild() {
        const out = {}
        const o = NiriService.outputs || {}
        for (const name in o) {
            const info = o[name]
            const parts = [info.make || "", info.model || "", info.serial || ""].map(s => String(s).replace(/[|]/g, "_"))
            out[name] = parts.join("|").replace(/^\|+|\|+$/g, "") || name
        }
        for (const s of Quickshell.screens) if (!out[s.name]) out[s.name] = (s.model ? (s.model + (s.serialNumber ? "|" + s.serialNumber : "")) : s.name)
        keys = out

    }

    Connections { target: NiriService; function onOutputsUpdated() { mon.rebuild(); mon.ready = true } }
    Connections { target: Quickshell; function onScreensChanged() { NiriService.refreshOutputs(); mon.rebuild() } }
    Component.onCompleted: rebuild()

    // Human-readable label for Settings.
    function label(screen) {
        const o = (NiriService.outputs || {})[screen.name]
        if (o) return screen.name + " · " + [o.make, o.model].filter(x => x).join(" ") + " · " + o.logical.width + "×" + o.logical.height + " @" + o.logical.scale + "x"
        return screen.name + " · " + screen.width + "×" + screen.height
    }

    // All monitor keys known from config + connected screens (for Settings).
    function knownKeys() {
        const set = {}
        for (const s of Quickshell.screens) set[keyFor(s)] = true
        const m = UserConfig.data.monitors || {}
        for (const k in m) set[k] = true
        return Object.keys(set)
    }
    function isConnected(key) { return Quickshell.screens.some(s => keyFor(s) === key) }

    function profile(screen) { return MonitorProfiles.profile(keyFor(screen)) }
    function screenByName(name) { return Quickshell.screens.find(s => s.name === name) || null }
    function focusedScreen() {
        return screenByName(NiriService.focusedOutput) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    }
}
