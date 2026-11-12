pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.services

// On-screen display for volume / microphone / brightness, driven by real state changes
// (PipeWire properties, brightness writes), regardless of what changed them.
Singleton {
    id: osd
    readonly property bool enabled: UserConfig.data.osd.enabled
    property bool armed: false          // ignore the initial value settle after startup
    property string kind: ""            // volume | mic | brightness
    property real value: 0
    property bool muted: false
    property bool visible: false
    Timer { interval: 3000; running: true; onTriggered: osd.armed = true }
    Timer { id: hide; interval: UserConfig.data.osd.timeout; onTriggered: osd.visible = false }

    function show(k, v, m) {
        if (!enabled || !armed) return
        kind = k; value = v; muted = !!m; visible = true; hide.restart()
    }
    Connections { target: AudioService
        function onVolumeChanged() { osd.show("volume", AudioService.volume, AudioService.muted) }
        function onMutedChanged() { osd.show("volume", AudioService.volume, AudioService.muted) }
        function onMicMutedChanged() { osd.show("mic", AudioService.micVolume, AudioService.micMuted) } }
    Connections { target: BrightnessService
        function onChanged(b, external) { osd.show("brightness", b, false) } }
    function iconName() {
        if (kind === "brightness") return value > 0.5 ? "sun" : "sun-dim"
        if (kind === "mic") return muted ? "mic-off" : "mic"
        if (muted || value <= 0) return "volume-x"
        return value < 0.34 ? "volume" : value < 0.67 ? "volume-1" : "volume-2"
    }
}
