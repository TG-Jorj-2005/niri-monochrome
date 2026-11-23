import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components
import qs.components.ui
ShellRoot {
    id: root
    property int passed: 0
    property int failed: 0
    property var controls: null
    function check(name,ok) { if(ok)passed++;else failed++; console.info((ok?"PASS ":"FAIL ")+name) }
    function find(item,predicate) { if(!item)return null; if(predicate(item))return item; for(const child of item.children||[]) { const found=find(child,predicate);if(found)return found } return null }
    function sheet() { return find(overlay.contentItem,item=>typeof item.navigate==="function" && item.category!==undefined) }
    OverlayLayer { id:overlay; modelData:Quickshell.screens[0]; mask:Region {}
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None }
    TestCase { id:events; parent:overlay.contentItem; when:false; optional:true }
    FileView { id:saved; path:UserConfig.path; blockAllReads:true; printErrors:false }
    Component {
        id:fixtures
        Item {
            id:mock
            width:650;height:54
            property int clicks:0
            property int iconClicks:0
            property int flips:0
            property bool state:false
            property real backend:0.4
            property alias button:button
            property alias icon:icon
            property alias toggle:toggle
            property alias slider:slider
            Row { spacing:12
                MonoButton { id:button; text:"Test button"; onClicked:mock.clicks++ }
                IconButton { id:icon; icon:"check"; onClicked:mock.iconClicks++ }
                MonoToggle { id:toggle; checked:mock.state; onToggled:on=>{mock.state=on;mock.flips++} }
                MonoSlider { id:slider; width:180; value:mock.backend; onMoved:v=>mock.backend=v }
            }
        }
    }
    Timer { interval:1200;running:true;onTriggered:ShellState.show("shortcuts",Quickshell.screens[0].name) }
    Timer { interval:2000;running:true;onTriggered:{
        const pane=root.sheet()
        if(!pane){root.check("overlay ready",false);Qt.quit();return}
        root.controls=fixtures.createObject(pane,{x:20,y:pane.height-118})
        const c=root.controls
        events.wait(120) // allow the dynamically injected fixture Row to polish
        events.mouseMove(overlay.contentItem,2,2);events.wait(30)
        events.mouseMove(c.button,c.button.width/2,c.button.height/2);events.wait(80)
        root.check("button hover feedback",c.button.hovered)
        events.mouseClick(c.button,c.button.width/2,c.button.height/2)
        root.check("button click fires exactly once inside overlay",c.clicks===1 && ShellState.open==="shortcuts")
        events.mousePress(c.button,8,8);events.wait(130)
        root.check("press feedback compresses without layout change",c.button.scale<1 && c.button.width===c.button.implicitWidth)
        events.mouseRelease(c.button,8,8);events.wait(130)
        root.check("release returns scale and fires once",Math.abs(c.button.scale-1)<0.001 && c.clicks===2)
        c.button.enabled=false
        events.mouseClick(c.button,8,8)
        root.check("disabled button rejects pointer action",c.clicks===2 && ShellState.open==="shortcuts")
        c.button.enabled=true
        events.mouseClick(c.toggle,c.toggle.width/2,c.toggle.height/2)
        root.check("toggle click fires once without dismissal",c.state && c.flips===1 && ShellState.open==="shortcuts")
        events.mousePress(c.slider,30,12);events.mouseMove(c.slider,120,12);events.mouseRelease(c.slider,120,12);events.wait(120)
        root.check("slider drag updates backend without dismissal",c.backend>0.6 && c.backend<0.8 && ShellState.open==="shortcuts")
        c.backend=0.25;events.wait(110)
        root.check("slider external updates retain binding",Math.abs(c.slider.value-0.25)<0.001 && Math.abs(c.slider.frac-0.25)<0.001)
        // Keyboard checks follow pointer checks, with all actions restricted to mock counters.
        c.button.forceActiveFocus();events.keyClick(Qt.Key_Tab)
        root.check("Tab moves to next button",c.icon.activeFocus)
        events.keyClick(Qt.Key_Tab)
        root.check("Tab reaches toggle",c.toggle.activeFocus)
        events.keyClick(Qt.Key_Tab)
        root.check("Tab reaches slider",c.slider.activeFocus)
        events.keyClick(Qt.Key_Backtab,Qt.ShiftModifier)
        root.check("Shift Tab restores previous control focus",c.toggle.activeFocus)
        c.button.forceActiveFocus();let count=c.clicks
        events.keyClick(Qt.Key_Space);events.keyClick(Qt.Key_Return);events.keyClick(Qt.Key_Enter)
        root.check("button Space Return Enter fire once each",c.clicks===count+3)
        c.icon.forceActiveFocus();events.keyClick(Qt.Key_Return)
        root.check("icon button keyboard activation",c.iconClicks===1)
        c.toggle.forceActiveFocus();let flips=c.flips
        events.keyClick(Qt.Key_Space);events.keyClick(Qt.Key_Return)
        root.check("toggle Space and Return activation",c.flips===flips+2)
        flips=c.flips;events.keyClick(Qt.Key_Enter)
        root.check("toggle keypad Enter activation",c.flips===flips+1)
        c.slider.forceActiveFocus();c.backend=0.5
        events.keyClick(Qt.Key_Right)
        root.check("slider Right keyboard step",Math.abs(c.backend-0.55)<0.001)
        events.keyClick(Qt.Key_Home);root.check("slider Home bound",c.backend===0)
        events.keyClick(Qt.Key_End);root.check("slider End bound",c.backend===1)
        c.toggle.enabled=false;flips=c.flips;events.mouseClick(c.toggle,8,8)
        root.check("disabled toggle rejects input",c.flips===flips)
        c.toggle.enabled=true
        c.slider.enabled=false;const old=c.backend;events.mouseClick(c.slider,20,12)
        root.check("disabled slider rejects input",c.backend===old)
        c.slider.enabled=true
        UserConfig.set("appearance.reduceMotion",true)
        events.wait(40)
        root.check("reduced motion applies without reload",!Theme.motionEnabled && Theme.durFast===0)
        events.mousePress(c.button,8,8);events.wait(30)
        root.check("reduced motion keeps immediate press feedback",c.button.scale===1)
        events.mouseRelease(c.button,8,8)
        events.wait(650);saved.reload()
        const persisted=JSON.parse(saved.text())
        root.check("reduced motion persists as valid config",persisted.appearance.reduceMotion===true)
        for(let i=0;i<8;i++){ShellState.close();ShellState.show("shortcuts",Quickshell.screens[0].name)}
        root.check("rapid open close keeps latest overlay state",ShellState.open==="shortcuts" && overlay.visible)
        ShellState.close();events.wait(40)
        root.check("reduced motion dismissal releases surface",!overlay.visible && !overlay.active)
        console.info("RESULT "+root.passed+"/"+(root.passed+root.failed)+" passed");Qt.quit()
    } }
}
