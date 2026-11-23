import json,os,subprocess,time
from pathlib import Path
pid=12157;hz=os.sysconf('SC_CLK_TCK');page=os.sysconf('SC_PAGE_SIZE')
def ipc(target,method):return subprocess.check_output(['qs','-c','niri-monochrome','ipc','call',target,method],text=True,timeout=4).strip()
def diag():return json.loads(ipc('shell','diagnostics'))
def focus():
 j=json.loads(subprocess.check_output(['niri','msg','-j','focused-window'],text=True));return j.get('id') if j else None
def sample():
 p=Path('/proc')/str(pid);st=(p/'stat').read_text().split(') ',1)[1].split()
 return dict(t=time.monotonic(),ticks=int(st[11])+int(st[12]),rss_kib=int(st[21])*page//1024,fds=len(list((p/'fd').iterdir())),children=(p/'task'/str(pid)/'children').read_text().split())
initial=diag();assert initial['overlay']=='' and not initial['dock'],'User overlay is active; do not override it'
settings=Path('/home/jorj/.config/niri-monochrome/config.json').read_bytes()
focused=focus();before=sample();samples=[]
try:
 for _ in range(12):
  ipc('shortcuts','toggle');time.sleep(.2);d=diag();assert d['overlay']=='shortcuts' and not d['visualizer'];samples.append(sample())
  ipc('shortcuts','toggle');time.sleep(.2);assert diag()['overlay']==''
 ipc('shortcuts','open');time.sleep(.3);ipc('shell','reload')
 until=time.monotonic()+6
 while time.monotonic()<until:
  try:
   d=diag()
   if d['niriStatus']=='ready' and d['overlay']=='':break
  except (ValueError,subprocess.CalledProcessError):pass
  time.sleep(.1)
 else:raise AssertionError('Shell readiness after supported reload')
 ipc('shortcuts','toggle');time.sleep(.3);assert diag()['overlay']=='shortcuts'
finally:
 if diag()['overlay']=='shortcuts':ipc('shortcuts','close')
time.sleep(.4);after=sample();final=diag()
assert not final['visualizer'] and final['visualizerWatchers']==0
assert Path('/home/jorj/.config/niri-monochrome/config.json').read_bytes()==settings
r=dict(cycles=12,before=before,after=after,cpu_percent=(after['ticks']-before['ticks'])/hz/(after['t']-before['t'])*100,samples=samples,focused_before=focused,focused_after=focus(),final=final,reload_then_reopen=True)
Path('/tmp/nm-task5-live-lifecycle.json').write_text(json.dumps(r,indent=2));print(json.dumps({k:v for k,v in r.items() if k!='samples'}))
