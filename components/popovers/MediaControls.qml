import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.config
import qs.services
import qs.components.ui

// Compact MPRIS widget: grayscale artwork, title/artist/album, transport, player switcher.
PopoverFrame {
    id: mc
    title: "Media"
    icon: "music"
    implicitWidth: 380
    readonly property var p: MediaService.active
    headerExtra: [ Row { spacing: 2; visible: MediaService.players.length > 1
        Repeater { model: MediaService.players
            delegate: MonoButton { required property var modelData; text: modelData.identity || "Player"; implicitHeight: 22; padding: 6; active: MediaService.active === modelData; onClicked: MediaService.select(modelData) } } } ]

    Item { visible: !MediaService.hasPlayer; width: parent.width; height: 70
        Column { anchors.centerIn: parent; spacing: 6
            MonoIcon { name: "music"; size: 22; color: Theme.textDisabled; anchors.horizontalCenter: parent.horizontalCenter }
            Label { text: "No media player is running"; secondary: true; font.pixelSize: Theme.fontSm; anchors.horizontalCenter: parent.horizontalCenter } } }

    Row {
        visible: MediaService.hasPlayer
        width: parent.width; spacing: 14
        ClippingRectangle {
            width: 84; height: 84; radius: Theme.radiusControl; color: Theme.surface2
            border.width: 1; border.color: Theme.border
            Image { id: art; anchors.fill: parent; source: MediaService.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(168, 168); visible: !UserConfig.data.appearance.grayscaleArtwork && status === Image.Ready }
            MultiEffect { anchors.fill: parent; source: art; saturation: -1; visible: UserConfig.data.appearance.grayscaleArtwork && art.status === Image.Ready }
            MonoIcon { anchors.centerIn: parent; name: "music"; size: 26; color: Theme.textDisabled; visible: art.status !== Image.Ready }
        }
        Column { width: parent.width - 98; anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Label { text: MediaService.title || "Unknown title"; font.weight: Font.DemiBold; width: parent.width }
            Label { text: MediaService.artist || "Unknown artist"; secondary: true; font.pixelSize: Theme.fontSm; width: parent.width }
            Label { text: MediaService.album; visible: text !== ""; secondary: true; font.pixelSize: Theme.fontXs; width: parent.width }
            Row { spacing: 6; topPadding: 4
                Label { text: MediaService.playing ? "PLAYING" : (mc.p && mc.p.playbackState === 0 ? "STOPPED" : "PAUSED"); font.pixelSize: Theme.fontXs; font.letterSpacing: 1.2; color: Theme.silverMuted }
                Label { text: "· " + MediaService.playerName; font.pixelSize: Theme.fontXs; color: Theme.textDisabled } } }
    }
    // Progress (only when the player reports position)
    Item { visible: MediaService.hasPlayer && mc.p && mc.p.lengthSupported && mc.p.length > 0; width: parent.width; height: 14
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; color: Theme.border }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: mc.p && mc.p.length > 0 ? parent.width * Math.min(1, mc.p.position / mc.p.length) : 0; height: 2; color: Theme.silver }
        Timer { interval: 1000; repeat: true; running: MediaService.playing && mc.p && mc.p.positionSupported; onTriggered: mc.p.positionChanged() } }
    Row {
        visible: MediaService.hasPlayer
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
        IconButton { icon: "skip-back"; iconSize: 16; implicitWidth: 36; implicitHeight: 32; enabled: mc.p && mc.p.canGoPrevious; onClicked: MediaService.previous() }
        Rectangle { width: 48; height: 32; radius: Theme.radiusControl; color: pma.containsMouse ? Theme.silverBright : Theme.silver; opacity: mc.p && mc.p.canTogglePlaying ? 1 : 0.4
            MonoIcon { anchors.centerIn: parent; name: MediaService.playing ? "pause" : "play"; size: 16; color: Theme.inverse }
            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MediaService.toggle() } }
        IconButton { icon: "skip-forward"; iconSize: 16; implicitWidth: 36; implicitHeight: 32; enabled: mc.p && mc.p.canGoNext; onClicked: MediaService.next() }
        IconButton { icon: "arrow-right"; iconSize: 14; implicitWidth: 32; implicitHeight: 32; enabled: mc.p && mc.p.canRaise; tooltip: "Open player"; onClicked: { MediaService.raise(); ShellState.close() } }
    }
}
