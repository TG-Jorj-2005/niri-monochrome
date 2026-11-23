pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
Singleton {
    id: spectrum
    property int watchers: 0
    property bool installed: false
    property bool cooling: false
    property int attempts: 0
    property bool stopExpected: false
    property string status: "initializing"
    property real amplitude: 0
    property var levels: []
    readonly property string target: AudioService.sink ? AudioService.sink.name : ""
    readonly property bool desired: watchers > 0 && UserConfig.data.media.visualizerEnabled && AudioService.ready && target !== "" && installed
    readonly property bool running: recorder.running
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../scripts/audio-levels.py").toString().replace(/^file:\/\//,""))
    Process { command:["sh","-c","command -v pw-cat >/dev/null && command -v python3 >/dev/null"]; running:true; onExited: code => { spectrum.installed=code===0; spectrum.status=code===0?"idle":"unavailable" } }
    function consume(line) {
        if (line.length>16) return
        const v=Number(line)
        if (!isFinite(v) || v<0 || v>1 || line.trim()==="") return
        amplitude = v === 0 && amplitude < 0.01 ? 0 : amplitude + (v-amplitude)*(v>amplitude?0.65:0.25)
        levels=levels.concat([amplitude]).slice(-UserConfig.data.media.visualizerBarCount)
        status="ready"
        if (recorder.running) freshness.restart()
    }
    onDesiredChanged: {
        freshness.stop()
        if (!desired && recorder.running) stopExpected=true
        retry.stop(); cooling=false; attempts=0
        if (!desired) { levels=[]; amplitude=0; status=installed?"idle":"unavailable" }
        else status="initializing"
    }
    onTargetChanged: if (desired) { cooling=true; attempts=0; retry.restart() }
    Process {
        id: recorder
        command:["python3",spectrum.helper,spectrum.target]
        running:spectrum.desired && !spectrum.cooling
        onStarted: spectrum.status="listening"
        stdout:SplitParser { onRead: line => spectrum.consume(line) }
        onExited: {
            freshness.stop()
            if (spectrum.stopExpected) {
                spectrum.stopExpected=false
                spectrum.cooling=true
                Qt.callLater(() => spectrum.cooling=false)
                return
            }
            if (spectrum.desired) {
                spectrum.status="unavailable"; spectrum.cooling=true; spectrum.amplitude=0; spectrum.levels=[]
                spectrum.attempts++
                if (spectrum.attempts<=3) retry.restart()
            }
        }
    }
    // Passive/suspended sinks can stop producing PCM without closing the stream.
    // Expire stale display state once; never manufacture samples or poll while idle.
    Timer { id:freshness; interval:750; onTriggered: {
        if (spectrum.desired && recorder.running) {
            spectrum.amplitude=0; spectrum.levels=[]; spectrum.status="listening"
        }
    } }
    Timer { id:retry; interval:2000; onTriggered: if(spectrum.desired) spectrum.cooling=false }
}
