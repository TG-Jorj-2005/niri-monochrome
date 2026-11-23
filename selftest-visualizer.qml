import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.ui

// Deterministic actual-component tests. Real transport/reload uses visualizer-live.qml.
ShellRoot {
    id: root
    property int passed: 0
    property int failed: 0
    property var fixture: null
    function check(name, ok) { if (ok) passed++; else failed++; console.info((ok ? "PASS " : "FAIL ") + name) }
    Window {
        id: window
        visible: true; width: 420; height: 420
        color: Theme.background
    }
    Component { id: basic; Item {
        width: 340; height: 68
        property alias viz: viz
        AudioVisualizer { id: viz; anchors.fill: parent }
    } }
    TestCase { id: events; parent: window.contentItem; when: false; optional: true }
    Timer { interval: 1100; running: true; onTriggered: {
        // Prevent actual hardware capture in deterministic tests. Real transport is tested separately.
        VisualizerService.installed = false
        root.check("target follows actual default AudioService sink", VisualizerService.target === (AudioService.sink ? AudioService.sink.name : ""))
        root.fixture = basic.createObject(window.contentItem)
        const v = root.fixture.viz
        root.check("closed visualizer has no subscription", VisualizerService.watchers === 0 && !VisualizerService.running)
        v.active = true
        root.check("visible activation subscribes exactly once", VisualizerService.watchers === 1 && v.subscribed)
        v.sync(); v.sync()
        root.check("repeated sync cannot duplicate subscription", VisualizerService.watchers === 1)
        root.fixture.visible = false
        root.check("ancestor hiding releases subscription", VisualizerService.watchers === 0 && !v.wanted)
        UserConfig.set("media.visualizerEnabled", false)
        UserConfig.set("media.visualizerEnabled", true)
        root.check("hidden reenable cannot capture", VisualizerService.watchers === 0 && !VisualizerService.running)
        root.fixture.visible = true
        UserConfig.set("media.visualizerEnabled", false)
        root.check("disable releases visible subscription", VisualizerService.watchers === 0)
        UserConfig.set("media.visualizerEnabled", true)
        root.check("reenable visible view restores one subscription", VisualizerService.watchers === 1)
        VisualizerService.amplitude = 0; VisualizerService.levels = []
        VisualizerService.consume("0.5"); VisualizerService.consume("0.5"); VisualizerService.consume("0")
        root.check("attack release smoothing deterministic", Math.abs(VisualizerService.amplitude - 0.3290625) < 0.000001)
        const previous = JSON.stringify(VisualizerService.levels)
        for (const line of ["", " ", "NaN", "Infinity", "-0.1", "1.1", "garbage", "9".repeat(100)]) VisualizerService.consume(line)
        root.check("invalid amplitudes do not change history", JSON.stringify(VisualizerService.levels) === previous)
        for (let i = 0; i < 80; i++) VisualizerService.consume("0")
        root.check("silence reaches exact calm state", VisualizerService.amplitude === 0 && VisualizerService.levels.every(x => x === 0))
        for (let i = 0; i < 200; i++) VisualizerService.consume(i % 2 ? "1" : "0")
        root.check("history and values remain bounded", VisualizerService.levels.length === v.count && VisualizerService.levels.every(x => x >= 0 && x <= 1))
        UserConfig.set("appearance.reduceMotion", true); events.wait(80)
        const row = v.children.find(c => c.spacing === 3)
        const bars = row.children.filter(c => c.amount !== undefined)
        root.check("reduced motion renders bounded actual bars", !Theme.motionEnabled && bars.length === v.count && bars.every(c => c.children[0].height >= 2 && c.children[0].height <= c.height))
        v.active = false
        root.fixture.destroy(); events.wait(30)
        for (let i = 0; i < 20; i++) {
            const item = basic.createObject(window.contentItem)
            item.viz.active = true; item.destroy(); events.wait(1)
        }
        // QObject.destroy() is deferred until the current event handler returns.
        finish.start()
    } }
    Timer { id: finish; interval: 100; onTriggered: {
        root.check("destroyed views release all subscriptions", VisualizerService.watchers === 0 && !VisualizerService.running)
        console.info("RESULT " + root.passed + "/" + (root.passed + root.failed) + " passed")
        Qt.quit()
    } }
}
