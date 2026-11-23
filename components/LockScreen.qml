import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.lock

// Secure lock: Wayland ext-session-lock via WlSessionLock + PAM via PamService.
// One surface per connected display; typing on any surface feeds the shared buffer.
// The visuals live in components/lock/LockContent.qml.
WlSessionLock {
    id: lock
    locked: LockService.locked
    onSecureChanged: { LockService.secure = secure; if (secure) Log.info("Lock", "session lock confirmed by compositor") }
    onLockedChanged: if (!locked) PamService.reset()

    surface: WlSessionLockSurface {
        id: surf
        color: Theme.background
        readonly property string monitorKey: MonitorService.keyFor(screen)
        LockContent {
            id: content
            anchors.fill: parent
            wallpaper: WallpaperService.current(surf.monitorKey)
        }
        Component.onCompleted: content.focusInput()
        onVisibleChanged: if (visible) content.focusInput()
    }
}
