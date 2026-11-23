import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components
ShellRoot {
 id:root
 property int passed:0
 property int failed:0
 function check(n,ok){if(ok)passed++;else failed++;console.info((ok?"PASS ":"FAIL ")+n)}
 function find(item,test){if(!item)return null;if(test(item))return item;for(const c of item.children||[]){const f=find(c,test);if(f)return f}return null}
 function all(item,test){let r=[];if(test(item))r.push(item);for(const c of item.children||[])r=r.concat(all(c,test));return r}
 function pane(){return find(overlay.contentItem,x=>typeof x.navigate==='function'&&x.category!==undefined)}
 function input(){return find(pane(),x=>x.echoMode!==undefined&&x.cursorPosition!==undefined)}
 function open(){ShellState.show('shortcuts',Quickshell.screens[0].name)}
 OverlayLayer {id:overlay;modelData:Quickshell.screens[0];mask:Region {}
  WlrLayershell.keyboardFocus:WlrKeyboardFocus.None }
 Settings {id:settings;visible:false}
 TestCase {id:events;parent:overlay.contentItem;when:false;optional:true}
 FileView {id:mainFile;path:Constants.niriConfigDir+'/config.kdl';blockAllReads:true;atomicWrites:true;printErrors:false}
 FileView {id:bindFile;path:Constants.niriConfigDir+'/binds.kdl';blockAllReads:true;atomicWrites:true;printErrors:false}
 FileView {id:generatedFile;path:Keybindings.includePath;blockAllReads:true;atomicWrites:true;printErrors:false}
 function source(){let s='binds {\n';for(let i=0;i<90;i++)s+='Mod+Shift+Ctrl+ISO_Level3_Shift+'+(i>=70?'ISO_Level5_Shift+':i>=35?'Alt+':'')+'F'+(i%35+1)+' hotkey-overlay-title="Example '+i+'" { spawn "app-'+i+'"; }\n';return s+'Mod+Return hotkey-overlay-title="Terminal [work]" { spawn "alacritty"; }\n}'}
 Timer {interval:1100;running:true;onTriggered:{
  mainFile.setText('include "binds.kdl"\ninclude "niri-monochrome.kdl"\n')
  bindFile.setText(root.source());generatedFile.setText('binds { Mod+D hotkey-overlay-title="Generated launcher" { spawn "qs"; }; }\n')
  events.wait(350);ShortcutService.refresh();events.wait(200)
  root.check('actual supported source files loaded without duplicate keys',ShortcutService.entries.length===92)
  root.open();events.wait(250)
  events.mouseClick(root.input(),8,root.input().height/2)
  root.check('synthetic search focus in pass-through overlay',root.input().activeFocus)
  events.keyClick(Qt.Key_T);events.wait(20)
  root.check('typing retains search focus and filters locally',root.input().text==='t'&&root.input().activeFocus&&root.pane().results.length>0)
  root.input().text='[work]';events.wait(40)
  root.check('special-character query shows correct row',root.pane().results.length===1&&root.pane().results[0].label==='Terminal [work]')
  const old=ShellState.open
  events.keyClick(Qt.Key_Return);events.keyClick(Qt.Key_Enter)
  root.check('Return and keypad Enter never execute informational rows',ShellState.open===old)
  root.input().text='';events.keyClick(Qt.Key_Tab);events.wait(40)
  const cat=root.find(root.pane(),x=>x.text==='All'&&typeof x.clicked==='function')
  root.check('Tab reaches category controls',cat.activeFocus)
  events.keyClick(Qt.Key_Backtab,Qt.ShiftModifier)
  root.check('Shift Tab returns to search',root.input().activeFocus)
  const apps=root.find(root.pane(),x=>x.text==='Applications'&&typeof x.clicked==='function')
  events.mouseClick(apps,8,8);events.wait(30)
  root.check('pointer category selection filters actual entries',root.pane().category==='Applications'&&root.pane().results.every(e=>e.category==='Applications'))
  apps.forceActiveFocus();events.keyClick(Qt.Key_Return);events.keyClick(Qt.Key_Enter);events.keyClick(Qt.Key_Space)
  root.check('category Return Enter Space remain safe',ShellState.open==='shortcuts'&&root.pane().category==='Applications')
  events.mouseClick(root.input(),8,root.input().height/2)
  root.check('pointer click restores search focus',root.input().activeFocus)
  root.input().text='nothing matches .*';events.wait(30);events.keyClick(Qt.Key_Down);events.keyClick(Qt.Key_Up)
  const empty=root.find(root.pane(),x=>x.text==='No matching shortcuts')
  root.check('empty result navigation remains bounded and legible',root.pane().results.length===0&&root.pane().selected===0&&empty.visible)
  root.input().text='';root.pane().category='All';events.wait(50)
  events.keyClick(Qt.Key_Down);root.check('Down selects next filtered row',root.pane().selected===1)
  events.keyClick(Qt.Key_Up);root.check('Up selects previous filtered row',root.pane().selected===0)
  const list=root.find(root.pane(),x=>typeof x.positionViewAtIndex==='function')
  list.forceLayout();events.wait(160)
  const before=list.contentY;events.mouseWheel(list,list.width/2,list.height/2,0,-720);events.wait(150)
  root.check('long result list scrolls without dismissal',list.contentY>before&&ShellState.open==='shortcuts')
  events.mouseClick(root.pane(),8,root.pane().height-8)
  root.check('inside padding preserves Task 1 shield',ShellState.open==='shortcuts')
  root.input().forceActiveFocus();events.keyClick(Qt.Key_Escape);events.wait(160)
  root.check('Escape dismisses actual overlay',ShellState.open==='')
  root.open();events.wait(250)
  root.pane().implicitWidth=616;root.pane().implicitHeight=456;events.wait(100)
  const sheet=root.pane();const smallList=root.find(sheet,x=>typeof x.positionViewAtIndex==='function')
  smallList.positionViewAtBeginning();events.wait(100)
  const keys=root.all(smallList,x=>x.mono===true&&x.font&&x.font.pixelSize===Theme.fontSm)
  root.check('small viewport keeps keycaps inside panel',sheet.width<=616&&keys.length>0&&keys.every(x=>{const p=x.mapToItem(sheet,0,0);return p.x>=0&&p.x+x.width<=sheet.width+1&&x.truncated===false}))
  const footer=root.find(sheet,x=>typeof x.text==='string'&&x.text.startsWith('Informational'))
  const fp=footer.mapToItem(sheet,0,0)
  root.check('small viewport footer and list never overlap or escape',fp.y>=smallList.y+smallList.height-1&&fp.y+footer.height<=sheet.height+1)
  events.wait(60)
  root.pane().implicitWidth=820;root.pane().implicitHeight=560;events.wait(100)
  events.wait(60)
  // File change and deletion use only this runner's private Niri directory.
  bindFile.setText('binds { Mod+T hotkey-overlay-title="Updated application" { spawn "changed"; }; }\n');events.wait(450)
  root.check('atomic source update immediately refreshes open sheet',ShortcutService.entries.some(e=>e.label==='Updated application')&&!ShortcutService.entries.some(e=>e.label==='Terminal [work]'))
  const remove=Qt.createQmlObject('import Quickshell.Io; Process {}',root)
  remove.command=['rm','--',Constants.niriConfigDir+'/binds.kdl'];remove.running=true;events.wait(350)
  root.check('removed source never leaves stale shortcuts',!ShortcutService.entries.some(e=>e.label==='Updated application'))
  remove.destroy()
  bindFile.setText('binds { Mod+T hotkey-overlay-title="Restored" { spawn "changed"; }; }\n');events.wait(450)
  ShortcutService.refresh();events.wait(150)
  root.check('recreated source restored on supported refresh',ShortcutService.entries.some(e=>e.label==='Restored'))
  generatedFile.setText('binds { Mod+T hotkey-overlay-title="Override" { spawn "qs"; }; }\n');events.wait(400)
  root.check('generated file change applies effective override once',ShortcutService.entries.length===1&&ShortcutService.entries[0].label==='Override')
  mainFile.setText('include "niri-monochrome.kdl"\ninclude "binds.kdl"\n');events.wait(400)
  root.check('main include order governs effective supported override',ShortcutService.entries.length===1&&ShortcutService.entries[0].label==='Restored')
  UserConfig.set('shortcuts.writeNiriInclude',true);UserConfig.set('shortcuts.launcher','Mod+F12');events.wait(500)
  root.check('settings change refreshes actual generated include',ShortcutService.entries.some(e=>e.key==='Mod+F12'&&e.label==='Application launcher'))
  UserConfig.set('shortcuts.launcher','');events.wait(450)
  root.check('disabled shell binding disappears after file regeneration',!ShortcutService.entries.some(e=>e.key==='Mod+F12'))
  ShellState.close();events.wait(200)
  const index=settings.sections.findIndex(x=>x.t==='Shortcuts');ShellState.settingsSection=index;events.wait(150)
  const button=root.find(settings.contentItem,x=>x.text==='Open cheat sheet')
  ShellState.settingsOpen=true;button.clicked();events.wait(200)
  root.check('actual Settings shortcut button opens overlay and closes Settings state',ShellState.open==='shortcuts'&&!ShellState.settingsOpen)
  ShellState.show('control',Quickshell.screens[0].name);events.wait(200)
  const keyboard=root.find(overlay.contentItem,x=>x.tooltip==='Keyboard Shortcuts')
  events.mouseClick(keyboard,8,8);events.wait(250)
  root.check('Control Center keyboard button transitions to cheat sheet',ShellState.open==='shortcuts'&&root.input().activeFocus)
  UserConfig.set('appearance.reduceMotion',true)
  rapid.start()
 } }
 Timer {id:rapid;interval:40;repeat:true;property int remaining:8;onTriggered:{
  if(remaining>0){ShellState.close();root.open();remaining--;return}
  stop();finish.start()
 } }
 Timer {id:finish;interval:120;onTriggered:{
  root.check('rapid reduced-motion reopen retains one sheet',ShellState.open==='shortcuts'&&root.all(overlay.contentItem,x=>typeof x.navigate==='function').length===1)
  const close=root.find(root.pane(),x=>x.tooltip==='Close')
  events.mouseClick(close,8,8);events.wait(30)
  root.check('close button dismisses without opening another overlay',ShellState.open==='')
  root.open();events.wait(100);events.mouseClick(overlay.contentItem,2,2)
  root.check('outside click dismisses and releases overlay',ShellState.open===''&&!overlay.visible)
  console.info('RESULT '+root.passed+'/'+(root.passed+root.failed)+' passed');Qt.quit()
 } }
}
