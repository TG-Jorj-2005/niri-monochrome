pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.config

// PAM authentication for the lock screen. Passwords are never stored or logged.
Singleton {
    id: pam

    property bool locked: false
    property bool authenticating: false
    property string message: ""         // user-visible feedback
    property bool messageIsError: false
    property int failures: 0
    property bool delayed: false
    property string pending: ""         // password being authenticated (cleared immediately after use)

    signal unlocked()
    signal failed()

    PamContext {
        id: ctx
        config: "login"
        configDirectory: "/etc/pam.d"
        user: Quickshell.env("USER")
        onPamMessage: {
            if (responseRequired) {
                ctx.respond(pam.pending)
                pam.pending = ""
            } else if (message && message.trim() !== "") {
                pam.message = message.trim()
                pam.messageIsError = messageIsError
            }
        }
        onCompleted: result => {
            pam.authenticating = false
            pam.pending = ""
            if (result === PamResult.Success) {
                pam.failures = 0
                pam.message = ""
                pam.unlocked()
            } else {
                pam.failures += 1
                pam.message = result === PamResult.MaxTries ? "Too many attempts" : "Authentication failed"
                pam.messageIsError = true
                pam.failed()
                if (pam.failures % UserConfig.data.security.maxFailuresBeforeDelay === 0) { pam.delayed = true; delayTimer.restart() }
            }
        }
        onError: error => {
            pam.authenticating = false
            pam.pending = ""
            pam.message = "PAM error: " + PamError.toString(error)
            pam.messageIsError = true
            pam.failed()
        }
    }
    Timer { id: delayTimer; interval: UserConfig.data.security.failureDelayMs; onTriggered: pam.delayed = false }

    function authenticate(password) {
        if (authenticating || delayed) return false
        if (!password || password.length === 0) { message = "Enter your password"; messageIsError = true; return false }
        pending = password
        message = "Verifying…"
        messageIsError = false
        authenticating = true
        if (!ctx.start()) {
            authenticating = false
            pending = ""
            message = "Could not start PAM"
            messageIsError = true
            return false
        }
        return true
    }
    function abort() { if (authenticating) ctx.abort(); pending = ""; authenticating = false }
    function reset() { abort(); message = ""; messageIsError = false; failures = 0; delayed = false }
}
