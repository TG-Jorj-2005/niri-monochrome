pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// UPower display device + power profiles (when power-profiles-daemon exists).
Singleton {
    id: bat
    readonly property var device: UPower.displayDevice
    readonly property bool present: device && device.ready && device.isLaptopBattery && device.isPresent
    readonly property real percentage: device ? device.percentage * 100 : 0
    readonly property int state: device ? device.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0
    readonly property bool low: present && !charging && percentage <= 15

    readonly property string status: !device ? "initializing" : (device.ready ? "ready" : "initializing")

    // Power profiles: tuned-ppd or power-profiles-daemon expose net.hadess.PowerProfiles /
    // org.freedesktop.UPower.PowerProfiles on the system bus; Quickshell's PowerProfiles reads them.
    property bool modernProfiles: false
    property bool legacyProfiles: false
    readonly property bool profilesAvailable: modernProfiles || legacyProfiles
    function refreshProfiles() { if (!probe.running) probe.running = true; if (!probe2.running) probe2.running = true; if (!backendProbe.running) backendProbe.running = true }
    property string profilesBackend: ""
    readonly property int profile: PowerProfiles.profile
    function setProfile(p) {
        if ([PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance].indexOf(p) < 0 || (p === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)) return
        if (!profilesAvailable) { Log.warn("Battery", "power profile requested but no backend"); return }
        PowerProfiles.profile = p      // the property only changes once the daemon confirms
    }
    Process { id: backendProbe; command: ["systemctl", "is-active", "tuned-ppd", "power-profiles-daemon"]; running: true
        stdout: StdioCollector { onStreamFinished: { const v = text.trim().split("\n"); bat.profilesBackend = v[0] === "active" ? "tuned-ppd" : v[1] === "active" ? "power-profiles-daemon" : "" } } }

    // ---- Low / critical warnings (hysteresis: one notification per crossing, reset when charging) ----
    property int warnedLevel: 0        // 0 none, 1 low, 2 critical
    readonly property int lowPct: UserConfig.data.system.batteryLowPercent
    readonly property int criticalPct: UserConfig.data.system.batteryCriticalPercent
    function checkWarnings() {
        if (!UserConfig.data.system.batteryWarnings || !present) return
        if (!onBattery || charging || full) { warnedLevel = 0; return }
        if (percentage <= criticalPct && warnedLevel < 2) { warnedLevel = 2; notify("critical", "Battery critical", Math.round(percentage) + "% remaining — plug in now") }
        else if (percentage <= lowPct && warnedLevel < 1) { warnedLevel = 1; notify("normal", "Battery low", Math.round(percentage) + "% remaining") }
    }
    onPercentageChanged: checkWarnings()
    onChargingChanged: checkWarnings()
    onOnBatteryChanged: checkWarnings()
    Component { id: notifier; Process { onExited: destroy() } }
    function notify(urgency, title, body) {
        const p = notifier.createObject(bat, { command: ["notify-send", "-a", "NIRI MONOCHROME", "-u", urgency, "-i", "battery-caution", title, body] })
        p.running = true
        Log.info("Battery", title, body)
    }
    Process {
        id: probe
        command: ["busctl", "--system", "--no-pager", "--timeout=2", "status", "org.freedesktop.UPower.PowerProfiles"]
        running: true
        onExited: code => { bat.modernProfiles = code === 0 }
    }
    Process {
        id: probe2
        command: ["busctl", "--system", "--no-pager", "--timeout=2", "status", "net.hadess.PowerProfiles"]
        running: true
        onExited: code => { bat.legacyProfiles = code === 0 }
    }

    function iconName() {
        if (!present) return "power-plug"
        if (charging) return "battery-charging"
        if (percentage > 87) return "battery-full"
        if (percentage > 60) return "battery-high"
        if (percentage > 35) return "battery-medium"
        if (percentage > 10) return "battery-low"
        return "battery-empty"
    }
    function stateText() {
        if (!present) return "AC power"
        if (full) return "Fully charged"
        if (charging) return "Charging" + (timeToFull > 0 ? " · " + fmt(timeToFull) + " to full" : "")
        if (!onBattery) return "Connected to AC"
        if (timeToEmpty > 0) return "Discharging · " + fmt(timeToEmpty) + " left"
        return "Discharging"
    }
    function fmt(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    function profileName(p) {
        switch (p) { case PowerProfile.PowerSaver: return "Power saver"; case PowerProfile.Performance: return "Performance"; default: return "Balanced" }
    }
}
