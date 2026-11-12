// Self-test harness for NiriService. Run by tests/niri-ipc-test.sh with NIRI_SOCKET pointing at a fake server.
import QtQuick
import Quickshell
import qs.services
ShellRoot {
    property var results: []
    Component.onCompleted: console.info("harness start, niri status:", NiriService.status)   // instantiate the singleton immediately
    function check(name, ok, detail) { results.push({ name: name, ok: !!ok, detail: detail || "" }); console.info((ok ? "PASS " : "FAIL ") + name + (detail ? "  (" + detail + ")" : "")) }
    // t=1.5s: initial state must be parsed
    Timer { interval: 2500; running: true; onTriggered: {
        check("connected", NiriService.connected)
        check("ready after WorkspacesChanged", NiriService.ready)
        check("workspaces parsed", NiriService.workspaces.length === 3, "n=" + NiriService.workspaces.length)
        check("per-output ordering", NiriService.workspacesOn("eDP-1").map(w => w.idx).join(",") === "1,2" && NiriService.workspacesOn("HDMI-A-1").length === 1)
        check("focused output", NiriService.focusedOutput === "eDP-1", NiriService.focusedOutput)
        check("windows parsed", NiriService.windowList.length === 2 && NiriService.focusedWindow && NiriService.focusedWindow.id === 7, "n=" + NiriService.windowList.length + " focused=" + (NiriService.focusedWindow ? NiriService.focusedWindow.id : "null") + " fid=" + NiriService.focusedWindowId)
        check("overview state", NiriService.overviewOpen === true)
        check("unknown event ignored", NiriService.workspaces.length === 3 && NiriService.windowList.length === 2)
    } }
    // t=3.5s: after WorkspaceActivated + WindowFocusChanged + WindowClosed + malformed line
    Timer { interval: 4300; running: true; onTriggered: {
        const a = NiriService.activeWorkspaceOn("eDP-1")
        check("workspace activation", a && a.id === 2, a ? "active id=" + a.id : "none")
        check("focus change", NiriService.focusedWindowId === 9, "id=" + NiriService.focusedWindowId)
        check("window closed", !NiriService.windows[7] && NiriService.windowList.length === 1)
        check("malformed JSON and malformed payloads survived", NiriService.connected && NiriService.workspaces.length === 3 && NiriService.windowList.length === 1)
    } }
    Timer { interval: 5400; running: true; onTriggered: {
        check("disconnect clears models and focus", !NiriService.ready && NiriService.workspaces.length === 0 && NiriService.focusedOutput === "")
        const count = NiriService.reconnectCount
        const delay = NiriService.reconnectDelay
        NiriService.onStreamClosed(NiriService.stream)
        NiriService.onStreamClosed(NiriService.stream)
        check("duplicate disconnect suppressed", NiriService.reconnectCount === count && NiriService.reconnectDelay === delay)
    } }
    // t=7s: the server dropped the connection at ~5s and accepted again → reconnected + resynced
    Timer { interval: 9000; running: true; onTriggered: {
        console.info("status at 9s:", NiriService.status, "connected:", NiriService.connected)
        check("reconnect attempted", NiriService.reconnectCount >= 1, "count=" + NiriService.reconnectCount)
        check("reconnected + resynced", NiriService.connected && NiriService.ready && NiriService.workspaces.length === 1, "ws=" + NiriService.workspaces.length + " status=" + NiriService.status)
        const failed = results.filter(r => !r.ok).length
        console.info("RESULT " + (results.length - failed) + "/" + results.length + " passed")
        Qt.quit()
    } }
}
