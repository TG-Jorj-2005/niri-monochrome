"""Bounded live panel workload; no audio capture, device actions or preference edits."""
import hashlib,json,os,re,subprocess,time
from pathlib import Path
pid=12157;hz=os.sysconf('SC_CLK_TCK');page=os.sysconf('SC_PAGE_SIZE')
out=Path('/tmp/nm-task4-nonmedia-profile');out.mkdir(exist_ok=True)
def ipc(target,method):
 return subprocess.check_output(['qs','-c','niri-monochrome','ipc','call',target,method],text=True,timeout=4).strip()
def diag():return json.loads(ipc('shell','diagnostics'))
def process(p):
 root=Path('/proc')/str(p);st=(root/'stat').read_text().split(') ',1)[1].split()
 return dict(ticks=int(st[11])+int(st[12]),rss_kib=int(st[21])*page//1024,fds=len(list((root/'fd').iterdir())),name=(root/'comm').read_text().strip())
def snap():
 root=Path('/proc')/str(pid);data=process(pid);threads={}
 for p in (root/'task').iterdir():
  try:
   st=(p/'stat').read_text().split(') ',1)[1].split()
   threads[p.name]=dict(ticks=int(st[11])+int(st[12]),name=(p/'comm').read_text().strip())
  except FileNotFoundError:pass
 data['threads']=threads
 data['children']={p:process(p) for p in (root/'task'/str(pid)/'children').read_text().split() if Path('/proc',p).exists()}
 data['t']=time.monotonic();return data
def context():
 d=diag();layers=subprocess.check_output(['niri','msg','layers'],text=True,timeout=4)
 return dict(diagnostics=d,namespaces=re.findall(r'Namespace: "([^"]+)"',layers))
def measure(label,seconds):
 a=snap();samples=[];deadline=time.monotonic()
 for _ in range(seconds):
  deadline+=1;time.sleep(max(0,deadline-time.monotonic()));samples.append(dict(process=snap(),context=context()))
 b=samples[-1]['process'];dt=b['t']-a['t'];threads={}
 for tid,x in b['threads'].items():
  if tid in a['threads']:
   threads[x['name']]=threads.get(x['name'],0)+max(0,x['ticks']-a['threads'][tid]['ticks'])/hz/dt*100
 r=dict(pid=pid,seconds=dt,cpu_percent=(b['ticks']-a['ticks'])/hz/dt*100,rss_start_mib=a['rss_kib']/1024,rss_end_mib=b['rss_kib']/1024,
        fds_start=a['fds'],fds_end=b['fds'],common_thread_cpu_percent=threads,samples=samples)
 (out/(label+'.json')).write_text(json.dumps(r,indent=2));print('MEASURE '+label+' '+json.dumps({k:v for k,v in r.items() if k!='samples'}),flush=True)
 assert all(not s['context']['diagnostics']['visualizer'] and s['context']['diagnostics']['visualizerWatchers']==0 for s in samples),'Audio active during nonmedia workload'
 return r
initial=diag();assert initial['overlay']=='' and not initial['dock'] and not initial['visualizer'],'User panel active; do not override'
settings=Path('/home/jorj/.config/niri-monochrome/config.json').read_bytes()
# Record only selected renderer variables; never dump the full process environment.
env=Path(f'/proc/{pid}/environ').read_bytes().split(b'\0')
keys=[b'QT_QUICK_BACKEND',b'QSG_RHI_BACKEND',b'LIBGL_ALWAYS_SOFTWARE',b'MESA_LOADER_DRIVER_OVERRIDE',b'QSG_RENDER_LOOP']
(out/'renderer-environment.json').write_text(json.dumps({v.split(b'=',1)[0].decode():v.split(b'=',1)[1].decode() for v in env if b'=' in v and v.split(b'=',1)[0] in keys},indent=2))
measure('closed-before',30)
a=snap();samples=[]
try:
 for _ in range(4):
  for target in ['shortcuts','launcher','controlcenter','notifications']:
   ipc(target,'toggle');time.sleep(.25);samples.append(dict(process=snap(),context=context()))
   ipc('launcher','close');time.sleep(.25)
 ipc('dock','toggle');time.sleep(.4)
finally:
 ipc('launcher','close');ipc('dock','hide')
b=snap();dt=b['t']-a['t']
r=dict(cycles=16,seconds=dt,cpu_percent=(b['ticks']-a['ticks'])/hz/dt*100,rss_start_mib=a['rss_kib']/1024,rss_end_mib=b['rss_kib']/1024,fds_start=a['fds'],fds_end=b['fds'],samples=samples)
(out/'cycles.json').write_text(json.dumps(r,indent=2));print('MEASURE cycles '+json.dumps({k:v for k,v in r.items() if k!='samples'}),flush=True)
assert all(not s['context']['diagnostics']['visualizer'] and s['context']['diagnostics']['visualizerWatchers']==0 for s in samples)
measure('recovery-30s',30);measure('recovery-60s',60)
assert Path('/home/jorj/.config/niri-monochrome/config.json').read_bytes()==settings
print('PASS no audio activity or preference edits in nonmedia workload',flush=True)
