pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Backlight via brightnessctl. Raw values (max 800 on this hardware) are kept; UI uses the 0..1 fraction.
// status: initializing | ready | unavailable
Singleton {
    id: br
    property string status: "initializing"
    readonly property bool available: status === "ready"
    property string device: ""
    property int max: 0
    property int raw: 0
    readonly property real brightness: max > 0 ? raw / max : 0
    readonly property int percent: Math.round(brightness * 100)
    signal changed(real brightness, bool external)

    Process {
        id: list
        command: ["brightnessctl", "-m", "-l", "-c", "backlight"]
        running: true
        stdout: StdioCollector { onStreamFinished: br.parseList(text) }
        onExited: code => { if (code !== 0) { br.status = "unavailable"; Log.warn("Brightness", "brightnessctl not usable (exit", code + ")") } }
    }
    function parseList(text) {
        const pref = UserConfig.data.system.brightnessDevice
        let chosen = null
        for (const line of text.split("\n")) {
            const f = line.split(",")      // device,class,current,percent,max
            if (f.length < 5 || f[1] !== "backlight") continue
            const dev = { name: f[0], cur: parseInt(f[2]), max: parseInt(f[4]) }
            if (!chosen || dev.name === pref) chosen = dev
        }
        if (chosen && chosen.max > 0) { device = chosen.name; raw = chosen.cur; max = chosen.max; status = "ready" }
        else { status = "unavailable"; Log.info("Brightness", "no backlight device") }
    }
    function refresh() { if (!list.running) list.running = true }

    // Writes are coalesced: at most one brightnessctl process at a time, latest value wins.
    property int pendingPct: -1
    function set(frac) {
        if (!available || !isFinite(frac)) return
        const pct = Math.round(Math.max(1, Math.min(100, frac * 100)))
        raw = Math.round(pct / 100 * max)
        pendingPct = pct
        changed(brightness, false)
        if (!setter.running) apply()
    }
    function step(delta) { set(brightness + delta) }
    function apply() {
        if (pendingPct < 0) return
        setter.command = ["brightnessctl", "-q", "-d", device, "set", pendingPct + "%"]
        pendingPct = -1
        setter.running = true
    }
    Process { id: setter; onExited: code => { if (code !== 0) { Log.warn("Brightness", "brightnessctl set failed", code); br.refresh() }; if (br.pendingPct >= 0) br.apply() } }

    // External changes (Fn keys through other tools): sysfs has no inotify, so poll only while watched.
    FileView {
        id: watch
        path: br.device !== "" ? "/sys/class/backlight/" + br.device + "/brightness" : ""
        printErrors: false
        onLoaded: { const v = parseInt(text()); if (!isNaN(v) && !setter.running && br.pendingPct < 0 && v !== br.raw) { br.raw = v; br.changed(br.brightness, true) } }
    }
    property int watchers: 0
    Timer { interval: 1000; running: br.available && br.watchers > 0; repeat: true; onTriggered: watch.reload() }
}
