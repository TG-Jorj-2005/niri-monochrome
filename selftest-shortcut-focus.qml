import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.services
import qs.components
ShellRoot {
 id:root
 function find(i,p){if(p(i))return i;for(const c of i.children||[]){const x=find(c,p);if(x)return x}return null}
 OverlayLayer{id:overlay;modelData:Quickshell.screens[0];mask:Region {}}
 TestCase{id:events;parent:overlay.contentItem;when:false;optional:true}
 Timer{interval:800;running:true;onTriggered:{ShellState.show('shortcuts',Quickshell.screens[0].name);observe.start()}}
 Timer{id:observe;interval:50;repeat:true;property int attempts:0;onTriggered:{
  const input=root.find(overlay.contentItem,x=>x.echoMode!==undefined)
  const window=input?input.Window.window:null
  if((!input||!window||!window.active)&&attempts++<60)return
  stop()
  const focused=input&&input.activeFocus
  console.info('NATIVE_FOCUS '+JSON.stringify({windowActive:window?window.active:false,inputFocus:input?input.focus:false,inputActive:!!focused,waitTicks:attempts}))
  events.keyClick(Qt.Key_T)
  const ok=!!focused&&input.text==='t'
  console.info((ok?'PASS ':'FAIL ')+'search focus after native window activation')
  console.info('RESULT '+(ok?1:0)+'/1 passed');Qt.quit()
 }}
}
