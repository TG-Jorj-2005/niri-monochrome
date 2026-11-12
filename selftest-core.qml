import QtQuick
import Quickshell
import qs.config
import qs.services
ShellRoot {
    id: root
    property int passed: 0
    property int failed: 0
    function check(name, ok) { if (ok) passed++; else failed++; console.info((ok ? "PASS " : "FAIL ") + name) }
    Component.onCompleted: { UserConfig.loaded; StateStore.loaded; NotificationService.serverEnabled }
    Timer { interval: 1800; running: true; onTriggered: {
        const d = UserConfig.validate({bar: null, dock: [], security: {useShellLock: "false"}, notifications: {server: "true"}})
        root.check("corrupt section types recover", d.bar.height === 40 && Array.isArray(d.dock.favorites))
        root.check("string cannot enable experimental lock", d.security.useShellLock === false)
        root.check("legacy server setting is not migration consent", d.notifications.shellServerApproved === false && !NotificationService.serverStarted)
        const before = JSON.stringify(UserConfig.data)
        UserConfig.applyText("{invalid json")
        root.check("invalid JSON retains last configuration", JSON.stringify(UserConfig.data) === before && UserConfig.lastError !== "")
        const normalized = StateStore.normalize({wallpaper: null, recentApps: [null, "firefox", 42]})
        root.check("corrupt state types recover", Object.keys(normalized.wallpaper).length === 0 && normalized.recentApps.join() === "firefox")
        const key = "Make|Model.1|Serial.2"
        WallpaperService.setState(key, {current: "/tmp/valid.png"})
        root.check("monitor key dots preserved in state", StateStore.data.wallpaper[key].current === "/tmp/valid.png")
        MonitorProfiles.setOverride(key, "bar.height", 45)
        root.check("monitor key dots preserved in config", UserConfig.data.monitors[key].bar.height === 45)
        const screens = [{name:"DP-1"}, {name:"DP-2"}]
        const keys = MonitorService.resolveKeys({"DP-1":{make:"M",model:"X"},"DP-2":{make:"M",model:"X"}}, screens)
        root.check("identical monitors do not collide", keys["DP-1"] !== keys["DP-2"])
        const unique = MonitorService.resolveKeys({"eDP-1":{make:"AU Optronics",model:"0x7EAD",serial:"0x00007EAD"}}, [{name:"eDP-1"}])
        root.check("existing monitor identity preserved", unique["eDP-1"] === "AU Optronics|0x7EAD|0x00007EAD")
        root.check("missing EDID falls back to connector", MonitorService.resolveKeys({}, [{name:"DP-3"}])["DP-3"] === "DP-3")
        WallpaperService.collections = {[key]:["/tmp/bad.png", "/tmp/good.png"]}
        WallpaperService.setState(key,{current:"/tmp/bad.png",order:["/tmp/bad.png","/tmp/good.png"]})
        WallpaperService.loadFailed(key,"/tmp/bad.png")
        root.check("failed wallpaper advances to valid candidate", WallpaperService.current(key) === "/tmp/good.png")
        WallpaperService.loadFailed(key,"/tmp/good.png")
        root.check("all wallpapers failed gives empty fallback", WallpaperService.current(key) === "")
        root.check("missing NIRI_SOCKET is unavailable", NiriService.status === "unavailable")
        ShellState.dockKeyboard = true
        ShellState.show("launcher")
        root.check("overlay clears dock keyboard focus", !ShellState.dockKeyboard)
        console.info("RESULT " + root.passed + "/" + (root.passed+root.failed) + " passed")
        Qt.quit()
    } }
}
