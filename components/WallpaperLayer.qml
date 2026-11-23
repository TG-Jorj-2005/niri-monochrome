import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Background layer per monitor with cross-fade between images (no black flash).
PanelWindow {
    id: wall
    required property var modelData
    readonly property string monitorKey: MonitorService.keyFor(modelData)
    readonly property var cfg: MonitorProfiles.profile(monitorKey).wallpaper
    readonly property string current: keyReady ? WallpaperService.current(monitorKey) : ""
    readonly property bool gray: UserConfig.data.appearance.grayscaleWallpaper

    screen: modelData
    visible: cfg.enabled
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.background
    WlrLayershell.namespace: Constants.nsWallpaper
    WlrLayershell.layer: WlrLayer.Background

    // Scan only once the monitor identity is stable (niri outputs received) so state is not
    // created under a transient key (connector/model) and the image does not switch at startup.
    readonly property bool keyReady: MonitorService.ready
    function ensureScanned() { if (keyReady) WallpaperService.scan(monitorKey) }
    Component.onCompleted: { ensureScanned(); show(current) }
    onKeyReadyChanged: ensureScanned()
    onMonitorKeyChanged: ensureScanned()
    Connections { target: UserConfig; function onChanged() { wall.ensureScanned() } }

    // Two image slots; the visible one fades in over the previous one.
    property int slot: 0
    property string pending: ""
    onCurrentChanged: show(current)
    function imageUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "" }
    function show(path) {
        if (!path) { pending = ""; imgA.source = ""; imgB.source = ""; return }
        const url = imageUrl(path)
        const shown = slot === 0 ? imgA : imgB
        if (shown.status === Image.Ready && shown.source == url) { pending = ""; return }
        const target = slot === 0 ? imgB : imgA
        if (target.source == url) { if (target.status === Image.Ready) { pending = path; onReady(target) }; return }
        pending = path
        target.source = url
    }
    function onReady(img) {
        if (img.source != imageUrl(pending)) return
        slot = (img === imgA) ? 0 : 1
        pending = ""
    }

    function failed(img) {
        if (!pending || img.source != imageUrl(pending)) return
        const path = pending
        pending = ""
        Log.warn("Wallpaper", "image unavailable; trying next collection entry")
        WallpaperService.loadFailed(monitorKey, path)
    }
    Item {
        id: stack
        anchors.fill: parent
        layer.enabled: wall.gray
        layer.effect: MultiEffect { saturation: -1.0 }
        Image { id: imgA; anchors.fill: parent; asynchronous: true; cache: false; fillMode: wall.cfg.fillMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            sourceSize: Qt.size(wall.modelData.width * wall.modelData.devicePixelRatio, wall.modelData.height * wall.modelData.devicePixelRatio)
            opacity: wall.slot === 0 ? 1 : 0; z: wall.slot === 0 ? 1 : 0
            onStatusChanged: if (status === Image.Ready) wall.onReady(imgA); else if (status === Image.Error) wall.failed(imgA)
            Behavior on opacity { NumberAnimation { duration: Theme.motionEnabled ? wall.cfg.fade : 0; easing.type: Easing.InOutQuad } } }
        Image { id: imgB; anchors.fill: parent; asynchronous: true; cache: false; fillMode: imgA.fillMode; sourceSize: imgA.sourceSize
            opacity: wall.slot === 1 ? 1 : 0; z: wall.slot === 1 ? 1 : 0
            onStatusChanged: if (status === Image.Ready) wall.onReady(imgB); else if (status === Image.Error) wall.failed(imgB)
            Behavior on opacity { NumberAnimation { duration: Theme.motionEnabled ? wall.cfg.fade : 0; easing.type: Easing.InOutQuad } } }
    }
    // Empty state when the collection is empty: keep the plain background + a quiet hint.
    Text { visible: wall.current === "" && WallpaperService.collections[wall.monitorKey] !== undefined; anchors.centerIn: parent
        text: "No images in " + wall.cfg.directory; color: Theme.textDisabled; font.family: Theme.fontMono; font.pixelSize: 13 }
}
