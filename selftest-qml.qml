// Headless QML load check used by tests/validate.sh: instantiates every component once (windows kept
// invisible) so syntax errors, bad imports and broken bindings surface in the log without touching the desktop.
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components
import qs.components.ui
import qs.components.popovers
import qs.components.settings
ShellRoot {
    id: root
    readonly property var screen0: Quickshell.screens[0]
    property int created: 0
    function make(name, comp, props) {
        try { const o = comp.createObject(root, props || {}); if (!o) { console.error("QMLCHECK FAIL", name, comp.errorString()); return } console.info("QMLCHECK ok", name); created++; Qt.callLater(() => o.destroy()) }
        catch (e) { console.error("QMLCHECK FAIL", name, e) }
    }
    Component { id: cBar; BottomBar { visible: false } }
    Component { id: cDock; AutoHideDock {} }
    Component { id: cOverlay; OverlayLayer { visible: false } }
    Component { id: cToasts; NotificationToasts { visible: false } }
    Component { id: cWall; WallpaperLayer { visible: false } }
    Component { id: cOsd; Osd { visible: false } }
    Component { id: cLock; LockScreen { locked: false } }
    Component { id: cSettings; Settings { visible: false } }
    Component { id: cLauncher; Item { width: 600; height: 400; Launcher {} } }
    Component { id: cCC; Item { width: 400; height: 600; ControlCenter { initialSection: "battery" } } }
    Component { id: cNC; Item { width: 400; height: 600; NotificationCenter {} } }
    Component { id: cMedia; Item { width: 400; height: 300; MediaControls {} } }
    Component { id: cCal; Item { width: 400; height: 400; CalendarPopover {} } }
    Component { id: cPower; Item { width: 600; height: 200; PowerMenu {} } }
    Component { id: cUi; Item { width: 300; height: 300; Column { MonoButton { text: "x"; icon: "check" } IconButton {} MonoSlider {} MonoToggle {} MonoTextField {} Panel { width: 10; height: 10 } MonoIcon {} AppIcon { icon: "firefox" } SectionTitle { text: "T" } Divider {} } } }
    Component { id: cSet; Item { width: 500; height: 400; Column { ToggleSetting { label: "a"; path: "osd.enabled" } NumberSetting { label: "b"; path: "osd.timeout" } TextSetting { label: "c"; path: "bar.clockFormat" } ChoiceSetting { label: "d"; path: "wallpaper.fillMode"; options: [{ value: "crop", label: "Crop" }] } SectionHeader { title: "h" } } } }
    Timer { interval: 1200; running: true; onTriggered: {
        const s = { modelData: root.screen0 }
        make("BottomBar", cBar, s); make("AutoHideDock", cDock, s); make("OverlayLayer", cOverlay, s); make("NotificationToasts", cToasts, s)
        make("WallpaperLayer", cWall, s); make("Osd", cOsd, s); make("LockScreen", cLock); make("Settings", cSettings)
        make("Launcher", cLauncher); make("ControlCenter", cCC); make("NotificationCenter", cNC); make("MediaControls", cMedia)
        make("CalendarPopover", cCal); make("PowerMenu", cPower); make("ui primitives", cUi); make("settings rows", cSet)
        const services = [NiriService, MonitorService, AudioService, NetworkService, BluetoothService, BatteryService, BrightnessService, MediaService, NotificationService, WallpaperService, PamService, LockService, SystemService, NightLightService, OsdService, ShellState, StateStore, ApplicationService]
        console.info("QMLCHECK ok services", services.length)
    } }
    Timer { interval: 3000; running: true; onTriggered: { console.info("QMLCHECK DONE", root.created, "components"); Qt.quit() } }
}
