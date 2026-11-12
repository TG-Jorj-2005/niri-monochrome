pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Dedicated niri IPC service.
// - Subscribes to the event stream over $NIRI_SOCKET (no polling).
// - Keeps workspaces / windows / focus / overview state in sync.
// - Reconnects with backoff if the socket drops.
// - Actions are sent through `niri msg action ...` (documented CLI, validated args).
Singleton {
    id: niri

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") || ""
    property bool connected: false
    property bool haveWorkspaces: false
    property bool haveWindows: false
    readonly property bool ready: connected && haveWorkspaces && haveWindows
    property int reconnectDelay: 1000
    property int reconnectAttempts: 0
    property int reconnectCount: 0         // total reconnects during this shell lifetime
    readonly property string status: socketPath === "" ? "unavailable" : ready ? "ready" : connected ? "initializing" : (reconnectAttempts > 0 ? "reconnecting" : "initializing")

    // State mirrors of niri_ipc types (unknown fields are kept as-is).
    property var workspaces: []           // [{id, idx, name, output, is_active, is_focused, is_urgent, active_window_id}]
    property var windows: ({})            // id -> window
    property var windowList: []           // derived array for views
    property int focusedWindowId: -1
    property var focusedWindow: null
    property bool overviewOpen: false
    property var outputs: ({})            // name -> output info (make/model/serial/logical)
    property var keyboardLayouts: ({ names: [], current_idx: 0 })
    property string focusedOutput: ""

    signal event(string kind, var payload)
    signal workspacesUpdated()
    signal windowsUpdated()
    signal outputsUpdated()

    // ---------------- Event stream ----------------
    // A fresh socket/parser owns each connection. Ignore callbacks from obsolete sockets.
    property var stream: null
    Component {
        id: streamComponent
        Socket {
            id: eventSocket
            property bool reconnectScheduled: false
            path: niri.socketPath
            onConnectionStateChanged: {
                if (eventSocket !== niri.stream || reconnectScheduled) return
                niri.connected = connected
                if (connected) {
                    reconnectScheduled = false
                    reconnect.stop()
                    syncTimeout.restart()
                    Log.debug("Niri", "event stream connected")
                    write('"EventStream"\n')
                    flush()
                    outputsProc.running = true
                } else niri.onStreamClosed(this)
            }
            // Some Quickshell 0.2.1 socket failures arrive as an error without a reliable
            // connection-state transition. Route all errors through the same guarded recovery.
            onError: err => { Log.debug("Niri", "socket error", err); niri.onStreamClosed(this) }
            parser: SplitParser { splitMarker: "\n"; onRead: line => niri.handleLine(line) }
        }
    }
    function connectStream() {
        if (socketPath === "") return
        reconnect.stop()
        const old = stream
        stream = null
        if (old) { old.connected = false; old.destroy() }
        stream = streamComponent.createObject(niri)
        stream.connected = true
    }
    function onStreamClosed(sock) {
        if (sock !== stream || sock.reconnectScheduled) return
        sock.reconnectScheduled = true
        Log.debug("Niri", "event stream closed")
        syncTimeout.stop()
        outputsProc.running = false
        connected = false
        haveWorkspaces = false
        haveWindows = false
        focusedOutput = ""
        outputs = ({})
        keyboardLayouts = ({ names: [], current_idx: 0 })
        reconnectAttempts += 1
        reconnectCount += 1
        workspaces = []
        windows = ({})
        focusedWindowId = -1
        focusedWindow = null
        overviewOpen = false
        workspacesUpdated()
        refreshWindows()
        if (reconnectAttempts === 1 || reconnectAttempts % 10 === 0) Log.warn("Niri", "event stream disconnected, reconnecting (attempt", reconnectAttempts + ")")
        reconnect.interval = reconnectDelay
        reconnectDelay = Math.min(reconnectDelay * 2, 10000)     // capped exponential backoff, never a tight loop
        reconnect.restart()
    }
    Timer { id: reconnect; interval: 1000; repeat: false; onTriggered: niri.connectStream() }
    Component.onCompleted: {
        if (socketPath === "") Log.warn("Niri", "NIRI_SOCKET is not set; niri integration disabled")
        else connectStream()
    }

    Timer { id: syncTimeout; interval: 5000; onTriggered: { if (!niri.ready && niri.stream) niri.onStreamClosed(niri.stream) } }
    onReadyChanged: if (ready) { syncTimeout.stop(); reconnectDelay = 1000; reconnectAttempts = 0 }

    function validId(id) { return Number.isSafeInteger(id) && id >= 0 }
    function validPayload(kind, p) {
        if (!p || typeof p !== "object" || Array.isArray(p)) return false
        switch (kind) {
        case "WorkspacesChanged": return Array.isArray(p.workspaces) && p.workspaces.every(w => w && validId(w.id) && Number.isInteger(w.idx) && (w.output === null || typeof w.output === "string"))
        case "WindowsChanged": return Array.isArray(p.windows) && p.windows.every(w => w && validId(w.id) && typeof w.is_focused === "boolean")
        case "WindowOpenedOrChanged": return p.window && validId(p.window.id) && typeof p.window.is_focused === "boolean"
        case "WindowFocusChanged": return p.id === null || validId(p.id)
        case "WindowClosed": return validId(p.id)
        case "WorkspaceActivated": return validId(p.id) && typeof p.focused === "boolean"
        case "WorkspaceActiveWindowChanged": return validId(p.workspace_id) && (p.active_window_id === null || validId(p.active_window_id))
        case "WindowUrgencyChanged":
        case "WorkspaceUrgencyChanged": return validId(p.id) && typeof p.urgent === "boolean"
        case "OverviewOpenedOrClosed": return typeof p.is_open === "boolean"
        case "KeyboardLayoutsChanged": return p.keyboard_layouts && Array.isArray(p.keyboard_layouts.names) && Number.isInteger(p.keyboard_layouts.current_idx)
        case "KeyboardLayoutSwitched": return Number.isInteger(p.idx) && p.idx >= 0
        default: return true
        }
    }
    function handleLine(line) {
        if (!line || line.trim() === "") return
        let msg
        try { msg = JSON.parse(line) } catch (e) { Log.debug("Niri", "invalid JSON event ignored"); return }
        if (typeof msg !== "object" || msg === null) return
        if ("Ok" in msg || "Err" in msg) { if ("Err" in msg) Log.warn("Niri", "error reply:", msg.Err); return }
        const kind = Object.keys(msg)[0]
        const p = msg[kind]
        if (!validPayload(kind, p)) { Log.debug("Niri", "invalid event ignored", kind); return }
        switch (kind) {
        case "WorkspacesChanged":
            workspaces = p.workspaces.slice()
            updateFocusedOutput()
            haveWorkspaces = true
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
            updateFocusedOutput()
            workspacesUpdated()
            break }
        case "WorkspaceActiveWindowChanged": {
            const ws = workspaces.map(w => w.id === p.workspace_id ? Object.assign({}, w, { active_window_id: p.active_window_id }) : w)
            workspaces = ws
            workspacesUpdated()
            break }
        case "WorkspaceUrgencyChanged": {
            workspaces = workspaces.map(w => w.id === p.id ? Object.assign({}, w, { is_urgent: p.urgent }) : w)
            workspacesUpdated()
            break }
        case "WindowsChanged": {
            const map = {}
            let focused = -1
            for (const w of p.windows) { map[w.id] = w; if (w.is_focused) focused = w.id }
            haveWindows = true
            windows = map
            focusedWindowId = focused
            refreshWindows()
            break }
        case "WindowOpenedOrChanged": {
            const map = Object.assign({}, windows)
            map[p.window.id] = p.window
            if (p.window.is_focused) {
                for (const id in map) if (Number(id) !== p.window.id && map[id].is_focused) map[id] = Object.assign({}, map[id], { is_focused: false })
                focusedWindowId = p.window.id
            }
            windows = map
            refreshWindows()
            break }
        case "WindowClosed": {
            const map = Object.assign({}, windows)
            delete map[p.id]
            windows = map
            if (focusedWindowId === p.id) focusedWindowId = -1
            refreshWindows()
            break }
        case "WindowFocusChanged": {
            const map = Object.assign({}, windows)
            for (const id in map) {
                const f = (p.id !== null && Number(id) === p.id)
                if (map[id].is_focused !== f) map[id] = Object.assign({}, map[id], { is_focused: f })
            }
            windows = map
            focusedWindowId = p.id === null ? -1 : p.id
            refreshWindows()
            break }
        case "WindowUrgencyChanged": {
            if (windows[p.id]) { const map = Object.assign({}, windows); map[p.id] = Object.assign({}, map[p.id], { is_urgent: p.urgent }); windows = map; refreshWindows() }
            break }
        case "WindowLayoutsChanged":
        case "WindowFocusTimestampChanged":
            break // layout geometry is not needed by the shell
        case "OverviewOpenedOrClosed":
            overviewOpen = !!p.is_open
            break
        case "KeyboardLayoutsChanged":
            keyboardLayouts = p.keyboard_layouts
            break
        case "KeyboardLayoutSwitched":
            keyboardLayouts = Object.assign({}, keyboardLayouts, { current_idx: p.idx })
            break
        case "ConfigLoaded":
            if (p.failed) Log.warn("Niri", "niri reported a config load failure")
            outputsProc.running = true   // output config may have changed
            break
        default:
            break // unknown events are ignored gracefully
        }
        event(kind, p)
    }

    function refreshWindows() {
        const list = []
        for (const id in windows) list.push(windows[id])
        list.sort((a, b) => a.id - b.id)
        windowList = list
        focusedWindow = focusedWindowId >= 0 ? (windows[focusedWindowId] || null) : null
        windowsUpdated()
    }

    function updateFocusedOutput() {
        const f = workspaces.find(w => w.is_focused)
        if (f && f.output) focusedOutput = f.output
        else focusedOutput = (workspaces.find(w => w.output) || {}).output || ""
    }

    // ---------------- Derived queries ----------------
    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx)
    }
    function activeWorkspaceOn(output) {
        return workspaces.find(w => w.output === output && w.is_active) || null
    }
    function outputNames() {
        const s = {}
        for (const w of workspaces) if (w.output) s[w.output] = true
        return Object.keys(s)
    }
    function windowsOn(output) {
        const ids = {}
        for (const w of workspaces) if (w.output === output) ids[w.id] = true
        return windowList.filter(w => ids[w.workspace_id])
    }
    // Last-active window of an output that is NOT focused (neutral representation for inactive monitors).
    function activeWindowOn(output) {
        const ws = activeWorkspaceOn(output)
        if (!ws || ws.active_window_id === null || ws.active_window_id === undefined) return null
        return windows[ws.active_window_id] || null
    }

    // ---------------- Outputs (one-shot request) ----------------
    Process {
        id: outputsProc
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector { onStreamFinished: {
            try { const value = JSON.parse(text); if (niri.connected && value && typeof value === "object" && !Array.isArray(value)) { niri.outputs = value; niri.outputsUpdated() } }
            catch (e) { if (niri.connected) Log.warn("Niri", "cannot parse outputs:", e) }
        } }
    }
    function refreshOutputs() { outputsProc.running = true }

    // ---------------- Actions ----------------
    // Arguments are passed as an argv array (never through a shell).
    function action(args, after) {
        for (const a of args) if (typeof a !== "string" && typeof a !== "number") { Log.warn("Niri", "invalid action arg", a); return }
        const p = actionComponent.createObject(niri, { command: ["niri", "msg", "action"].concat(args.map(String)), after: after || [] })
        p.running = true
    }
    Component {
        id: actionComponent
        Process {
            property var after: []
            stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") Log.warn("Niri", "action stderr:", text.trim()) }
            onExited: (code) => { if (code !== 0) Log.warn("Niri", "action failed", "exit", code); else if (after.length) niri.action(after); destroy() }
        }
    }

    function focusWorkspaceById(id) {
        const ws = workspaces.find(w => w.id === id)
        if (!ws) return
        // Workspace reference by index is per-output in niri; focusing by name is global when named.
        if (ws.output && ws.output !== focusedOutput) action(["focus-monitor", ws.output], ["focus-workspace", String(ws.idx)])
        else action(["focus-workspace", String(ws.idx)])
    }
    function focusWindow(id) { action(["focus-window", "--id", String(id)]) }
    function toggleOverview() { action(["toggle-overview"]) }
    function openOverview() { action(["open-overview"]) }
    function closeOverview() { action(["close-overview"]) }
    function spawn(argv) { action(["spawn", "--"].concat(argv)) }
    function powerOffMonitors() { action(["power-off-monitors"]) }
}
