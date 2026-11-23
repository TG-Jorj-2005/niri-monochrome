pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Persistent user configuration: ~/.config/niri-monochrome/config.json
// `data` is the merged (defaults + file) object. Mutate through set()/update();
// every change reassigns `data` so all bindings re-evaluate.
Singleton {
    id: cfg

    readonly property string path: Constants.configDir + "/config.json"
    property bool loaded: false
    property string lastError: ""

    // ---- Defaults (also serve as the "reset to defaults" source) ----
    readonly property var defaults: ({
        version: 2,
        appearance: {
            accentColor: "#829DA3",
            grayscaleAppIcons: true,
            grayscaleWallpaper: true,
            grayscaleArtwork: true,
            animations: true,
            reduceMotion: false,
            glassEnabled: true,
            panelOpacity: 0.92,
            panelRadius: 12,
            shadowStrength: 0.35,
            animationIntensity: 1.0,
            barShadow: true
        },
        bar: {
            enabled: true,
            height: 40,
            widthPercent: 92,            // percent of the display width
            marginX: 24,                 // minimum side margin
            marginBottom: 12,
            maxWidth: 1760,
            radius: 9,
            reserveSpace: true,
            showBranding: true,
            showTray: true,
            showDate: true,
            showSeconds: false,
            clockFormat: "HH:mm",
            dateFormat: "ddd d MMM",
            titleMaxChars: 64,
            showAppName: true
        },
        dock: {
            enabled: true,
            autoHide: true,
            iconSize: 40,
            hideDelay: 350,
            triggerHeight: 2,
            showRunning: true,
            favorites: [
                "Alacritty.desktop",
                "org.gnome.Nautilus.desktop",
                "org.mozilla.firefox.desktop",
                "org.gnome.TextEditor.desktop",
                "niri-monochrome-settings.desktop"
            ]
        },
        launcher: {
            width: 600,
            maxResults: 8,
            showDescriptions: true,
            rememberRecent: true,
            recentLimit: 12,
            terminal: "alacritty"
        },
        controlCenter: {
            width: 380,
            showBrightness: true,
            showPowerProfile: true,
            confirmPower: true
        },
        notifications: {
            server: true,
            shellServerApproved: false,    // explicit migration consent; legacy server:true is insufficient
            toasts: true,
            toastTimeout: 6000,
            criticalTimeout: 0,
            maxToasts: 4,
            doNotDisturb: false,
            historyEnabled: true,
            historyRetentionDays: 7,
            historyMax: 200,
            storeBodies: true
        },
        wallpaper: {
            enabled: true,
            directory: Constants.defaultWallpaperDir,
            interval: 30,
            shuffle: true,
            fade: 900,
            fillMode: "crop"
        },
        media: { showIndicator: true, visualizerEnabled: true, visualizerStyle: "history", visualizerBarCount: 24 },
        osd: {
            enabled: false,                // off by default: the user's Fn-key scripts show a mako OSD; enable + rebind to use this one
            timeout: 1500,
            width: 280
        },
        nightLight: {
            enabled: false,                // owns a wlsunset process while on
            latitude: 44.4,
            longitude: 26.1,
            tempLow: 4000,
            tempHigh: 6500
        },
        shortcuts: {
            launcher: "Mod+D",
            dock: "Mod+A",
            notifications: "",             // empty: Mod+N stays bound to makoctl in the user's binds.kdl
            doNotDisturb: "",              // empty: Mod+Shift+N stays bound to makoctl mode -t dnd
            controlCenter: "Mod+Shift+A",
            powerMenu: "Mod+X",
            settings: "Mod+Comma",
            lock: "",                      // empty = keep the existing niri binding (swaylock)
            overview: "",                  // empty = keep the existing niri Mod+O
            wallpaperNext: "Mod+Shift+W",
            writeNiriInclude: true
        },
        security: {
            useShellLock: false,           // opt-in until verified by the user; false = swaylock
            systemLockCommand: ["swaylock", "-f"],
            lockClockFormat: "HH:mm",
            lockDateFormat: "dddd, d MMMM yyyy",
            maxFailuresBeforeDelay: 3,
            failureDelayMs: 2000,
            showBattery: true
        },
        system: {
            brightnessDevice: "",          // empty = first backlight device
            logLevel: "info",             // debug | info | warn | error
            batteryLowPercent: 15,
            batteryCriticalPercent: 5,
            batteryWarnings: true,
            suspendCommand: ["systemctl", "suspend"],
            rebootCommand: ["systemctl", "reboot"],
            shutdownCommand: ["systemctl", "poweroff"],
            logoutCommand: ["niri", "msg", "action", "quit", "--skip-confirmation"]
        },
        // Per-monitor overrides keyed by stable identity "make|model|serial" (or connector).
        monitors: {}
    })

    property var data: deepClone(defaults)

    signal changed()

    // ---------------------------------------------------------------
    function deepClone(o) { return JSON.parse(JSON.stringify(o)) }

    function isObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }

    // Deep merge b over a (arrays replaced, objects merged).
    function merge(a, b) {
        const out = deepClone(a)
        if (!isObject(b)) return out
        for (const k in b) {
            if (isObject(b[k]) && isObject(out[k])) out[k] = merge(out[k], b[k])
            else out[k] = deepClone(b[k])
        }
        return out
    }

    // Read "a.b.c" from data.
    function get(path, fallback) {
        let cur = data
        for (const p of path.split(".")) {
            if (cur === undefined || cur === null || !(p in cur)) return fallback
            cur = cur[p]
        }
        return cur
    }

    function set(path, value) {
        const parts = Array.isArray(path) ? path : path.split(".")
        const next = deepClone(data)
        let cur = next
        for (let i = 0; i < parts.length - 1; i++) {
            if (!isObject(cur[parts[i]])) cur[parts[i]] = {}
            cur = cur[parts[i]]
        }
        cur[parts[parts.length - 1]] = deepClone(value)
        data = validate(next)
        changed()
        save()
    }

    function resetSection(section) {
        const next = deepClone(data)
        next[section] = deepClone(defaults[section])
        data = next
        changed(); save()
    }

    function resetAll() { data = deepClone(defaults); changed(); save() }

    // ---- Validation: clamp numeric values to sane ranges ----
    function clamp(v, lo, hi, dflt) {
        const n = Number(v)
        if (!isFinite(n)) return dflt
        return Math.min(hi, Math.max(lo, n))
    }
    function normalize(template, value) {
        if (isObject(template)) {
            const out = isObject(value) ? deepClone(value) : {}
            for (const k of Object.keys(template)) out[k] = normalize(template[k], out[k])
            return out
        }
        if (Array.isArray(template)) return Array.isArray(value) && value.every(v => typeof v === "string") ? value.slice() : deepClone(template)
        return typeof value === typeof template && (typeof value !== "number" || isFinite(value)) ? value : deepClone(template)
    }
    function validate(d) {
        d = normalize(defaults, d)
        if (!/^#[0-9a-f]{6}$/i.test(d.appearance.accentColor)) d.appearance.accentColor = defaults.appearance.accentColor
        d.appearance.panelOpacity = clamp(d.appearance.panelOpacity, 0.82, 1, 0.92)
        d.appearance.panelRadius = clamp(d.appearance.panelRadius, 0, 24, 12)
        d.appearance.shadowStrength = clamp(d.appearance.shadowStrength, 0, 0.65, 0.35)
        d.appearance.animationIntensity = clamp(d.appearance.animationIntensity, 0, 1.5, 1)
        d.media.visualizerBarCount = Math.round(clamp(d.media.visualizerBarCount, 16, 32, 24))
        if (["history", "meter"].indexOf(d.media.visualizerStyle) < 0) d.media.visualizerStyle = "history"
        d.bar.height = clamp(d.bar.height, 32, 96, 40)
        d.bar.widthPercent = clamp(d.bar.widthPercent, 30, 100, 92)
        d.bar.radius = clamp(d.bar.radius, 0, 24, 9)
        d.bar.marginX = clamp(d.bar.marginX, 0, 400, 24)
        d.bar.marginBottom = clamp(d.bar.marginBottom, 0, 200, 12)
        d.bar.maxWidth = clamp(d.bar.maxWidth, 400, 7680, 1760)
        d.bar.titleMaxChars = clamp(d.bar.titleMaxChars, 10, 200, 64)
        d.dock.iconSize = clamp(d.dock.iconSize, 24, 96, 40)
        d.dock.hideDelay = clamp(d.dock.hideDelay, 0, 5000, 350)
        d.dock.triggerHeight = clamp(d.dock.triggerHeight, 1, 20, 2)
        d.launcher.width = clamp(d.launcher.width, 360, 1200, 600)
        d.launcher.maxResults = clamp(d.launcher.maxResults, 3, 20, 8)
        d.launcher.recentLimit = clamp(d.launcher.recentLimit, 0, 50, 12)
        d.controlCenter.width = clamp(d.controlCenter.width, 300, 600, 380)
        d.notifications.toastTimeout = clamp(d.notifications.toastTimeout, 1000, 60000, 6000)
        d.notifications.criticalTimeout = clamp(d.notifications.criticalTimeout, 0, 600000, 0)
        d.notifications.maxToasts = clamp(d.notifications.maxToasts, 1, 10, 4)
        d.notifications.historyRetentionDays = clamp(d.notifications.historyRetentionDays, 0, 365, 7)
        d.notifications.historyMax = clamp(d.notifications.historyMax, 10, 2000, 200)
        d.osd.timeout = clamp(d.osd.timeout, 500, 10000, 1500)
        d.osd.width = clamp(d.osd.width, 160, 600, 280)
        d.nightLight.latitude = clamp(d.nightLight.latitude, -90, 90, 44.4)
        d.nightLight.longitude = clamp(d.nightLight.longitude, -180, 180, 26.1)
        d.nightLight.tempLow = clamp(d.nightLight.tempLow, 1000, 10000, 4000)
        d.nightLight.tempHigh = clamp(d.nightLight.tempHigh, 1000, 10000, 6500)
        d.system.batteryLowPercent = clamp(d.system.batteryLowPercent, 1, 50, 15)
        d.system.batteryCriticalPercent = clamp(d.system.batteryCriticalPercent, 1, 30, 5)
        if (["debug","info","warn","error"].indexOf(d.system.logLevel) === -1) d.system.logLevel = "info"
        d.wallpaper.interval = clamp(d.wallpaper.interval, 1, 1440, 30)
        d.wallpaper.fade = clamp(d.wallpaper.fade, 0, 5000, 900)
        d.security.maxFailuresBeforeDelay = clamp(d.security.maxFailuresBeforeDelay, 1, 20, 3)
        d.security.failureDelayMs = clamp(d.security.failureDelayMs, 0, 30000, 2000)
        if (!Array.isArray(d.dock.favorites)) d.dock.favorites = deepClone(defaults.dock.favorites)
        if (!isObject(d.monitors)) d.monitors = {}
        d.system.batteryCriticalPercent = Math.min(d.system.batteryLowPercent, d.system.batteryCriticalPercent)
        if (["crop", "fit"].indexOf(d.wallpaper.fillMode) < 0) d.wallpaper.fillMode = "crop"
        return d
    }

    // ---- Persistence ----
    FileView {
        id: file
        path: cfg.path
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: cfg.applyText(text())
        onLoadFailed: error => {
            // Missing file is fine on first run: write defaults.
            if (error === FileViewError.FileNotFound) { cfg.loaded = true; cfg.save() }
            else { cfg.lastError = "config load failed: " + FileViewError.toString(error); cfg.loaded = true }
        }
        onFileChanged: reload()
    }

    function applyText(text) {
        try {
            const parsed = JSON.parse(text)
            const merged = validate(merge(defaults, parsed))
            if (JSON.stringify(merged) !== JSON.stringify(data)) { data = merged; changed() }
            lastError = ""
        } catch (e) {
            lastError = "config.json is not valid JSON: " + e
            Log.warn("UserConfig", "", lastError)
        }
        loaded = true
    }

    Timer { id: saveTimer; interval: 250; onTriggered: cfg.flush() }
    function save() { saveTimer.restart() }
    function flush() {
        mkdir.running = true
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", Constants.configDir]
        onExited: { file.setText(JSON.stringify(cfg.data, null, 2) + "\n") }
    }
}
