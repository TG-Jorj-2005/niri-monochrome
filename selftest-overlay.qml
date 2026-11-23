// Qt events are sent only to this isolated test overlay, never to other applications.
import QtQuick
import QtTest
import Quickshell
import qs.services
import qs.components
ShellRoot {
    id: root
    property int passed: 0
    property int failed: 0
    function check(name, ok) { if(ok) passed++; else failed++; console.info((ok ? "PASS " : "FAIL ")+name) }
    function find(item, predicate) {
        if (predicate(item)) return item
        for (const child of item.children || []) { const result=find(child,predicate); if(result) return result }
        return null
    }
    function sheet() { return find(overlay.contentItem, item => typeof item.navigate === "function" && item.category !== undefined) }
    function open() { ShellState.show("shortcuts", Quickshell.screens[0].name) }
    OverlayLayer { id: overlay; modelData: Quickshell.screens[0] }
    TestCase { id: events; parent: overlay.contentItem; when: false; optional: true }
    Timer { interval:1200; running:true; onTriggered:root.open() }
    Timer { interval:2000; running:true; onTriggered:{
        const pane=root.sheet()
        if (!pane) { root.check("shortcut overlay loaded",false);return }
        events.mouseClick(pane,10,pane.height-10,Qt.LeftButton)
        root.check("inside padding preserves overlay",ShellState.open==="shortcuts")
        root.open()
    } }
    Timer { interval:2400; running:true; onTriggered:{
        const button=root.find(root.sheet(),item => item.tooltip === "Close")
        events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton)
        root.check("child close button remains clickable",ShellState.open==="")
        root.open()
    } }
    Timer { interval:2800; running:true; onTriggered:{
        const pane=root.sheet()
        const input=root.find(pane,item => item.echoMode !== undefined && item.cursorPosition !== undefined)
        events.mouseClick(input,10,input.height/2,Qt.LeftButton)
        events.keyClick(Qt.Key_Down)
        root.check("Down navigates shortcut rows",pane.selected===1)
        events.keyClick(Qt.Key_Up)
        root.check("Up navigates shortcut rows",pane.selected===0)
        events.keyClick(Qt.Key_Escape)
        root.check("Escape dismisses overlay",ShellState.open==="")
        root.open()
    } }
    Timer { interval:3300; running:true; onTriggered:{
        events.mouseClick(overlay.contentItem,4,4,Qt.LeftButton)
        root.check("outside click dismisses overlay",ShellState.open==="")
        console.info("RESULT "+root.passed+"/"+(root.passed+root.failed)+" passed")
        Qt.quit()
    } }
}
