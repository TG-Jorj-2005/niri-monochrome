import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components.ui
ShellRoot {
    id: root
    property int passed:0
    property bool activeVisualizer:false
    function check(name,ok) { if(ok) passed++; console.info((ok?"PASS ":"FAIL ")+name) }
    AudioVisualizer { id:viz; width:300; active:root.activeVisualizer }
    Timer { interval:1500; running:true; onTriggered:{
        let d=UserConfig.deepClone(UserConfig.data)
        d.appearance.panelOpacity=0; d.appearance.panelRadius=100;d.media.visualizerBarCount=100;d.media.visualizerStyle="fake"
        d=UserConfig.validate(d)
        root.check("safe appearance and visualizer ranges",d.appearance.panelOpacity===0.82 && d.appearance.panelRadius===24 && d.media.visualizerBarCount===32 && d.media.visualizerStyle==="history")
        d.appearance.reduceMotion=true; UserConfig.data=d
        root.check("reduced motion gates centralized durations",!Theme.motionEnabled && Theme.durFast===0 && Theme.motionIntensity===0)
        const base=ShortcutService.parse('    Mod+Comma { consume-window-into-column; }\n    Mod+Shift+Slash { show-hotkey-overlay; }\n// Mod+Z { quit; }',false)
        const generated=ShortcutService.parse('Mod+Comma hotkey-overlay-title="Settings" { spawn "qs"; }',true)
        const combined=ShortcutService.combine(base,generated)
        root.check("later bindings override without duplicate rows",combined.length===2 && combined.some(x=>x.label==="Settings"))
        root.check("occupied native shortcut is retained",combined.some(x=>x.key==="Mod+Shift+Slash" && x.description==="show-hotkey-overlay"))
        ShortcutService.external=base;ShortcutService.generated=generated
        root.check("shortcut action and key filtering",ShortcutService.filter("settings","All").length===1 && ShortcutService.filter("slash","All").length===1)
        VisualizerService.installed=false
        root.activeVisualizer=true
        root.check("missing backend cannot start capture",!VisualizerService.running && !VisualizerService.desired)
        root.activeVisualizer=false
        root.check("hidden visualizer releases subscription",VisualizerService.watchers===0)
        let off=UserConfig.deepClone(UserConfig.data);off.media.visualizerEnabled=false;UserConfig.data=off
        root.activeVisualizer=true
        root.check("disabled visualizer cannot subscribe",VisualizerService.watchers===0 && !VisualizerService.running)
        const old=VisualizerService.levels.length
        VisualizerService.consume("NaN");VisualizerService.consume("9".repeat(30))
        root.check("invalid audio frames ignored",VisualizerService.levels.length===old)
        for(let i=0;i<100;i++) VisualizerService.consume("0.3")
        root.check("audio history bounded by bar count",VisualizerService.levels.length===UserConfig.data.media.visualizerBarCount)
        console.info("RESULT "+root.passed+"/10 passed"); Qt.quit()
    } }
}
