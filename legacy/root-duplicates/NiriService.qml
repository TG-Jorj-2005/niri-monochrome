pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Niri IPC — event-driven workspace/window/output state.
// Uses `niri msg --json event-stream` (handles the socket protocol for us).
Singleton {
    id: niri

    property bool connected: false
    property bool ready: false
    property var workspaces: []            // [{id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}]
    property var windows: ({})             // id -> window object
    property var windowList: []            // derived sorted array
    property int focusedWindowId: -1
    property var focusedWindow: null
    property string focusedOutput: ""

    signal workspacesUpdated()

    // ---- Event stream process ----
    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => niri.handleEvent(data)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => { if (data.trim()) console.warn("[NiriService] stderr:", data.trim()) }
        }
        onExited: (code, status) => {
            console.warn("[NiriService] event-stream exited with code", code)
            niri.connected = false
            niri.ready = false
            reconnect.restart()
        }
        onStarted: { niri.connected = true }
    }

    Timer {
        id: reconnect
        interval: 2000
        onTriggered: { stream.running = true }
    }

    // ---- Event handler ----
    function handleEvent(line) {
        if (!line || line.trim() === "") return
        let msg
        try { msg = JSON.parse(line) } catch (e) { return }
        if (typeof msg !== "object" || msg === null) return

        const kind = Object.keys(msg)[0]
        const p = msg[kind]

        switch (kind) {
        case "WorkspacesChanged":
            workspaces = p.workspaces.slice()
            updateFocus()
            ready = true
            workspacesUpdated()
            break
        case "WorkspaceActivated": {
            const ws = workspaces.map(w => Object.assign({}, w))
            const target = ws.find(w => w.id === p.id)
            if (target) {
                for (const w of ws) {
                    if (w.output === target.output) w.is_active = (w.id === p.id)
                    if (p.focused) w.is_focused = (w.id === p.id)
                }
            }
            workspaces = ws
            updateFocus()
            workspacesUpdated()
            break
        }
        case "WorkspaceActiveWindowChanged":
            workspaces = workspaces.map(w => w.id === p.workspace_id ? Object.assign({}, w, { active_window_id: p.active_window_id }) : w)
            workspacesUpdated()
            break
        case "WorkspaceUrgencyChanged":
            workspaces = workspaces.map(w => w.id === p.id ? Object.assign({}, w, { is_urgent: p.urgent }) : w)
            workspacesUpdated()
            break
        case "WindowsChanged": {
            const map = {}
            let focused = -1
            for (const w of p.windows) { map[w.id] = w; if (w.is_focused) focused = w.id }
            windows = map
            focusedWindowId = focused
            refreshWindows()
            break
        }
        case "WindowOpenedOrChanged": {
            const map = Object.assign({}, windows)
            map[p.window.id] = p.window
            if (p.window.is_focused) {
                for (const id in map) map[id] = Object.assign({}, map[id], { is_focused: map[id].id === p.window.id })
                focusedWindowId = p.window.id
            }
            windows = map
            refreshWindows()
            break
        }
        case "WindowClosed": {
            const map = Object.assign({}, windows)
            delete map[p.id]
            windows = map
            if (focusedWindowId === p.id) focusedWindowId = -1
            refreshWindows()
            break
        }
        case "WindowFocusChanged": {
            const map = Object.assign({}, windows)
            for (const id in map) {
                const f = (p.id !== null && Number(id) === p.id)
                if (map[id].is_focused !== f) map[id] = Object.assign({}, map[id], { is_focused: f })
            }
            windows = map
            focusedWindowId = p.id === null ? -1 : p.id
            refreshWindows()
            break
        }
        default:
            break
        }
    }

    function refreshWindows() {
        const list = []
        for (const id in windows) list.push(windows[id])
        list.sort((a, b) => a.id - b.id)
        windowList = list
        focusedWindow = focusedWindowId >= 0 ? (windows[focusedWindowId] || null) : null
    }

    function updateFocus() {
        const f = workspaces.find(w => w.is_focused)
        if (f && f.output) focusedOutput = f.output
    }

    // ---- Queries ----
    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx)
    }

    function activeWorkspaceOn(output) {
        return workspaces.find(w => w.output === output && w.is_active) || null
    }

    // ---- Actions (via niri msg action) ----
    function action(args) {
        const p = actionComp.createObject(niri, { command: ["niri", "msg", "action"].concat(args.map(String)) })
        p.running = true
    }
    Component {
        id: actionComp
        Process {
            onExited: (code) => {
                if (code !== 0) console.warn("[NiriService] action failed:", command.join(" "))
                destroy()
            }
        }
    }

    function focusWorkspaceById(id) {
        const ws = workspaces.find(w => w.id === id)
        if (!ws) return
        if (ws.output && ws.output !== focusedOutput) action(["focus-monitor", ws.output])
        action(["focus-workspace", String(ws.idx)])
    }

    function focusWindow(id) { action(["focus-window", "--id", String(id)]) }
    function toggleOverview() { action(["toggle-overview"]) }
}
