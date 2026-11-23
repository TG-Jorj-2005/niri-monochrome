import json,os,subprocess,time
from pathlib import Path
pid=12157;helper=Path('/home/jorj/.config/quickshell/niri-monochrome/scripts/audio-levels.py')
def call(target,action):
 return subprocess.check_output(['qs','-c','niri-monochrome','ipc','call',target,action],text=True,timeout=4).strip()
def state():return json.loads(call('shell','diagnostics'))
def children(p):
 try:return [int(x) for x in Path(f'/proc/{p}/task/{p}/children').read_text().split()]
 except FileNotFoundError:return []
def owned():
 result=[]
 for child in children(pid):
  try:
   if str(helper).encode() in Path(f'/proc/{child}/cmdline').read_bytes().split(b'\0'):result.append(child)
  except FileNotFoundError:pass
 return result
def alive(p):
 try:return Path(f'/proc/{p}/stat').read_text().split(') ',1)[1][0]!='Z'
 except FileNotFoundError:return False
def wait(predicate):
 until=time.monotonic()+7
 while time.monotonic()<until:
  try:
   d=state()
   if predicate(d):return d
  except (ValueError,subprocess.CalledProcessError):pass
  time.sleep(.1)
 raise AssertionError('Live shell readiness timeout')
initial=state();assert initial['overlay']=='' and not initial['dock'] and not initial['visualizer']
settings=Path('/home/jorj/.config/niri-monochrome/config.json').read_bytes()
sink=subprocess.check_output(['pactl','get-default-sink'],text=True).strip()
source=subprocess.check_output(['pactl','get-default-source'],text=True).strip()
result={}
try:
 call('media','toggle');started=wait(lambda d:d['visualizer'] and d['visualizerWatchers']==1)
 time.sleep(.3);capture=owned();assert len(capture)==1
 old=capture+[x for p in capture for x in children(p)]
 graph=json.loads(subprocess.check_output(['pw-dump'],text=True))
 nodes=[x.get('info',{}).get('props',{}) for x in graph if x['type'].endswith(':Node')]
 node=[p for p in nodes if p.get('node.name')=='niri-monochrome-visualizer' and p.get('target.object')==sink]
 assert len(node)==1 and node[0].get('stream.capture.sink') and node[0].get('node.dont-fallback') and node[0].get('node.dont-reconnect')
 by_id={x['id']:x.get('info',{}).get('props',{}) for x in graph if x['type'].endswith(':Node')}
 capture_ids={i for i,p in by_id.items() if p.get('node.name')=='niri-monochrome-visualizer' and p.get('target.object')==sink}
 links=[by_id.get(x.get('info',{}).get('output-node-id'),{}) for x in graph if x['type'].endswith(':Link') and x.get('info',{}).get('input-node-id') in capture_ids]
 assert links and all(p.get('node.name')==sink and p.get('media.class')=='Audio/Sink' for p in links)
 result['current_default_monitor_verified']=True
 result['capture_pids_before_reload']=old
 call('shell','reload');final=wait(lambda d:d['niriStatus']=='ready' and not d['visualizer'] and d['visualizerWatchers']==0 and d['overlay']=='')
 time.sleep(.4);assert not owned() and all(not alive(p) for p in old)
 result['reload_during_real_capture_clean']=True
 result['final']=final
 assert settings==Path('/home/jorj/.config/niri-monochrome/config.json').read_bytes()
 assert sink==subprocess.check_output(['pactl','get-default-sink'],text=True).strip()
 assert source==subprocess.check_output(['pactl','get-default-source'],text=True).strip()
 result['settings_and_current_routing_preserved']=True
 Path('/tmp/nm-task4-live-reload.json').write_text(json.dumps(result,indent=2))
 print(json.dumps(result))
finally:
 if state()['overlay']=='media':call('launcher','close')
