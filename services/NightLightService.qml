pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Night light: the shell owns a single wlsunset process while enabled (config `nightLight`).
// status: unavailable (no wlsunset) | off | on | error
Singleton {
    id: nl
    readonly property var cfg: UserConfig.data.nightLight
    property bool installed: false
    property string status: "off"
    readonly property bool enabled: cfg.enabled
    readonly property bool available: installed

    Process { command: ["sh", "-c", "command -v wlsunset >/dev/null"]; running: true
        onExited: code => { nl.installed = (code === 0); if (!nl.installed) nl.status = "unavailable"; else nl.sync() } }

    Process {
        id: proc
        command: ["wlsunset", "-l", String(nl.cfg.latitude), "-L", String(nl.cfg.longitude), "-t", String(nl.cfg.tempLow), "-T", String(nl.cfg.tempHigh)]
        onStarted: nl.status = "on"
        onExited: (code) => { if (nl.enabled && code !== 0) { nl.status = "error"; Log.warn("NightLight", "wlsunset exited", code) } else nl.status = "off" }
    }
    function sync() {
        if (!installed) return
        if (enabled && !proc.running) proc.running = true
        else if (!enabled && proc.running) proc.running = false
    }
    onEnabledChanged: sync()
    onCfgChanged: if (installed && enabled && proc.running) { proc.running = false; restart.restart() }
    Timer { id: restart; interval: 300; onTriggered: nl.sync() }
    function toggle() { UserConfig.set("nightLight.enabled", !enabled) }
}
