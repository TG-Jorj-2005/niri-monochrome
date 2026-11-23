pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
Singleton {
    id: appearance
    readonly property string path: Constants.niriConfigDir + "/niri-monochrome-appearance.kdl"
    property string lastWritten: ""
    function text() {
        const a = UserConfig.data.appearance
        const alpha = Math.round(a.shadowStrength*255).toString(16).padStart(2,"0")
        let result = "// Generated bounded effects; no full-screen overlay blur.\n"
        for (const name of ["bar", "dock"]) {
            result += 'layer-rule {\n    match namespace="^nm-' + name + '$"\n    geometry-corner-radius ' + (name === "bar" ? UserConfig.data.bar.radius : a.panelRadius) + '\n    background-effect {\n        blur ' + a.glassEnabled + '\n        saturation 0\n        noise 0.01\n    }\n    shadow {\n        on\n        softness 12\n        spread 1\n        offset x=0 y=3\n        color "#000000' + alpha + '"\n    }\n}\n'
        }
        return result
    }
    function write() {
        if (!UserConfig.loaded) return
        const next = text()
        if (next === lastWritten) return
        if (writer.text() !== next) writer.setText(next)
        lastWritten = next
    }
    FileView { id: writer; path: appearance.path; blockLoading: true; atomicWrites: true; printErrors: false
        onSaveFailed: Log.warn("Appearance", "Could not save Niri appearance include") }
    Timer { id: debounce; interval: 200; onTriggered: appearance.write() }
    Connections { target: UserConfig; function onChanged() { debounce.restart() } function onLoadedChanged() { debounce.restart() } }
    Component.onCompleted: debounce.restart()
}
