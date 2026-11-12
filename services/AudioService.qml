pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire audio: default sink/source volume, mute, device selection.
Singleton {
    id: audio

    readonly property bool ready: Pipewire.ready
    readonly property string status: !ready ? "initializing" : (sink ? "ready" : "unavailable")
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property string sinkName: sink ? (sink.description || sink.nickname || sink.name) : "No output"
    readonly property string sourceName: source ? (source.description || source.nickname || source.name) : "No input"

    // Keep the default nodes bound so their properties are tracked.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    // Track all device nodes (not streams) for the output/input pickers.
    PwObjectTracker { objects: audio.sinks.concat(audio.sources) }

    readonly property var sinks: Pipewire.nodes.values.filter(n => n && n.isSink && !n.isStream && (n.type & PwNodeType.Audio))
    readonly property var sources: Pipewire.nodes.values.filter(n => n && !n.isSink && !n.isStream && (n.type & PwNodeType.Audio) && !(n.properties && n.properties["media.class"] === "Audio/Sink"))

    function setVolume(v) { if (sink && sink.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1.5, v)) } }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
    function setMicVolume(v) { if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1.5, v)) }
    function toggleMicMute() { if (source && source.audio) source.audio.muted = !source.audio.muted }
    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node }
    function step(delta) { setVolume(volume + delta) }

    function iconName() {
        if (!sink || muted || volume <= 0) return "volume-x"
        if (volume < 0.34) return "volume"
        if (volume < 0.67) return "volume-1"
        return "volume-2"
    }
    function label(node) { return node ? (node.description || node.nickname || node.name) : "" }
}
