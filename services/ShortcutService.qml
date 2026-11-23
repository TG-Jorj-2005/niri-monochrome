pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "ShortcutParser.js" as Kdl
Singleton {
    id: shortcuts
    property var external: []
    property var generated: []
    property var mainTree: null
    property var inputTree: []
    property string externalError: ""
    property string generatedError: ""
    property string mainError: ""
    property string inputError: ""
    readonly property string modKey: configuredMod()
    readonly property var entries: effective()
    readonly property var categories: ["All", "Applications", "Windows", "Workspaces", "Navigation", "System", "Media", "Screenshots", "NIRI MONOCHROME"]
    readonly property string scopeNote: "Mod=" + modKey + ". Source view: config.kdl + direct binds.kdl/shell include; other includes and XKB symbol aliases are not resolved; not a live compositor snapshot. " + (mainTree === null ? "Main source unavailable; file contents only. " : "") + [externalError,generatedError,mainError,inputError].filter(x=>x!=="").join(" · ")
    function canonical(key) { return Kdl.canonical(key,modKey) }
    function parse(text,shell,strict) {
        try { return Kdl.bindings(Kdl.nodes(text),shell,!strict) }
        catch(e) { return [] }
    }
    function includeName(node) {
        const path=Kdl.argument(node)
        const prefix=Constants.niriConfigDir+"/"
        return path.startsWith(prefix)?path.slice(prefix.length):path.replace(/^\.\//,"")
    }
    function inputMod(tree,current) {
        for(const node of tree) if(!node.disabled&&node.name==="input")
            for(const child of node.children) if(!child.disabled&&child.name==="mod-key") {
                const value=Kdl.argument(child)
                if(["Super","Win","Alt","Ctrl","Control","Shift"].includes(value))current=({Win:"Super",Control:"Ctrl"})[value]||value
            }
        return current
    }
    function configuredMod() {
        let value="Super" // This project's native TTY session; nested-winit Mod is outside coverage.
        if(mainTree===null)return inputMod(inputTree,value)
        for(const node of mainTree) {
            if(node.disabled)continue
            if(node.name==="include"&&includeName(node)==="input.kdl")value=inputMod(inputTree,value)
            if(node.name==="input")value=inputMod([node],value)
        }
        return value
    }
    function combine(base,later) {
        const map=new Map()
        for(const item of base.concat(later))map.set(canonical(item.key),item)
        return Array.from(map.values()).filter(x=>!x.hidden).sort((a,b)=>a.category.localeCompare(b.category)||a.label.localeCompare(b.label))
    }
    function effective() {
        if(mainTree===null)return combine(external,generated)
        let all=[]
        for(const node of mainTree) {
            if(node.disabled)continue
            if(node.name==="include") {
                const name=includeName(node)
                if(name==="binds.kdl")all=all.concat(external)
                if(name==="niri-monochrome.kdl")all=all.concat(generated)
            } else if(node.name==="binds")all=all.concat(Kdl.bindings([node],false,false))
        }
        return combine([],all)
    }
    function filter(query,category) {
        const q=query.toLowerCase().trim()
        return entries.filter(e=>(category==="All"||e.category===category)&&(e.key+" "+e.label+" "+e.category+" "+e.description).toLowerCase().includes(q))
    }
    function load(text,kind) {
        try {
            const tree=Kdl.nodes(text)
            if(kind==="external")external=Kdl.bindings(tree,false,false)
            else if(kind==="generated")generated=Kdl.bindings(tree,true,false)
            else if(kind==="main") { Kdl.bindings(tree,false,false); mainTree=tree }
            else inputTree=tree
            shortcuts[kind+"Error"]=""
        } catch(e) { unavailable(kind,"Unsupported/invalid "+kind+" source") }
    }
    function unavailable(kind,message) {
        if(kind==="external")external=[]
        else if(kind==="generated")generated=[]
        else if(kind==="main")mainTree=null
        else inputTree=[]
        shortcuts[kind+"Error"]=message
    }
    function refresh() { mainFile.reload(); inputFile.reload(); externalFile.reload(); generatedFile.reload() }
    FileView { id:mainFile; path:Constants.niriConfigDir+"/config.kdl"; watchChanges:true; printErrors:false
        onLoaded:shortcuts.load(text(),"main");onFileChanged:reload();onLoadFailed:shortcuts.unavailable("main","Main source unavailable") }
    FileView { id:inputFile; path:Constants.niriConfigDir+"/input.kdl"; watchChanges:true; printErrors:false
        onLoaded:shortcuts.load(text(),"input");onFileChanged:reload();onLoadFailed:shortcuts.unavailable("input","") }
    FileView { id:externalFile; path:Constants.niriConfigDir+"/binds.kdl"; watchChanges:true; printErrors:false
        onLoaded:shortcuts.load(text(),"external");onFileChanged:reload();onLoadFailed:shortcuts.unavailable("external","binds.kdl unavailable") }
    FileView { id:generatedFile; path:Keybindings.includePath; watchChanges:true; printErrors:false
        onLoaded:shortcuts.load(text(),"generated");onFileChanged:reload();onLoadFailed:shortcuts.unavailable("generated","Shell include unavailable") }
}
