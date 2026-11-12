pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.services

// Lock entry point shared by the power menu, control center and IPC.
// Until `security.useShellLock` is enabled, locking delegates to the trusted
// system locker (swaylock), exactly like Super+Alt+L, lid-close and swayidle.
// `lockShell()` always uses the shell's WlSessionLock + PAM screen (Settings → Security → Test).
Singleton {
    id: ls
    property bool locked: false
    property string password: ""      // in-memory only, cleared on unlock/escape
    property bool secure: false       // compositor confirmed the session is locked
    readonly property bool useShellLock: UserConfig.data.security.useShellLock
    readonly property var systemLockCommand: UserConfig.data.security.systemLockCommand || ["swaylock", "-f"]
    signal lockRequested()

    function lock() {
        if (useShellLock) lockShell()
        else SystemService.run("lock", systemLockCommand)
    }
    function lockShell() {
        if (locked) return
        PamService.reset()
        password = ""
        locked = true
        lockRequested()
    }
    function submit() {
        if (PamService.authenticating || PamService.delayed) return
        PamService.authenticate(password)
        password = ""
    }
    Connections { target: PamService; function onUnlocked() { ls.password = ""; ls.locked = false } }
}
