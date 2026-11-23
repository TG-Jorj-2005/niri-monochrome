import QtQuick
import Quickshell
import qs.config
import qs.services
ShellRoot {
 id: root
 property int passed:0
 property int failed:0
 function check(n,ok){if(ok)passed++;else failed++;console.info((ok?"PASS ":"FAIL ")+n)}
 function rows(s){return ShortcutService.parse(s,false)}
 Timer { interval:800;running:true;onTriggered:{
  let r=root.rows('binds {\n/*\nMod+Q { quit; }\n*/\nMod+T { spawn "alacritty"; }\n}')
  root.check("block comments never invent bindings",r.length===1 && r[0].key==="Mod+T")
  r=root.rows('binds {\n /- Mod+Q { quit; }\n Mod+T {\n spawn "alacritty";\n }\n}')
  root.check("disabled nodes excluded and multiline action retained",r.length===1 && r[0].key==="Mod+T")
  r=root.rows('binds { Mod+T { spawn "sh" "-c" "echo } literal"; }; Mod+E { spawn "nautilus"; }; }')
  root.check("quoted braces and same-line nodes preserve structure",r.length===2 && r[0].description.includes('echo } literal'))
  r=root.rows('binds {\n Control+Win+T { spawn "alacritty"; }\n Mod5+guillemotleft { focus-column-left; }\n}')
  root.check("native modifier aliases accepted",r.length===2)
  root.check("canonicalization changes modifiers only",ShortcutService.canonical("Mod+Mode_switch")===ShortcutService.canonical("Super+Mode_switch") && ShortcutService.canonical("Mode_switch")==="Mode_switch")
  const base=root.rows('Mod+T { spawn "alacritty"; }')
  const hidden=root.rows('Super+T hotkey-overlay-title=null { spawn "foot"; }')
  root.check("hidden later binding cannot resurrect overridden row",ShortcutService.combine(base,hidden).length===0)
  root.check("modifier aliases resolve one effective row",ShortcutService.combine(root.rows('Ctrl+Super+T { spawn "a"; }'),root.rows('Win+Control+T { spawn "b"; }'))[0].description.includes('"b"'))
  r=root.rows('binds {\nMod+T hotkey-overlay-title="A \\"quoted\\" title" { spawn "foo"; }\n}')
  root.check("escaped title decoded",r.length===1 && r[0].label==='A "quoted" title')
  r=root.rows('binds {\nMod+T { spawn "x"; }\nMod+E {\n')
  root.check("structurally invalid source fails closed",r.length===0)
  const same=root.rows('Mod+T { spawn "alacritty"; }\nMod+Return { spawn "alacritty"; }')
  root.check("multiple keys for one action are retained",ShortcutService.combine([],same).length===2)
  ShortcutService.external=root.rows('Mod+T hotkey-overlay-title="Terminal [work]" { spawn "alacritty"; }\nMod+E { spawn "nautilus"; }');ShortcutService.generated=[]
  root.check("case insensitive action and description filtering",ShortcutService.filter('ALACRITTY','All').length===1 && ShortcutService.filter('terminal','All').length===1)
  root.check("literal special-character search",ShortcutService.filter('[work]','All').length===1 && ShortcutService.filter('.*','All').length===0)
  root.check("category filtering and empty state",ShortcutService.filter('','Applications').length===2 && ShortcutService.filter('missing','All').length===0)
  root.check("same-block duplicates fail closed as native niri requires",root.rows('binds { Mod+T { spawn "a"; }; Mod+T { spawn "b"; }; }').length===0)
  root.check("raw quoted strings and nested comments preserved",root.rows('/* outer /* nested */ end */ binds { Mod+T hotkey-overlay-title=r#"Raw \"title\""# { spawn "x"; }; }')[0].label==='Raw "title"')
  ShortcutService.external=root.rows('Mod+T hotkey-overlay-title="Base" { spawn "a"; }')
  ShortcutService.generated=root.rows('Mod+T hotkey-overlay-title="Later" { spawn "b"; }')
  ShortcutService.load('include "niri-monochrome.kdl"\ninclude "binds.kdl"\n','main')
  root.check("supported includes follow main file order",ShortcutService.entries.length===1&&ShortcutService.entries[0].label==='Base')
  ShortcutService.load('/- include "binds.kdl"\ninclude "niri-monochrome.kdl"\n','main')
  root.check("disabled source include cannot contribute rows",ShortcutService.entries.length===1&&ShortcutService.entries[0].label==='Later')
  ShortcutService.load('include "binds.kdl"\nbinds { Mod+T hotkey-overlay-title="Inline" { spawn "c"; }; }\n','main')
  root.check("main inline binding overrides preceding included source",ShortcutService.entries[0].label==='Inline')
  ShortcutService.load('input { mod-key "Alt"; }','input')
  ShortcutService.load('include "input.kdl"\ninclude "binds.kdl"\n','main')
  root.check("configured native Mod changes modifier normalization",ShortcutService.modKey==='Alt'&&ShortcutService.canonical('Mod+T')===ShortcutService.canonical('Alt+T')&&ShortcutService.canonical('Mod+T')!==ShortcutService.canonical('Super+T'))
  root.check("unknown actions remain raw informational descriptions",root.rows('Mod+T { unrecognized-action "literal"; }')[0].description==='unrecognized-action "literal"')
  root.check("empty or invalid supported entries never invent actions",root.rows('binds { Mod++T { quit; }; Mod+Q {}; }').length===0)
  ShortcutService.mainTree=null;ShortcutService.inputTree=[]
  ShortcutService.external=[];for(let i=0;i<5000;i++)ShortcutService.external.push({key:'Mod+F'+i,label:'Action '+i,category:'Applications',description:'spawn "application-'+i+'"'})
  ShortcutService.external=ShortcutService.external.slice();ShortcutService.generated=[]
  const start=Date.now();let found=0;for(let i=0;i<100;i++)found+=ShortcutService.filter('application-42','All').length
  console.info('FILTER_BENCH '+(Date.now()-start)+' ms for 100 queries over 5000 rows')
  root.check("large registry filtering remains local and deterministic",found===11100)
  const classified=root.rows('binds { Mod+T { spawn "workspace-manager"; }; Mod+L { spawn "niri-lock"; }; }')
  root.check("category uses native action and recognizes configured lock wrapper",classified.find(e=>e.key==='Mod+T').category==='Applications'&&classified.find(e=>e.key==='Mod+L').category==='System')
  console.info("RESULT "+root.passed+"/"+(root.passed+root.failed)+" passed");Qt.quit()
 } }
}
