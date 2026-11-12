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
            grayscaleAppIcons: true,
            grayscaleWallpaper: true,
            grayscaleArtwork: true,
            animations: true,
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
        media: { showIndicator: true },
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
        const parts = path.split(".")
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
    function validate(d) {
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
        d.wallpaper.interval = clamp(d.wallpaper.interval, 1, 1440, 30)
        d.wallpaper.fade = clamp(d.wallpaper.fade, 0, 5000, 900)
        d.security.maxFailuresBeforeDelay = clamp(d.security.maxFailuresBeforeDelay, 1, 20, 3)
        d.security.failureDelayMs = clamp(d.security.failureDelayMs, 0, 30000, 2000)
        if (!Array.isArray(d.dock.favorites)) d.dock.favorites = deepClone(defaults.dock.favorites)
        if (!isObject(d.monitors)) d.monitors = {}
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
            console.warn("[UserConfig]", lastError)
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
