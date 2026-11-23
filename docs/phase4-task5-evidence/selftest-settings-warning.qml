import QtQuick
import QtTest
import Quickshell
import qs.services
import qs.components
ShellRoot {
 id:root
 function find(i,p){if(p(i))return i;for(const c of i.children||[]){const f=find(c,p);if(f)return f}return null}
 Settings {id:settings;visible:false}
 TestCase {id:events;parent:settings.contentItem;when:false;optional:true}
 Timer{interval:1000;running:true;onTriggered:{ShellState.settingsSection=settings.sections.findIndex(x=>x.t==='Dock');events.wait(200)
  const field=root.find(settings.contentItem,x=>typeof x.placeholder==='string'&&x.placeholder.startsWith('Add application'))
  for(const q of ['fire','term','nau']){field.text=q;events.wait(100)}
  console.info('PROBE completed three dock search assignments, no config setter or app launch');Qt.quit()
 }}
}
