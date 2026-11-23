.pragma library

// Structural reader for the registry's bounded KDL subset, not a Niri validator.
// Quoted/raw strings, comments, slash-dash nodes and braces are read before bindings.
function nodes(text) {
    if (text.length > 1024*1024) throw new Error("Source exceeds 1 MiB")
    const t=[]; let i=0
    function put(kind,value,start) { t.push({kind:kind,value:value,raw:text.slice(start,i)}) }
    while(i<text.length) {
        const start=i, c=text[i]
        if(c==='\n'||c===';') { i++;put('end',c,start);continue }
        if(/\s/.test(c)) {i++;continue}
        if(text.slice(i,i+2)==='//') {while(i<text.length&&text[i]!=='\n')i++;continue}
        if(text.slice(i,i+2)==='/*') {
            i+=2;let depth=1
            while(i<text.length&&depth) {if(text.slice(i,i+2)==='/*'){depth++;i+=2}else if(text.slice(i,i+2)==='*/'){depth--;i+=2}else i++}
            if(depth)throw new Error('Unterminated comment');continue
        }
        if(text.slice(i,i+2)==='/-') {i+=2;put('disabled','/-',start);continue}
        if(c==='\\') {i++;while(i<text.length&&/[ \t\r]/.test(text[i]))i++;if(text[i]!=='\n')throw new Error('Unsupported continuation');i++;continue}
        const raw=c==='r'?text.slice(i).match(/^r(#{0,16})"/):null
        if(raw) {
            i+=raw[0].length;const stop='"'+raw[1], end=text.indexOf(stop,i)
            if(end<0)throw new Error('Unterminated raw string')
            const value=text.slice(i,end);i=end+stop.length;put('string',value,start);continue
        }
        if(c==='"') {
            i++;let value='',closed=false
            while(i<text.length) {
                const x=text[i++]
                if(x==='"'){closed=true;break}
                if(x!=='\\'){value+=x;continue}
                const e=text[i++], escapes={'n':'\n','r':'\r','t':'\t','b':'\b','f':'\f','"':'"','\\':'\\','/':'/'}
                if(e==='u'&&text[i]==='{') {
                    const end=text.indexOf('}',++i), hex=text.slice(i,end)
                    if(end<0||! /^[a-fA-F0-9]{1,6}$/.test(hex))throw new Error('Invalid Unicode escape')
                    value+=String.fromCodePoint(parseInt(hex,16));i=end+1
                } else if(escapes[e]!==undefined)value+=escapes[e]
                else throw new Error('Unsupported string escape')
            }
            if(!closed)throw new Error('Unterminated string')
            put('string',value,start);continue
        }
        if('{}='.includes(c)){i++;put(c,c,start);continue}
        while(i<text.length&&!/[\s{}=;]/.test(text[i])&&!['//','/*','/-'].includes(text.slice(i,i+2)))i++
        if(i===start)throw new Error('Unsupported token')
        put('word',text.slice(start,i),start)
    }
    let at=0
    function read(nested,depth) {
        if(depth>64)throw new Error('Nesting limit')
        const result=[]
        while(at<t.length) {
            if(t[at].kind==='end'){at++;continue}
            if(t[at].kind==='}') {if(!nested)throw new Error('Unexpected brace');at++;return result}
            const begin=at;let disabled=false
            if(t[at].kind==='disabled'){disabled=true;at++}
            const header=[]
            while(at<t.length&&!['end','{','}'].includes(t[at].kind))header.push(t[at++])
            if(!header.length)throw new Error('Empty node')
            let children=[]
            if(at<t.length&&t[at].kind==='{'){at++;children=read(true,depth+1)}
            result.push({name:header[0].value,header:header,children:children,disabled:disabled,raw:t.slice(begin,at).map(x=>x.raw).join(' ')})
        }
        if(nested)throw new Error('Unclosed brace')
        return result
    }
    return read(false,0)
}
function property(node,name) {
    for(let i=1;i<node.header.length;i++) {
        if(node.header[i].kind==='disabled') { i++;if(node.header[i+1]&&node.header[i+1].kind==='=')i+=2;continue }
        if(node.header[i].value===name&&node.header[i+1]&&node.header[i+1].kind==='=')return node.header[i+2]
    }
    return undefined
}
function argument(node) {
    for(let i=1;i<node.header.length;i++) {
        if(node.header[i].kind==='disabled'){i++;if(node.header[i+1]&&node.header[i+1].kind==='=')i+=2;continue}
        if(node.header[i+1]&&node.header[i+1].kind==='='){i+=2;continue}
        return node.header[i].value
    }
    return ''
}
function validKey(key) {return /^(?:(?:Mod|Super|Win|Ctrl|Control|Alt|Shift|Mod5|ISO_Level3_Shift|ISO_Level5_Shift)\+)*[A-Za-z0-9_]+$/.test(key)}
function canonical(key,mod) {
    const pieces=key.split('+'), trigger=pieces.pop()
    const aliases={Mod:mod||'Super',Win:'Super',Control:'Ctrl',Mod5:'ISO_Level3_Shift'}
    return Array.from(new Set(pieces.map(p=>aliases[p]||p))).sort().concat([trigger]).join('+')
}
function bindings(tree,shell,fragments) {
    const list=[]
    function add(n) {
        if(n.disabled||!validKey(n.name))return
        const actions=n.children.filter(x=>!x.disabled)
        if(actions.length!==1)return
        const title=property(n,'hotkey-overlay-title'), command=actions[0].raw.replace(/;\s*$/,'')
        // Preserve a hidden override as a tombstone until duplicate resolution.
        const hidden=title&&title.kind==='word'&&['null','#null'].includes(title.value)
        const label=title&&!hidden?title.value:command.replace(/-/g,' ')
        const category=shell?'NIRI MONOCHROME':/screenshot|Print/.test(command+' '+n.name)?'Screenshots':/XF86Audio|XF86Mon/.test(n.name)?'Media':/workspace/.test(actions[0].name)?'Workspaces':/monitor|focus-column|focus-window|switch-layout/.test(actions[0].name)?'Navigation':/window|column|fullscreen/.test(actions[0].name)?'Windows':/makoctl|swaylock|niri-lock|power|suspend|quit/.test(command)?'System':/spawn/.test(command)?'Applications':'System'
        list.push({key:n.name,label:label,category:category,description:command,hidden:!!hidden})
    }
    if(tree.filter(n=>!n.disabled&&n.name==='binds').length>1)throw new Error('Duplicate binds node')
    for(const node of tree) {
        if(node.disabled)continue
        if(node.name==='binds') {
            const seen=new Set()
            for(const n of node.children) {
                if(!n.disabled&&validKey(n.name)) {
                    const key=canonical(n.name,'Mod')
                    if(seen.has(key))throw new Error('Duplicate binding in one block')
                    seen.add(key)
                }
                add(n)
            }
        }
        else if(fragments)add(node)
    }
    return list
}
