import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
 FileView{id:main;path:'/home/jorj/.config/niri/config.kdl';blockAllReads:true;printErrors:false}
 FileView{id:input;path:'/home/jorj/.config/niri/input.kdl';blockAllReads:true;printErrors:false}
 FileView{id:binds;path:'/home/jorj/.config/niri/binds.kdl';blockAllReads:true;printErrors:false}
 FileView{id:shell;path:'/home/jorj/.config/niri/niri-monochrome.kdl';blockAllReads:true;printErrors:false}
 Timer{interval:1000;running:true;onTriggered:{
  ShortcutService.load(input.text(),'input');ShortcutService.load(binds.text(),'external');ShortcutService.load(shell.text(),'generated');ShortcutService.load(main.text(),'main')
  const rows=ShortcutService.entries;const categories={};for(const r of rows)categories[r.category]=(categories[r.category]||0)+1
  console.info('LIVE_REGISTRY '+JSON.stringify({total:rows.length,unique:new Set(rows.map(e=>ShortcutService.canonical(e.key))).size,categories:categories,mod:ShortcutService.modKey,comma:rows.find(e=>e.key==='Mod+Comma'),scope:ShortcutService.scopeNote}))
  console.info('QMLCHECK DONE');Qt.quit()
 }}
}
