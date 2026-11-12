pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper manager: directory scanning, rotation timer, per-monitor coordination.
Singleton {
    id: wp

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property var imageExt: ["png", "jpg", "jpeg", "webp", "bmp", "avif", "jxl"]
    property var wallpapers: []
    property int currentIndex: 0
    property string currentWallpaper: ""
    property bool paused: false
    property int intervalMinutes: 30
    property bool scanning: false

    signal wallpaperChanged(string path)

    Component.onCompleted: {
        scan()
    }

    Process {
        id: scanProc
        command: ["find", "-L", wp.wallpaperDir, "-maxdepth", "1", "-type", "f", "(",
                  "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o",
                  "-iname", "*.webp", "-o", "-iname", "*.bmp", "-o", "-iname", "*.avif", ")"]
        stdout: StdioCollector { id: scanOut }
        onExited: code => {
            wp.scanning = false
            if (code === 0) {
                const lines = scanOut.text.split("\n").map(s => s.trim()).filter(s => s.length > 0).sort()
                wp.wallpapers = lines
                if (lines.length > 0) {
                    // Check if current.png is in list and prefer it initially
                    const cur = wp.wallpaperDir + "/current.png"
                    let idx = lines.indexOf(cur)
                    if (idx === -1) idx = 0
                    wp.currentIndex = idx
                    wp.currentWallpaper = lines[idx]
                }
            } else {
                console.warn("[WallpaperService] find failed with code", code)
            }
        }
    }

    function scan() {
        if (scanning) return
        scanning = true
        scanProc.running = true
    }

    function next() {
        if (wallpapers.length <= 1) return
        currentIndex = (currentIndex + 1) % wallpapers.length
        currentWallpaper = wallpapers[currentIndex]
        wallpaperChanged(currentWallpaper)
    }

    function previous() {
        if (wallpapers.length <= 1) return
        currentIndex = (currentIndex + wallpapers.length - 1) % wallpapers.length
        currentWallpaper = wallpapers[currentIndex]
        wallpaperChanged(currentWallpaper)
    }

    function togglePaused() {
        paused = !paused
    }

    function setWallpaper(path) {
        const idx = wallpapers.indexOf(path)
        if (idx !== -1) currentIndex = idx
        currentWallpaper = path
        wallpaperChanged(currentWallpaper)
    }

    // Auto-rotation timer (checks every 30 seconds against interval)
    Timer {
        interval: 30000
        repeat: true
        running: true
        property double lastAdvance: Date.now()
        onTriggered: {
            if (wp.paused || wp.wallpapers.length <= 1) return
            const now = Date.now()
            if (now - lastAdvance >= wp.intervalMinutes * 60000) {
                lastAdvance = now
                wp.next()
            }
        }
    }
}
