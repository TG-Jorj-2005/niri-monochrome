pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Use Niri's native screenshot UI and its existing save path/clipboard behavior.
Singleton {
    id: capture
    property string mode: "region"
    property bool editorAvailable: false
    property string lastError: ""
    function take(kind) {
        if (["region", "screen", "window"].indexOf(kind) < 0) return
        mode = kind
        lastError = ""
        ShellState.close()
        ShellState.hideDock()
        delay.restart()
    }
    // Allow the shell overlay to unmap before the compositor captures the scene.
    Timer { id: delay; interval: 250; onTriggered: NiriService.action([capture.mode === "region" ? "screenshot" : "screenshot-" + capture.mode]) }
    Process {
        command: ["sh", "-c", "command -v swappy >/dev/null 2>&1"]
        running: true
        onExited: code => capture.editorAvailable = code === 0
    }
    function editClipboard() {
        if (!editorAvailable || editor.running) return
        ShellState.close()
        lastError = ""
        editor.running = true
    }
    Process {
        id: editor
        // Fixed pipeline: pixels stay out of QML strings, arguments and logs.
        command: ["sh", "-c", "wl-paste --type image/png | swappy -f -"]
        onExited: code => { if (code !== 0) capture.lastError = "Could not open an image from the clipboard. Take a screenshot first." }
    }
}
