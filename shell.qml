//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// NIRI MONOCHROME — Designed for Focus.
// Entry point: per-monitor surfaces + global IPC handlers (bound to niri keys via `qs ipc call`).
ShellRoot {
    id: root

    // Touch singletons early so services connect at startup.
    Component.onCompleted: {
        console.info("[shell] NIRI MONOCHROME", Constants.version, "· fonts:", Theme.fontSans, "/", Theme.fontMono)
        NiriService.connected; ApplicationService.visible; NotificationService.serverEnabled; WallpaperService.collections; Keybindings.includePath; MediaService.hasPlayer
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope { id: perScreen
            required property var modelData
            WallpaperLayer { modelData: perScreen.modelData }
            BottomBar { modelData: perScreen.modelData }
            AutoHideDock { modelData: perScreen.modelData }
            OverlayLayer { modelData: perScreen.modelData }
            NotificationToasts { modelData: perScreen.modelData }
        }
    }

    LockScreen {}
    OverviewBridge {}
    Settings {}

    // ---- IPC: `qs -c niri-monochrome ipc call <target> <function>` ----
    IpcHandler { target: "launcher"
        function toggle(): void { ShellState.toggle("launcher") }
        function open(): void { ShellState.show("launcher") }
        function close(): void { ShellState.close() } }
    IpcHandler { target: "dock"
        function toggle(): void { ShellState.toggleDock() }
        function hide(): void { ShellState.hideDock() } }
    IpcHandler { target: "notifications"
        function toggle(): void { ShellState.toggle("notifications") }
        function toggleDnd(): void { NotificationService.toggleDnd() }
        function dismissAll(): void { NotificationService.dismissAll() }
        function clearHistory(): void { NotificationService.clearHistory() } }
    IpcHandler { target: "controlcenter"
        function toggle(): void { ShellState.toggle("control") }
        function section(name: string): void { ShellState.show("control", "", -1, name) } }
    IpcHandler { target: "power"
        function toggle(): void { ShellState.toggle("power") } }
    IpcHandler { target: "media"
        function toggle(): void { ShellState.toggle("media") }
        function playPause(): void { MediaService.toggle() }
        function next(): void { MediaService.next() }
        function previous(): void { MediaService.previous() } }
    IpcHandler { target: "settings"
        function toggle(): void { ShellState.settingsOpen = !ShellState.settingsOpen }
        function open(): void { ShellState.settingsOpen = true } }
    IpcHandler { target: "lock"
        function lock(): void { LockService.lock() }
        function lockShell(): void { LockService.lockShell() }
        function isLocked(): bool { return LockService.locked } }
    IpcHandler { target: "wallpaper"
        function next(): void { WallpaperService.nextAllFocused() }
        function previous(): void { const s = MonitorService.focusedScreen(); if (s) WallpaperService.previous(MonitorService.keyFor(s)) }
        function pause(): void { const s = MonitorService.focusedScreen(); if (s) WallpaperService.togglePaused(MonitorService.keyFor(s)) }
        function rescan(): void { WallpaperService.rescanAll() } }
    IpcHandler { target: "audio"
        function volumeUp(): void { AudioService.step(0.05) }
        function volumeDown(): void { AudioService.step(-0.05) }
        function mute(): void { AudioService.toggleMute() } }
    IpcHandler { target: "shell"
        function version(): string { return Constants.version }
        function status(): string { return JSON.stringify({ niri: NiriService.connected, screens: Quickshell.screens.map(s => s.name), notifications: SystemService.notificationOwnedByUs ? "owned" : (SystemService.notificationOwnedByOther ? "other:" + SystemService.notificationOwnerPid : "none"), locked: LockService.locked, workspaces: NiriService.workspaces.length }) }
        function reload(): void { Quickshell.reload(false) } }
}
