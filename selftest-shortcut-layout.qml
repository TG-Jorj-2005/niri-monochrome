import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.config
import qs.services
import qs.components.popovers
ShellRoot {
 id:root
 property int passed:0
 property int failed:0
 function check(n,ok){if(ok)passed++;else failed++;console.info((ok?'PASS ':'FAIL ')+n)}
 function all(i,p){let r=[];if(p(i))r.push(i);for(const c of i.children||[])r=r.concat(all(c,p));return r}
 Window {id:window;visible:true;width:860;height:600
  Rectangle {id:scene;anchors.fill:parent;color:'#808080'
   ShortcutCheatSheet {id:sheet;anchors.centerIn:parent;width:Math.min(820,parent.width-24);height:Math.min(560,parent.height-24)}
  }
 }
 TestCase{id:events;parent:scene;when:false;optional:true}
 function examine(name) {
  events.wait(100)
  const list=root.all(sheet,x=>typeof x.positionViewAtIndex==='function')[0];list.forceLayout();events.wait(100)
  const image=events.grabImage(scene)
  if(Quickshell.env('NM_SHORTCUT_EVIDENCE'))image.save(Quickshell.env('NM_SHORTCUT_EVIDENCE')+'/'+name+'.png')
  const keys=root.all(list,x=>x.mono===true&&x.font&&x.font.pixelSize===Theme.fontSm)
  root.check(name+' keycaps stay within the sheet',keys.length>0&&keys.every(x=>{const p=x.mapToItem(sheet,0,0);return p.x>=0&&p.x+x.width<=sheet.width+1&&!x.truncated}))
  const footer=root.all(sheet,x=>typeof x.text==='string'&&x.text.startsWith('Informational'))[0]
  const fp=footer.mapToItem(sheet,0,0),lp=list.mapToItem(sheet,0,0)
  root.check(name+' content and footer remain bounded',fp.y>=lp.y+list.height-1&&fp.y+footer.height<=sheet.height+1&&list.contentHeight>list.height)
 }
 Timer{interval:800;running:true;onTriggered:{
  ShortcutService.mainTree=null;ShortcutService.external=[];ShortcutService.generated=[]
  for(let i=0;i<60;i++)ShortcutService.external.push({key:'Mod+Ctrl+Alt+Shift+ISO_Level3_Shift+ISO_Level5_Shift+XF86MonBrightnessDown',label:'Long description with an intentionally lengthy application title '+i,category:'Applications',description:'spawn "example application with a long argument"'})
  // Distinct symbols for the remaining rows; the first long key represents one real combination.
  ShortcutService.external=ShortcutService.external.map((e,i)=>i===0?e:({key:'Mod+F'+i,label:'Other action '+i,category:'Applications',description:'spawn "example"'}))
  root.examine('normal');small.start()
 }}
 Timer{id:small;interval:100;onTriggered:{window.width=640;window.height=480;smallCheck.start()}}
 Timer{id:smallCheck;interval:150;onTriggered:{root.examine('small');narrow.start()}}
 Timer{id:narrow;interval:100;onTriggered:{window.width=384;window.height=480;narrowCheck.start()}}
 Timer{id:narrowCheck;interval:150;onTriggered:{root.examine('narrow');console.info('RESULT '+root.passed+'/'+(root.passed+root.failed)+' passed');Qt.quit()}}
}
