import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Background layer per monitor with smooth cross-fade between wallpapers and monochrome filter.
PanelWindow {
    id: wall
    required property var modelData

    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.background
    WlrLayershell.namespace: "nm-wallpaper"
    WlrLayershell.layer: WlrLayer.Background

    readonly property string current: WallpaperService.currentWallpaper

    // Two image slots for cross-fading
    property int activeSlot: 0
    property string pendingSource: ""

    onCurrentChanged: {
        if (!current) return
        const fileUrl = current.startsWith("file://") ? current : "file://" + current
        const target = activeSlot === 0 ? imgB : imgA
        if (target.source == fileUrl) return
        pendingSource = fileUrl
        target.source = fileUrl
    }

    function onImageReady(img) {
        if (img.source != pendingSource) return
        activeSlot = (img === imgA) ? 0 : 1
        pendingSource = ""
    }

    Item {
        id: stack
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect { saturation: -1.0 }

        Image {
            id: imgA
            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(wall.modelData.width * (wall.modelData.devicePixelRatio || 1), wall.modelData.height * (wall.modelData.devicePixelRatio || 1))
            opacity: wall.activeSlot === 0 ? 1 : 0
            z: wall.activeSlot === 0 ? 1 : 0
            onStatusChanged: {
                if (status === Image.Ready) wall.onImageReady(imgA)
            }
            Behavior on opacity {
                NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
            }
        }

        Image {
            id: imgB
            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            sourceSize: imgA.sourceSize
            opacity: wall.activeSlot === 1 ? 1 : 0
            z: wall.activeSlot === 1 ? 1 : 0
            onStatusChanged: {
                if (status === Image.Ready) wall.onImageReady(imgB)
            }
            Behavior on opacity {
                NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
            }
        }
    }

    // Empty state fallback when no wallpapers are found
    Text {
        visible: wall.current === "" && !WallpaperService.scanning
        anchors.centerIn: parent
        text: "No wallpapers found in " + WallpaperService.wallpaperDir
        color: Theme.muted
        font.family: Theme.mono
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }
}
