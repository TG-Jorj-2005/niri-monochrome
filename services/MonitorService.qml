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
    Timer { id: readyFallback; interval: 4000; running: true; onTriggered: { if (!mon.ready) { Log.warn("MonitorService", "niri outputs not received, using connector-based keys"); mon.ready = true } } }

    function keyFor(screen) {
        if (!screen) return "default"
        return keys[screen.name] || screen.name
    }
    function keyForName(name) { return keys[name] || name }

    // Remember ambiguous EDIDs for this lifetime so unplugging one twin does not rename the other.
    property var ambiguous: ({})
    function resolveKeys(outputs, screens) {
        const result = {}, counts = {}, bases = {}, duplicate = Object.assign({}, ambiguous)
        for (const s of screens) {
            const info = outputs[s.name] || {}
            const parts = [info.make || "", info.model || "", info.serial || ""].map(v => String(v).replace(/\|/g, "_"))
            const base = parts.join("|").replace(/^\|+|\|+$/g, "")
            bases[s.name] = { base: base, serial: !!info.serial }
            if (base) counts[base] = (counts[base] || 0) + 1
        }
        for (const base of Object.keys(counts)) if (counts[base] > 1) duplicate[base] = true
        for (const s of screens) {
            const b = bases[s.name]
            result[s.name] = !b.base ? s.name : (!b.serial || duplicate[b.base]) ? b.base + "|" + s.name : b.base
        }
        ambiguous = duplicate
        return result
    }
    function rebuild() {
        keys = resolveKeys(NiriService.outputs || {}, Quickshell.screens)

    }

    Connections { target: NiriService; function onOutputsUpdated() { mon.rebuild(); mon.ready = true } }
    Connections { target: Quickshell; function onScreensChanged() { NiriService.refreshOutputs(); mon.rebuild() } }
    Component.onCompleted: rebuild()

    // Human-readable label for Settings.
    function label(screen) {
        const o = (NiriService.outputs || {})[screen.name]
        if (o && o.logical) return screen.name + " · " + [o.make, o.model].filter(x => x).join(" ") + " · " + o.logical.width + "×" + o.logical.height + " @" + o.logical.scale + "x"
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
