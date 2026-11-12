import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Thin bridge to niri's native overview (no custom overview is drawn).
Scope {
    IpcHandler {
        target: "niri"
        function toggleOverview(): void { NiriService.toggleOverview() }
        function openOverview(): void { NiriService.openOverview() }
        function closeOverview(): void { NiriService.closeOverview() }
        function focusWorkspace(index: int): void { NiriService.action(["focus-workspace", String(index)]) }
    }
}
