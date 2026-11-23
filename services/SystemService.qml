pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Power actions (systemd/logind), session helpers, D-Bus ownership probes. Brightness lives in BrightnessService.
Singleton {
    id: sys

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
    // Full name (GECOS) and AccountsService avatar, used by the lock screen.
    property string realName: ""
    readonly property string avatarPath: "/var/lib/AccountsService/icons/" + user
    Process { command: ["getent", "passwd", sys.user]; running: true
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split(":"); sys.realName = f.length > 4 ? f[4].split(",")[0].trim() : "" } } }

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
