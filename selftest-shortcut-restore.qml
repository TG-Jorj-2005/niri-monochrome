import QtQuick
import Quickshell
import qs.services
ShellRoot {
 Component.onCompleted: ShortcutService.refresh()
 Timer{interval:1000;running:true;onTriggered:{
  const rows=ShortcutService.entries
  const ok=rows.some(e=>e.key==='Mod+T'&&e.label==='Restored')&&!rows.some(e=>e.key==='Mod+F12')&&new Set(rows.map(e=>ShortcutService.canonical(e.key))).size===rows.length
  console.info((ok?'PASS ':'FAIL ')+'new process restores supported registry after settings/source updates')
  console.info('RESULT '+(ok?1:0)+'/1 passed');Qt.quit()
 }}
}
