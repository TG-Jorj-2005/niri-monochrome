import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.ui
import qs.components.settings

// Settings window (regular toplevel; niri opens it floating via the installed window rule).
FloatingWindow {
    id: win
    title: "NIRI MONOCHROME — Settings"
    visible: ShellState.settingsOpen
    implicitWidth: 960
    implicitHeight: 640
    minimumSize: Qt.size(760, 480)
    color: Theme.background
    onVisibleChanged: if (!visible) ShellState.settingsOpen = false

    property int section: ShellState.settingsSection
    onSectionChanged: ShellState.settingsSection = section
    property string monitorKey: Quickshell.screens.length > 0 ? MonitorService.keyFor(Quickshell.screens[0]) : "default"
    readonly property var sections: [
        { t: "Appearance", i: "palette" }, { t: "Bottom Bar", i: "bar" }, { t: "Dock", i: "dock" }, { t: "Applications", i: "grid" },
        { t: "Launcher", i: "search" }, { t: "Control Center", i: "settings" }, { t: "Notifications", i: "bell" }, { t: "Wallpapers", i: "image" },
        { t: "Monitors", i: "monitor" }, { t: "Shortcuts", i: "keyboard" }, { t: "Security", i: "shield" }, { t: "System", i: "wrench" }
    ]

    // ---- Sidebar ----
    Rectangle {
        id: side
        width: 220; height: parent.height
        color: Theme.surface
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; rightMargin: 15 }
            spacing: 2
            Column { spacing: 2; bottomPadding: 16
                Label { text: "NIRI MONOCHROME"; font.weight: Font.Bold; font.letterSpacing: 2; font.pixelSize: Theme.fontSm; color: Theme.silver }
                Label { text: "Designed for Focus."; font.pixelSize: Theme.fontXs; color: Theme.textSecondary } }
            Repeater {
                model: win.sections
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 32; radius: Theme.radiusControl
                    color: win.section === index ? Theme.silver : sma.containsMouse ? Theme.hover : "transparent"
                    Row { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        MonoIcon { name: parent.parent.modelData.i; size: 14; color: win.section === parent.parent.index ? Theme.inverse : Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: parent.parent.modelData.t; font.pixelSize: Theme.fontSm; font.weight: Font.Medium; color: win.section === parent.parent.index ? Theme.inverse : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.section = parent.index }
                }
            }
        }
        Label { anchors { bottom: parent.bottom; left: parent.left; margins: 14 } text: "v" + Constants.version + " · " + UserConfig.path.replace(Constants.home, "~"); font.pixelSize: Theme.fontXs; color: Theme.textSecondary; mono: true; width: parent.width - 28; wrapMode: Text.Wrap }
    }

    // ---- Content ----
    Flickable {
        id: flick
        anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        contentHeight: page.implicitHeight + 48
        clip: true
        Loader {
            id: page
            x: 28; y: 20; width: flick.width - 56
            sourceComponent: [appearance, barS, dockS, appsS, launcherS, ccS, notifS, wallS, monS, keysS, secS, sysS][win.section]
        }
    }

    // ================= Sections =================
    Component { id: appearance; Column { spacing: 0
        SectionHeader { title: "Appearance"; subtitle: "Dark monochrome · silver accent · brutalist geometry. Tokens live in config/Theme.qml." }
        Row { spacing: 6; bottomPadding: 14
            Repeater { model: [Theme.background, Theme.surface, Theme.surface2, Theme.elevated, Theme.border, Theme.silverMuted, Theme.silver, Theme.silverBright, Theme.text]
                delegate: Rectangle { required property var modelData; width: 44; height: 28; color: modelData; border.width: 1; border.color: Theme.border; radius: 3
                    Label { anchors.centerIn: parent; text: String(parent.modelData).toUpperCase().substring(1); font.pixelSize: 8; mono: true; color: parent.modelData.hslLightness > 0.45 ? Theme.inverse : Theme.text } } } }
        ToggleSetting { label: "Grayscale application icons"; description: "Desaturate app icons in the dock, launcher and bar"; path: "appearance.grayscaleAppIcons" }
        ToggleSetting { label: "Grayscale wallpaper"; description: "Force black-and-white rendering of wallpapers"; path: "appearance.grayscaleWallpaper" }
        ToggleSetting { label: "Grayscale album artwork"; path: "appearance.grayscaleArtwork" }
        ToggleSetting { label: "Animations"; description: "Subtle 140–180 ms ease-out transitions"; path: "appearance.animations" }
        ToggleSetting { label: "Reduced motion"; description: "Immediate state changes; decorative movement disabled"; path: "appearance.reduceMotion" }
        ToggleSetting { label: "Monochrome glass"; description: "Translucent panels; compositor blur limited to bar and dock"; path: "appearance.glassEnabled" }
        NumberSetting { label: "Panel opacity"; path: "appearance.panelOpacity"; from: 0.82; to: 1; step: 0.01 }
        NumberSetting { label: "Panel radius"; path: "appearance.panelRadius"; from: 0; to: 24; unit: "px" }
        NumberSetting { label: "Shadow strength"; path: "appearance.shadowStrength"; from: 0; to: 0.65; step: 0.05 }
        NumberSetting { label: "Animation intensity"; path: "appearance.animationIntensity"; from: 0; to: 1.5; step: 0.1 }
        ToggleSetting { label: "Audio visualizer"; description: "Real output amplitude; backend runs only while Media is open"; path: "media.visualizerEnabled" }
        ChoiceSetting { label: "Visualizer style"; path: "media.visualizerStyle"; options: [{value:"history",label:"Level history"},{value:"meter",label:"Level meter"}] }
        NumberSetting { label: "Visualizer bars"; path: "media.visualizerBarCount"; from: 16; to: 32; step: 1 }
        SettingRow { label: "Typography"; description: Theme.fontSans + " · " + Theme.fontMono; Label { text: "Aa 01"; mono: true; secondary: true } }
        SettingRow { label: "Reset appearance"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("appearance") } }
    } }

    Component { id: barS; Column { spacing: 0
        SectionHeader { title: "Bottom Bar"; subtitle: "Global defaults. Per-monitor overrides live under Monitors." }
        ToggleSetting { label: "Enabled"; path: "bar.enabled" }
        NumberSetting { label: "Height"; path: "bar.height"; from: 32; to: 96; unit: "px" }
        NumberSetting { label: "Width"; description: "Percentage of the display width (capped by maximum width and side margins)"; path: "bar.widthPercent"; from: 30; to: 100; unit: "%" }
        NumberSetting { label: "Corner radius"; path: "bar.radius"; from: 0; to: 24; unit: "px" }
        NumberSetting { label: "Horizontal margins"; description: "Minimum distance from the screen edges"; path: "bar.marginX"; from: 0; to: 400; unit: "px" }
        NumberSetting { label: "Bottom margin"; path: "bar.marginBottom"; from: 0; to: 200; unit: "px" }
        NumberSetting { label: "Maximum width"; path: "bar.maxWidth"; from: 400; to: 7680; step: 10; unit: "px" }
        ToggleSetting { label: "Reserve space"; description: "Exclusive zone so windows are not covered by the bar"; path: "bar.reserveSpace" }
        ToggleSetting { label: "Show NIRI branding"; path: "bar.showBranding" }
        ToggleSetting { label: "Show system tray"; path: "bar.showTray" }
        ToggleSetting { label: "Show application name"; description: "Prefix the window title with the app name"; path: "bar.showAppName" }
        NumberSetting { label: "Title max characters"; path: "bar.titleMaxChars"; from: 10; to: 200; unit: "ch" }
        ToggleSetting { label: "Show date"; path: "bar.showDate" }
        ToggleSetting { label: "Show seconds"; path: "bar.showSeconds" }
        TextSetting { label: "Clock format"; description: "Qt format, e.g. HH:mm or h:mm AP"; path: "bar.clockFormat"; fieldWidth: 140 }
        TextSetting { label: "Date format"; description: "e.g. ddd d MMM"; path: "bar.dateFormat"; fieldWidth: 140 }
        SettingRow { label: "Reset bar"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("bar") } }
    } }

    Component { id: dockS; Column { id: dockCol; spacing: 0
        SectionHeader { title: "Dock"; subtitle: "Auto-hidden launcher strip above the bar. Hover the bottom edge or press " + Keybindings.binding("dock") + "." }
        ToggleSetting { label: "Enabled"; path: "dock.enabled" }
        ToggleSetting { label: "Auto-hide"; description: "Off = always visible"; path: "dock.autoHide" }
        NumberSetting { label: "Icon size"; path: "dock.iconSize"; from: 24; to: 96; unit: "px" }
        NumberSetting { label: "Hide delay"; path: "dock.hideDelay"; from: 0; to: 5000; step: 50; unit: "ms" }
        NumberSetting { label: "Trigger height"; description: "Hover zone at the bottom edge"; path: "dock.triggerHeight"; from: 1; to: 20; unit: "px" }
        ToggleSetting { label: "Show running applications"; path: "dock.showRunning" }
        SectionHeader { title: "Favorites"; subtitle: "Order = dock order. Click ↑ ↓ to reorder." }
        Column { width: parent.width; spacing: 2
            Repeater { model: UserConfig.data.dock.favorites
                delegate: Rectangle { required property string modelData; required property int index
                    readonly property var e: ApplicationService.byId(modelData)
                    width: parent.width; height: 36; radius: Theme.radiusControl; color: Theme.surface2; border.width: 1; border.color: Theme.border
                    Row { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        AppIcon { icon: e ? e.icon : ""; size: 20; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: e ? e.name : modelData + "  (not installed)"; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter; color: e ? Theme.text : Theme.textDisabled }
                        Label { text: modelData; mono: true; font.pixelSize: Theme.fontXs; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter } }
                    Row { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        IconButton { icon: "chevron-up"; iconSize: 12; implicitWidth: 24; implicitHeight: 24; enabled: index > 0; onClicked: win.moveFav(index, -1) }
                        IconButton { icon: "chevron-down"; iconSize: 12; implicitWidth: 24; implicitHeight: 24; enabled: index < UserConfig.data.dock.favorites.length - 1; onClicked: win.moveFav(index, 1) }
                        IconButton { icon: "x"; iconSize: 12; implicitWidth: 24; implicitHeight: 24; onClicked: win.removeFav(index) } } } } }
        Item { height: 10; width: 1 }
        MonoTextField {
            id: favSearch; width: parent.width; icon: "plus"; placeholder: "Add application…"; implicitHeight: 34
            // Clearing/rebuilding results destroys the clicked delegate's QML context.
            function selectFavorite(id) { text = ""; win.addFav(id) }
        }
        Column { width: parent.width; spacing: 2; visible: favSearch.text.length > 0
            // A model binding must not mutate the launcher's reactive memoization cache.
            Repeater { model: favSearch.text.length > 0 ? ApplicationService.searchUncached(favSearch.text.trim(), 6).filter(e => UserConfig.data.dock.favorites.indexOf(e.id) === -1) : []
                delegate: Rectangle { required property var modelData; width: parent.width; height: 32; radius: Theme.radiusControl; color: ama.containsMouse ? Theme.hover : "transparent"
                    Row { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        AppIcon { icon: modelData.icon; size: 18; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: modelData.name; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: favSearch.selectFavorite(modelData.id) } } } }
        SettingRow { label: "Reset dock"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("dock") } }
    } }
    function moveFav(i, d) { const f = UserConfig.data.dock.favorites.slice(); const j = i + d; if (j < 0 || j >= f.length) return; const t = f[i]; f[i] = f[j]; f[j] = t; UserConfig.set("dock.favorites", f) }
    function removeFav(i) { const f = UserConfig.data.dock.favorites.slice(); f.splice(i, 1); UserConfig.set("dock.favorites", f) }
    function addFav(id) { const f = UserConfig.data.dock.favorites.slice(); if (f.indexOf(id) === -1) f.push(id); UserConfig.set("dock.favorites", f) }

    Component { id: appsS; Column { spacing: 0
        SectionHeader { title: "Applications"; subtitle: ApplicationService.visible.length + " visible desktop entries (" + ApplicationService.entries.length + " total)." }
        TextSetting { label: "Terminal"; description: "Used for entries with Terminal=true"; path: "launcher.terminal"; fieldWidth: 160 }
        SettingRow { label: "Recent applications"; description: StateStore.get("recentApps", []).length + " remembered"; MonoButton { text: "Clear"; onClicked: ApplicationService.clearRecent() } }
        SectionHeader { title: "Recent" }
        Column { width: parent.width; spacing: 2
            Repeater { model: StateStore.get("recentApps", [])
                delegate: Row { required property string modelData; readonly property var e: ApplicationService.byId(modelData); spacing: 10; height: 30
                    AppIcon { icon: e ? e.icon : ""; size: 18; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: e ? e.name : modelData; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter } } } }
    } }

    Component { id: launcherS; Column { spacing: 0
        SectionHeader { title: "Launcher"; subtitle: "Applications only — no files, no commands. " + Keybindings.binding("launcher") }
        NumberSetting { label: "Width"; path: "launcher.width"; from: 360; to: 1200; step: 10; unit: "px" }
        NumberSetting { label: "Max results"; path: "launcher.maxResults"; from: 3; to: 20 }
        ToggleSetting { label: "Show descriptions"; description: "Also match on the entry's comment"; path: "launcher.showDescriptions" }
        ToggleSetting { label: "Remember recent applications"; path: "launcher.rememberRecent" }
        NumberSetting { label: "Recent limit"; path: "launcher.recentLimit"; from: 0; to: 50 }
        SettingRow { label: "Reset launcher"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("launcher") } }
    } }

    Component { id: ccS; Column { spacing: 0
        SectionHeader { title: "Control Center"; subtitle: "Compact popover anchored to the status indicators." }
        NumberSetting { label: "Width"; path: "controlCenter.width"; from: 300; to: 600; step: 10; unit: "px" }
        ToggleSetting { label: "Brightness slider"; description: BrightnessService.available ? "Device: " + BrightnessService.device : "No backlight device detected"; path: "controlCenter.showBrightness" }
        ToggleSetting { label: "Power profile selector"; description: BatteryService.profilesAvailable ? "Backend: " + (BatteryService.profilesBackend || "PowerProfiles D-Bus service") : "No power-profile service available"; path: "controlCenter.showPowerProfile" }
        ToggleSetting { label: "Confirm power actions"; description: "Logout, reboot and shutdown ask twice"; path: "controlCenter.confirmPower" }
        SectionHeader { title: "On-screen display"; subtitle: "Volume / microphone / brightness OSD above the bar, driven by real state changes. Your Fn keys currently show a mako OSD; rebind them to `qs -c niri-monochrome ipc call audio volumeUp|volumeDown|mute|micMute` and `ipc call brightness up|down` to avoid two OSDs (scripts/install.sh --shell-osd does this with a backup)." }
        ToggleSetting { label: "Shell OSD"; path: "osd.enabled" }
        NumberSetting { label: "OSD timeout"; path: "osd.timeout"; from: 500; to: 10000; step: 100; unit: "ms" }
        SectionHeader { title: "Night light"; subtitle: NightLightService.available ? "wlsunset owned by the shell while enabled (status: " + NightLightService.status + ")" : "wlsunset is not installed" }
        ToggleSetting { label: "Night light"; path: "nightLight.enabled" }
        NumberSetting { label: "Latitude"; path: "nightLight.latitude"; from: -90; to: 90; step: 0.1 }
        NumberSetting { label: "Longitude"; path: "nightLight.longitude"; from: -180; to: 180; step: 0.1 }
        NumberSetting { label: "Night temperature"; path: "nightLight.tempLow"; from: 1000; to: 10000; step: 100; unit: "K" }
        NumberSetting { label: "Day temperature"; path: "nightLight.tempHigh"; from: 1000; to: 10000; step: 100; unit: "K" }
        SettingRow { label: "Reset control center"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("controlCenter") } }
    } }

    Component { id: notifS; Column { spacing: 0
        SectionHeader { title: "Notifications"; subtitle: SystemService.notificationOwnedByUs ? "This shell owns org.freedesktop.Notifications." : SystemService.notificationOwnedByOther ? "Another daemon (pid " + SystemService.notificationOwnerPid + ") owns org.freedesktop.Notifications — stop it (e.g. mako) to receive notifications here." : "No notification daemon is registered." }
        SettingRow { label: "Notification ownership"; description: "mako remains authoritative. Shell server migration requires explicit approval." }
        ToggleSetting { label: "Show toasts"; path: "notifications.toasts" }
        ToggleSetting { label: "Do Not Disturb"; description: "Critical notifications still show"; path: "notifications.doNotDisturb" }
        NumberSetting { label: "Toast timeout"; path: "notifications.toastTimeout"; from: 1000; to: 60000; step: 500; unit: "ms" }
        NumberSetting { label: "Critical timeout"; description: "0 = stays until dismissed"; path: "notifications.criticalTimeout"; from: 0; to: 600000; step: 1000; unit: "ms" }
        NumberSetting { label: "Max visible toasts"; path: "notifications.maxToasts"; from: 1; to: 10 }
        ToggleSetting { label: "Keep history"; path: "notifications.historyEnabled" }
        NumberSetting { label: "History retention"; description: "0 = forever (not recommended)"; path: "notifications.historyRetentionDays"; from: 0; to: 365; unit: "d" }
        NumberSetting { label: "History size"; path: "notifications.historyMax"; from: 10; to: 2000; step: 10 }
        ToggleSetting { label: "Store message bodies"; description: "Off = only app + title are kept on disk"; path: "notifications.storeBodies" }
        SettingRow { label: "Clear history"; MonoButton { text: "Clear"; onClicked: NotificationService.clearHistory() } }
        SettingRow { label: "Reset notifications"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("notifications") } }
    } }

    Component { id: wallS; Column { spacing: 0
        SectionHeader { title: "Wallpapers"; subtitle: "Black-and-white brutalist architecture. Each monitor has its own collection and rotation." }
        MonitorPicker {}
        readonly property var prof: MonitorProfiles.profile(win.monitorKey).wallpaper
        readonly property var st: WallpaperService.state(win.monitorKey)
        readonly property var list: WallpaperService.collections[win.monitorKey] || []
        ToggleSetting { label: "Enabled"; value: prof.enabled; onChanged: v => MonitorProfiles.setOverride(win.monitorKey, "wallpaper.enabled", v) }
        TextSetting { label: "Directory"; description: "Images are read from here (png, jpg, webp…)"; value: prof.directory; fieldWidth: 300; mono: true
            onChanged: v => { MonitorProfiles.setOverride(win.monitorKey, "wallpaper.directory", v); WallpaperService.scan(win.monitorKey) } }
        NumberSetting { label: "Rotation interval"; value: prof.interval; from: 1; to: 1440; unit: "min"; onChanged: v => MonitorProfiles.setOverride(win.monitorKey, "wallpaper.interval", v) }
        ToggleSetting { label: "Shuffle"; value: prof.shuffle; onChanged: v => { MonitorProfiles.setOverride(win.monitorKey, "wallpaper.shuffle", v); WallpaperService.ensureOrder(win.monitorKey) } }
        NumberSetting { label: "Fade duration"; value: prof.fade; from: 0; to: 5000; step: 100; unit: "ms"; onChanged: v => MonitorProfiles.setOverride(win.monitorKey, "wallpaper.fade", v) }
        ChoiceSetting { label: "Fill mode"; value: prof.fillMode; options: [{ value: "crop", label: "Crop" }, { value: "fit", label: "Fit" }]; onChanged: v => MonitorProfiles.setOverride(win.monitorKey, "wallpaper.fillMode", v) }
        SettingRow { label: "Rotation"; description: list.length + " images · " + (st.paused ? "paused" : st.pinned ? "pinned" : "next in " + WallpaperService.remainingMinutes(win.monitorKey) + " min")
            MonoButton { icon: "chevron-left"; implicitHeight: 28; onClicked: WallpaperService.previous(win.monitorKey) }
            MonoButton { icon: st.paused ? "play" : "pause"; text: st.paused ? "Resume" : "Pause"; implicitHeight: 28; onClicked: WallpaperService.togglePaused(win.monitorKey) }
            MonoButton { icon: "chevron-right"; implicitHeight: 28; onClicked: WallpaperService.next(win.monitorKey) }
            MonoButton { icon: "refresh"; implicitHeight: 28; onClicked: WallpaperService.scan(win.monitorKey) } }
        SectionHeader { title: "Collection"; subtitle: "Click to show now · pin to keep permanently." }
        Flow { width: parent.width; spacing: 8
            Repeater { model: list
                delegate: Rectangle { required property string modelData
                    readonly property bool cur: WallpaperService.current(win.monitorKey) === modelData
                    width: 150; height: 100; color: Theme.surface2; radius: Theme.radiusControl; border.width: cur ? 2 : 1; border.color: cur ? Theme.silver : Theme.border; clip: true
                    Image { anchors.fill: parent; anchors.margins: 2; source: "file://" + modelData; asynchronous: true; sourceSize: Qt.size(300, 200); fillMode: Image.PreserveAspectCrop }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 20; color: Qt.rgba(0,0,0,0.7)
                        Label { anchors.left: parent.left; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: WallpaperService.fileName(modelData); font.pixelSize: 10; width: parent.width - 36; mono: true } }
                    IconButton { icon: "pin"; iconSize: 11; implicitWidth: 20; implicitHeight: 20; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3
                        active: cur && WallpaperService.pinned(win.monitorKey); onClicked: { if (cur && WallpaperService.pinned(win.monitorKey)) WallpaperService.unpin(win.monitorKey); else WallpaperService.select(win.monitorKey, modelData, true) } }
                    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperService.select(win.monitorKey, modelData, false) } } }
            Label { visible: list.length === 0; text: "No images found. Add black-and-white images to the directory above."; secondary: true; font.pixelSize: Theme.fontSm } }
    } }

    Component { id: monS; Column { spacing: 0
        SectionHeader { title: "Monitors"; subtitle: "Profiles are keyed by make|model|serial so they survive reconnection and reordering." }
        Column { width: parent.width; spacing: 4
            Repeater { model: MonitorService.knownKeys()
                delegate: Rectangle { required property string modelData
                    readonly property bool connected: MonitorService.isConnected(modelData)
                    readonly property var scr: Quickshell.screens.find(s => MonitorService.keyFor(s) === modelData) || null
                    width: parent.width; height: 48; radius: Theme.radiusControl; color: win.monitorKey === modelData ? Theme.elevated : Theme.surface2; border.width: 1; border.color: win.monitorKey === modelData ? Theme.silver : Theme.border
                    Row { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        MonoIcon { name: "monitor"; size: 16; color: connected ? Theme.silver : Theme.textDisabled; anchors.verticalCenter: parent.verticalCenter }
                        Column { anchors.verticalCenter: parent.verticalCenter
                            Label { text: scr ? MonitorService.label(scr) : modelData; font.pixelSize: Theme.fontSm }
                            Label { text: (connected ? "connected" : "disconnected — profile preserved") + " · key " + modelData + (Object.keys(MonitorProfiles.overridesFor(modelData)).length ? " · has overrides" : ""); font.pixelSize: Theme.fontXs; secondary: true; mono: true } } }
                    Row { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        MonoButton { text: "Edit"; implicitHeight: 26; padding: 8; active: win.monitorKey === modelData; onClicked: win.monitorKey = modelData }
                        MonoButton { text: "Clear overrides"; implicitHeight: 26; padding: 8; flat: true; enabled: Object.keys(MonitorProfiles.overridesFor(modelData)).length > 0; onClicked: MonitorProfiles.clearMonitor(modelData) } } } } }
        SectionHeader { title: "Overrides for " + win.monitorKey; subtitle: "Toggle 'override' to decouple a value from the global default." }
        Repeater {
            model: [
                { s: "bar", p: "enabled", l: "Bar enabled", t: "bool" }, { s: "bar", p: "height", l: "Bar height", t: "num", lo: 36, hi: 96 },
                { s: "bar", p: "marginX", l: "Bar horizontal margins", t: "num", lo: 0, hi: 400 }, { s: "bar", p: "marginBottom", l: "Bar bottom margin", t: "num", lo: 0, hi: 200 },
                { s: "bar", p: "maxWidth", l: "Bar max width", t: "num", lo: 400, hi: 7680 }, { s: "bar", p: "reserveSpace", l: "Bar reserves space", t: "bool" },
                { s: "dock", p: "enabled", l: "Dock enabled", t: "bool" }, { s: "dock", p: "autoHide", l: "Dock auto-hide", t: "bool" },
                { s: "dock", p: "iconSize", l: "Dock icon size", t: "num", lo: 24, hi: 96 }
            ]
            delegate: SettingRow { required property var modelData
                readonly property string path: modelData.s + "." + modelData.p
                readonly property bool ov: MonitorProfiles.hasOverride(win.monitorKey, path)
                readonly property var eff: MonitorProfiles.profile(win.monitorKey)[modelData.s][modelData.p]
                label: modelData.l; description: ov ? "override" : "inherits global (" + eff + ")"
                MonoToggle { visible: modelData.t === "bool"; enabled: ov; checked: eff; onToggled: c => MonitorProfiles.setOverride(win.monitorKey, path, c) }
                Row { visible: modelData.t === "num"; spacing: 4
                    IconButton { icon: "minus"; iconSize: 12; implicitWidth: 24; implicitHeight: 28; enabled: ov; onClicked: MonitorProfiles.setOverride(win.monitorKey, path, Math.max(modelData.lo, eff - 2)) }
                    Label { text: String(eff); mono: true; width: 44; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
                    IconButton { icon: "plus"; iconSize: 12; implicitWidth: 24; implicitHeight: 28; enabled: ov; onClicked: MonitorProfiles.setOverride(win.monitorKey, path, Math.min(modelData.hi, eff + 2)) } }
                MonoButton { text: ov ? "Overridden" : "Override"; implicitHeight: 26; padding: 8; active: ov
                    onClicked: { if (ov) MonitorProfiles.clearOverride(win.monitorKey, path); else MonitorProfiles.setOverride(win.monitorKey, path, eff) } } }
        }
        Label { topPadding: 10; text: "Dock favorites per monitor: edit config.json → monitors.<key>.dock.favorites. Wallpaper overrides are under Wallpapers."; secondary: true; font.pixelSize: Theme.fontXs; width: parent.width; wrapMode: Text.Wrap }
    } }

    Component { id: keysS; Column { spacing: 0
        SectionHeader { title: "Shortcuts"; subtitle: "Written to " + Keybindings.includePath.replace(Constants.home, "~") + " (included from config.kdl; niri reloads it live). Empty = not bound." }
        SettingRow { label: "Keyboard Shortcuts"; description: "Search current bindings without executing actions"; MonoButton { text: "Open cheat sheet"; icon: "keyboard"; onClicked: { ShellState.settingsOpen = false; ShellState.show("shortcuts") } } }
        ToggleSetting { label: "Write niri include file"; description: "Disable if you manage binds yourself"; path: "shortcuts.writeNiriInclude" }
        Repeater { model: Keybindings.actions
            delegate: TextSetting { required property var modelData; label: modelData.label; description: "qs ipc call " + modelData.target + " " + modelData.fn; path: "shortcuts." + modelData.id; fieldWidth: 180
                validate: t => Keybindings.valid(t) } }
        SectionHeader { title: "Preserved from your niri config" }
        Repeater { model: Keybindings.preserved
            delegate: SettingRow { required property var modelData; label: modelData.label; Label { text: modelData.key; mono: true; font.pixelSize: Theme.fontSm; color: Theme.silver } } }
        SettingRow { label: "Reset shortcuts"; MonoButton { text: "Reset"; onClicked: UserConfig.resetSection("shortcuts") } }
    } }

    Component { id: secS; Column { spacing: 0
        SectionHeader { title: "Security"; subtitle: "Lock screen uses the Wayland session-lock protocol (WlSessionLock) and PAM (/etc/pam.d/login). Passwords are never stored or logged." }
        ToggleSetting { label: "Use the shell lock screen"; description: "On = every lock (power menu, control center, Super+Alt+L, lid-close, swayidle via ~/.local/bin/niri-lock) uses this screen, with swaylock as fallback if the shell does not answer. Off = swaylock everywhere."; path: "security.useShellLock" }
        SettingRow { label: "Test lock now"; description: "Always uses the shell lock (WlSessionLock + PAM) regardless of the toggle above; unlock with your password"; MonoButton { icon: "lock"; text: "Test shell lock"; onClicked: LockService.lockShell() } }
        TextSetting { label: "Clock format"; path: "security.lockClockFormat"; fieldWidth: 140 }
        TextSetting { label: "Date format"; path: "security.lockDateFormat"; fieldWidth: 220 }
        NumberSetting { label: "Failures before delay"; path: "security.maxFailuresBeforeDelay"; from: 1; to: 20 }
        NumberSetting { label: "Delay after failures"; path: "security.failureDelayMs"; from: 0; to: 30000; step: 500; unit: "ms" }
        ToggleSetting { label: "Show battery on lock screen"; path: "security.showBattery" }
        SettingRow { label: "Status"; Label { text: "PAM user " + SystemService.user + " · failures " + PamService.failures; mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
    } }

    Component { id: sysS; Column { spacing: 0
        SectionHeader { title: "System"; subtitle: "Diagnostics and dangerous buttons." }
        SettingRow { label: "niri IPC"; Label { text: NiriService.connected ? "connected · " + NiriService.workspaces.length + " workspaces · " + NiriService.windowList.length + " windows" : "disconnected"; mono: true; font.pixelSize: Theme.fontSm; color: NiriService.connected ? Theme.silver : Theme.silverBright } }
        SettingRow { label: "Displays"; Label { text: Quickshell.screens.map(s => s.name).join(", "); mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
        SettingRow { label: "Notification service"; Label { text: SystemService.notificationOwnedByUs ? "owned by this shell" : SystemService.notificationOwnedByOther ? "owned by pid " + SystemService.notificationOwnerPid : "none"; mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
        SettingRow { label: "Audio"; Label { text: AudioService.ready ? AudioService.sinkName : "PipeWire not ready"; mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
        SettingRow { label: "Network"; Label { text: NetworkService.statusText(); mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
        SettingRow { label: "Bluetooth"; Label { text: BluetoothService.statusText(); mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
        SettingRow { label: "Battery"; description: BatteryService.profilesAvailable ? "power profiles via " + BatteryService.profilesBackend : "no power-profile backend"; Label { text: BatteryService.stateText(); mono: true; font.pixelSize: Theme.fontSm; secondary: true } }
        ToggleSetting { label: "Battery warnings"; description: "Low / critical notifications (sent through the active notification daemon)"; path: "system.batteryWarnings" }
        NumberSetting { label: "Low battery at"; path: "system.batteryLowPercent"; from: 1; to: 50; unit: "%" }
        NumberSetting { label: "Critical battery at"; path: "system.batteryCriticalPercent"; from: 1; to: 30; unit: "%" }
        SectionHeader { title: "Service status" }
        Repeater { model: [
                { n: "niri IPC", s: NiriService.status }, { n: "Monitors", s: MonitorService.ready ? "ready" : "initializing" }, { n: "Audio (PipeWire)", s: AudioService.status },
                { n: "Network", s: NetworkService.status }, { n: "Bluetooth", s: BluetoothService.status }, { n: "Battery (UPower)", s: BatteryService.status },
                { n: "Brightness", s: BrightnessService.status }, { n: "Notifications", s: NotificationService.status }, { n: "Night light", s: NightLightService.status },
                { n: "Wallpaper", s: Object.keys(WallpaperService.collections).length > 0 ? "ready" : "initializing" } ]
            delegate: SettingRow { required property var modelData; label: modelData.n; height: 34
                Label { text: modelData.s; mono: true; font.pixelSize: Theme.fontSm; color: /ready|mako|server|on|off/.test(modelData.s) ? Theme.silver : /unavailable|error|other|reconnecting/.test(modelData.s) ? Theme.silverBright : Theme.textSecondary } } }
        ChoiceSetting { label: "Log level"; path: "system.logLevel"; options: [{ value: "debug", label: "debug" }, { value: "info", label: "info" }, { value: "warn", label: "warn" }, { value: "error", label: "error" }] }
        SettingRow { label: "Recent log"; description: Log.warnCount + " warnings · " + Log.errorCount + " errors this session"; MonoButton { text: "Clear"; flat: true; onClicked: Log.clear() } }
        Rectangle { width: parent.width; height: Math.min(220, logCol.implicitHeight + 16); color: Theme.surface; border.width: 1; border.color: Theme.border; radius: Theme.radiusControl; clip: true
            Flickable { anchors.fill: parent; anchors.margins: 8; contentHeight: logCol.implicitHeight; clip: true
                Column { id: logCol; width: parent.width
                    Repeater { model: Log.entries.slice(-40).reverse()
                        delegate: Label { required property var modelData; width: parent.width; mono: true; font.pixelSize: 10; wrapMode: Text.Wrap; elide: Text.ElideNone
                            color: modelData.level === "error" ? Theme.silverBright : modelData.level === "warn" ? Theme.silver : Theme.textSecondary
                            text: Qt.formatTime(new Date(modelData.t), "HH:mm:ss") + "  " + modelData.level.toUpperCase().padEnd(5) + " " + modelData.tag + ": " + modelData.msg } }
                    Label { visible: Log.entries.length === 0; text: "no log entries"; secondary: true; font.pixelSize: Theme.fontXs } } } }
        TextSetting { label: "Brightness device"; description: "Empty = first backlight device"; path: "system.brightnessDevice"; fieldWidth: 220 }
        SettingRow { label: "Config file"; description: UserConfig.lastError !== "" ? UserConfig.lastError : "valid"; Label { text: UserConfig.path.replace(Constants.home, "~"); mono: true; font.pixelSize: Theme.fontXs; secondary: true } }
        SettingRow { label: "Reload shell"; MonoButton { icon: "refresh"; text: "Reload"; onClicked: Quickshell.reload(false) } }
        SettingRow { label: "Reset everything to defaults"; description: "Clears all settings and monitor overrides"; MonoButton { text: "Reset all"; onClicked: UserConfig.resetAll() } }
        Label { topPadding: 16; text: "NIRI MONOCHROME " + Constants.version + " · Quickshell · niri · Designed for Focus."; secondary: true; font.pixelSize: Theme.fontXs }
    } }

    component MonitorPicker: Row { spacing: 6; bottomPadding: 8
        Repeater { model: MonitorService.knownKeys()
            delegate: MonoButton { required property string modelData; readonly property var scr: Quickshell.screens.find(s => MonitorService.keyFor(s) === modelData) || null
                text: scr ? scr.name : modelData; icon: "monitor"; iconSize: 13; implicitHeight: 28; active: win.monitorKey === modelData; onClicked: win.monitorKey = modelData } } }
}
