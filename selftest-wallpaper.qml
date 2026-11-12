import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
ShellRoot {
    id: root
    property int passed: 0
    function check(name, ok) { if (ok) passed++; console.info((ok ? "PASS " : "FAIL ") + name) }
    WallpaperLayer { id: wall; modelData: Quickshell.screens[0]; visible: false }
    Timer { interval: 1500; running: true; onTriggered: MonitorService.ready = true }
    Timer { interval: 5000; running: true; onTriggered: {
        root.check("decoder failure skips invalid image", wall.current.endsWith("/b-good.png") && wall.pending === "")
        const missing = UserConfig.data.wallpaper.directory + "/missing.png"
        WallpaperService.collections = { [wall.monitorKey]: [missing] }
        WallpaperService.setState(wall.monitorKey, {current: missing, order: [missing]})
    } }
    Timer { interval: 6500; running: true; onTriggered: {
        root.check("missing image reaches empty background fallback", wall.current === "" && wall.pending === "")
        console.info("RESULT " + root.passed + "/2 passed")
        Qt.quit()
    } }
}
