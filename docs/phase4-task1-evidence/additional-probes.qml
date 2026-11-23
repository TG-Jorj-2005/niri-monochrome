import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components.ui
ShellRoot {
    id: root
    property int phase:0
    property int passed:0
    property int failed:0
    property bool request:false
    property bool showViz:true
    property real backend:0.2
    function check(name,ok) { if(ok)passed++;else failed++; console.info((ok?"PASS ":"FAIL ")+name) }
    function enable(on) { const d=UserConfig.deepClone(UserConfig.data);d.media.visualizerEnabled=on;UserConfig.data=d }
    AudioVisualizer { id:visual; width:300; active:root.request; visible:root.showViz }
    MonoSlider { id:slider; value:root.backend; onMoved:v=>root.backend=v }
    Timer { interval:100; repeat:true; running:true; onTriggered:{
        switch(root.phase) {
        case 0:
            if (!UserConfig.loaded || !AudioService.ready || !VisualizerService.installed) return
            root.enable(true);root.request=true;root.phase=1;break
        case 1:
            if (!VisualizerService.running) return
            root.check("enabled requested visualizer starts real backend",VisualizerService.watchers===1)
            root.enable(false);root.phase=2;break
        case 2:
            if (VisualizerService.running) return
            root.check("disabling active visualizer stops backend",VisualizerService.watchers===0 && !VisualizerService.desired)
            root.request=false;root.enable(true);root.phase=3;break
        case 3:
            root.check("re-enable while hidden stays stopped",!VisualizerService.running && VisualizerService.watchers===0)
            root.request=true;root.phase=4;break
        case 4:
            if (!VisualizerService.running) return
            root.showViz=false;root.phase=5;break
        case 5:
            if (VisualizerService.running) return
            root.check("hiding active visualizer stops backend",VisualizerService.watchers===0 && !VisualizerService.desired)
            slider.commit(0.6)
            root.check("slider writes through backend signal",Math.abs(slider.value-0.6)<0.0001)
            root.backend=0.85
            root.check("slider retains external backend binding",Math.abs(slider.value-0.85)<0.0001)
            let d=UserConfig.deepClone(UserConfig.data);d.appearance.reduceMotion=true;d.appearance.glassEnabled=false;UserConfig.data=d
            root.check("reduce motion and opaque fallback remain connected",!Theme.motionEnabled && Theme.durNormal===0 && Theme.surface.a===1)
            console.info("RESULT "+root.passed+"/"+(root.passed+root.failed)+" passed");Qt.quit();root.phase=6;break
        }
    } }
    Timer { interval:12000;running:true;onTriggered:{console.error("FAIL lifecycle probe timeout at phase",root.phase);Qt.quit()} }
}
