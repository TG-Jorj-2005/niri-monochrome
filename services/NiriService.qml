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
    property bool ready: false            // first WorkspacesChanged received
    property int reconnectDelay: 1000

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
    Socket {
        id: stream
        path: niri.socketPath
        connected: false
        onConnectionStateChanged: {
            niri.connected = connected
            if (connected) {
                niri.reconnectDelay = 1000
                write('"EventStream"\n')
                flush()
                outputsProc.running = true
            } else {
                niri.ready = false
                reconnect.interval = niri.reconnectDelay
                niri.reconnectDelay = Math.min(niri.reconnectDelay * 2, 10000)
                reconnect.restart()
            }
        }
        onError: err => console.warn("[NiriService] socket error", err)
        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => niri.handleLine(line)
        }
    }
    Timer { id: reconnect; interval: 1000; repeat: false; onTriggered: { if (niri.socketPath !== "") stream.connected = true } }
    Component.onCompleted: {
        if (socketPath === "") console.warn("[NiriService] NIRI_SOCKET is not set; niri integration disabled")
        else stream.connected = true
    }

    function handleLine(line) {
        if (!line || line.trim() === "") return
        let msg
        try { msg = JSON.parse(line) } catch (e) { console.warn("[NiriService] bad JSON from niri:", line.substring(0, 80)); return }
        if (typeof msg !== "object" || msg === null) return
        if ("Ok" in msg || "Err" in msg) { if ("Err" in msg) console.warn("[NiriService] error reply:", msg.Err); return }
        const kind = Object.keys(msg)[0]
        const p = msg[kind]
        switch (kind) {
        case "WorkspacesChanged":
            workspaces = p.workspaces.slice()
            updateFocusedOutput()
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
            if (p.failed) console.warn("[NiriService] niri reported a config load failure")
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
        else if (workspaces.length > 0 && focusedOutput === "") focusedOutput = workspaces[0].output || ""
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
            try { niri.outputs = JSON.parse(text); niri.outputsUpdated() }
            catch (e) { console.warn("[NiriService] cannot parse outputs:", e) }
        } }
    }
    function refreshOutputs() { outputsProc.running = true }

    // ---------------- Actions ----------------
    // Arguments are passed as an argv array (never through a shell).
    function action(args) {
        for (const a of args) if (typeof a !== "string" && typeof a !== "number") { console.warn("[NiriService] invalid action arg", a); return }
        const p = actionComponent.createObject(niri, { command: ["niri", "msg", "action"].concat(args.map(String)) })
        p.running = true
    }
    Component {
        id: actionComponent
        Process {
            stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("[NiriService] action stderr:", text.trim()) }
            onExited: (code) => { if (code !== 0) console.warn("[NiriService] action failed", command.join(" "), "exit", code); destroy() }
        }
    }

    function focusWorkspaceById(id) {
        const ws = workspaces.find(w => w.id === id)
        if (!ws) return
        // Workspace reference by index is per-output in niri; focusing by name is global when named.
        if (ws.output && ws.output !== focusedOutput) action(["focus-monitor", ws.output])
        action(["focus-workspace", String(ws.idx)])
    }
    function focusWindow(id) { action(["focus-window", "--id", String(id)]) }
    function toggleOverview() { action(["toggle-overview"]) }
    function openOverview() { action(["open-overview"]) }
    function closeOverview() { action(["close-overview"]) }
    function spawn(argv) { action(["spawn", "--"].concat(argv)) }
    function powerOffMonitors() { action(["power-off-monitors"]) }
}
