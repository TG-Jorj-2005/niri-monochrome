pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Brightness (brightnessctl), power actions (systemd/logind), session helpers.
Singleton {
    id: sys

    // ---- Brightness ----
    property bool brightnessAvailable: false
    property string brightnessDevice: ""
    property int brightnessMax: 0
    property int brightnessRaw: 0
    readonly property real brightness: brightnessMax > 0 ? brightnessRaw / brightnessMax : 0
    property bool _setting: false

    Process {
        id: brList
        command: ["brightnessctl", "-m", "-l", "-c", "backlight"]
        running: true
        stdout: StdioCollector { onStreamFinished: sys.parseList(text) }
        onExited: code => { if (code !== 0) sys.brightnessAvailable = false }
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
        if (chosen) { brightnessDevice = chosen.name; brightnessRaw = chosen.cur; brightnessMax = chosen.max; brightnessAvailable = chosen.max > 0 }
        else brightnessAvailable = false
    }
    function refreshBrightness() { if (!brList.running) brList.running = true }
    function setBrightness(frac) {
        if (!brightnessAvailable) return
        const pct = Math.round(Math.max(1, Math.min(100, frac * 100)))
        brightnessRaw = Math.round(pct / 100 * brightnessMax)
        pendingPct = pct
        if (!brSet.running) applyBrightness()
    }
    property int pendingPct: -1
    function applyBrightness() {
        if (pendingPct < 0) return
        brSet.command = ["brightnessctl", "-q", "-d", brightnessDevice, "set", pendingPct + "%"]
        pendingPct = -1
        brSet.running = true
    }
    Process { id: brSet; onExited: code => { if (code !== 0) console.warn("[SystemService] brightnessctl failed", code); if (sys.pendingPct >= 0) sys.applyBrightness() } }
    // Watch sysfs for external changes (Fn keys) while something displays brightness.
    FileView {
        id: brWatch
        path: sys.brightnessDevice !== "" ? "/sys/class/backlight/" + sys.brightnessDevice + "/brightness" : ""
        watchChanges: sys.brightnessDevice !== ""
        printErrors: false
        onFileChanged: reload()
        onLoaded: { const v = parseInt(text()); if (!isNaN(v) && !brSet.running && sys.pendingPct < 0) sys.brightnessRaw = v }
    }
    // Poll sysfs only while something displays brightness (the control center); sysfs has no inotify.
    property int brightnessWatchers: 0
    Timer { interval: 2000; running: sys.brightnessAvailable && sys.brightnessWatchers > 0; repeat: true; onTriggered: brWatch.reload() }

    // ---- Power ----
    signal actionFailed(string action, string message)
    function run(name, argv) {
        if (!Array.isArray(argv) || argv.length === 0) { actionFailed(name, "No command configured"); return }
        const p = runner.createObject(sys, { name: name, command: argv })
        p.running = true
    }
    Component {
        id: runner
        Process {
            property string name
            stderr: StdioCollector { id: errc }
            onExited: code => { if (code !== 0) sys.actionFailed(name, (errc.text || ("exit " + code)).trim()); destroy() }
        }
    }
    function suspend()  { run("suspend",  UserConfig.data.system.suspendCommand) }
    function reboot()   { run("reboot",   UserConfig.data.system.rebootCommand) }
    function shutdown() { run("shutdown", UserConfig.data.system.shutdownCommand) }
    function logout()   { run("logout",   UserConfig.data.system.logoutCommand) }

    // ---- Misc ----
    readonly property string user: Quickshell.env("USER") || "user"
    property string hostname: ""
    Process { command: ["hostname"]; running: true; stdout: StdioCollector { onStreamFinished: sys.hostname = text.trim() } }

    // Notification daemon owner (to detect a competing server).
    property string notificationOwnerPid: ""
    property bool notificationOwnedByUs: false
    property bool notificationOwnedByOther: false
    property bool notificationProbed: false      // first ownership probe finished
    Process {
        id: ownerProbe
        command: ["busctl", "--user", "--no-pager", "--timeout=2", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"]
        stdout: StdioCollector { onStreamFinished: {
            const m = text.match(/u\s+(\d+)/)
            sys.notificationOwnerPid = m ? m[1] : ""
            sys.notificationOwnedByUs = m && Number(m[1]) === Quickshell.processId
            sys.notificationOwnedByOther = m && Number(m[1]) !== Quickshell.processId
        } }
        onExited: code => { if (code !== 0) { sys.notificationOwnerPid = ""; sys.notificationOwnedByUs = false; sys.notificationOwnedByOther = false }; sys.notificationProbed = true }
    }
    function probeNotificationOwner() { if (!ownerProbe.running) ownerProbe.running = true }
    Timer { interval: 1500; running: true; onTriggered: sys.probeNotificationOwner() }
}
