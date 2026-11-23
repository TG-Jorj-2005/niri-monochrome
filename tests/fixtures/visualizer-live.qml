import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.ui
import qs.components.popovers

// Real backend/lifecycle fixture. AudioService selection is replaced only in its private copy.
ShellRoot {
    id: root
    readonly property bool lifecycle: true
    property bool opened: false
    property bool extra: false
    property int frames: 0
    Connections { target: VisualizerService; function onLevelsChanged() { root.frames++ } }
    Window {
        visible: true; width: 420; height: 420; color: Theme.background
        Loader { active: root.opened; sourceComponent: Component { MediaControls { width: 380 } } }
        AudioVisualizer { visible: root.extra; active: root.extra; width: 340 }
    }
    IpcHandler {
        target: "audioTest"
        function state(): string { return JSON.stringify({watchers:VisualizerService.watchers, running:VisualizerService.running, desired:VisualizerService.desired, target:VisualizerService.target, status:VisualizerService.status, amplitude:VisualizerService.amplitude, levels:VisualizerService.levels, attempts:VisualizerService.attempts, frames:root.frames, open:root.opened}) }
        function open(): void { ShellState.open = "media"; root.opened = true }
        function close(): void { ShellState.open = ""; root.opened = false; root.extra = false }
        function enabled(on: bool): void { UserConfig.set("media.visualizerEnabled", on) }
        // Only the private lifecycle fixture has this test replacement of AudioService.
        function select(name: string): void { if (root.lifecycle) AudioService.testTarget = name }
        function available(on: bool): void { if (root.lifecycle) AudioService.ready = on }
        function duplicate(on: bool): void { root.extra = on }
        function appearance(): void { UserConfig.set("appearance.panelOpacity", 0.88); UserConfig.set("appearance.reduceMotion", true) }
        function reload(): void { Quickshell.reload(false) }
        function quit(): void { Qt.quit() }
    }
}
