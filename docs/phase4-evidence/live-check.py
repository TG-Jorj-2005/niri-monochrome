import json,os,subprocess,time
from pathlib import Path
base=['qs','-c','niri-monochrome','ipc','call']
def call(target,method):
 p=subprocess.run(base+[target,method],capture_output=True,text=True,timeout=4)
 if p.returncode:raise RuntimeError(p.stderr)
 return p.stdout.strip()
def state():return json.loads(call('shell','diagnostics'))
def until(predicate,limit=4):
 end=time.monotonic()+limit
 while time.monotonic()<end:
  try: d=state()
  except (ValueError, RuntimeError):
   time.sleep(.1);continue
  if predicate(d):return d
  time.sleep(.1)
 raise RuntimeError('Bounded readiness check failed: '+json.dumps(d))
def capture_pids():
 p=subprocess.run(['pgrep','-f','^/usr/bin/python3 /home/jorj/.config/quickshell/niri-monochrome/scripts/audio-levels.py '],capture_output=True,text=True)
 return p.stdout.split()
def snapshot():
 s=Path('/proc/12157/stat').read_text().split(') ',1)[1].split()
 return {'rss_kib':int(s[21])*os.sysconf('SC_PAGE_SIZE')//1024,'ticks':int(s[11])+int(s[12])}
time.sleep(.5)
until(lambda d:d['niriStatus']=='ready')
call('launcher','close');call('dock','hide')
start=snapshot();started=time.monotonic();samples=[]
try:
 for i in range(5):
  for target,method in [('shortcuts','open'),('media','toggle'),('launcher','open'),('dock','toggle')]:
   call(target,method)
   if target=='media':
    d=until(lambda d:d['visualizer'] and d['visualizerWatchers']==1)
    assert len(capture_pids())==1,'Duplicate audio capture helpers'
   time.sleep(.15)
   call('launcher','close');call('dock','hide')
   until(lambda d:not d['visualizer'] and d['visualizerWatchers']==0)
   time.sleep(.18)
  samples.append(snapshot()['rss_kib'])
 # Verify that a live reload also tears down a running capture.
 call('media','toggle');until(lambda d:d['visualizer'])
 old=capture_pids();call('shell','reload');time.sleep(.5)
 d=until(lambda d:d['niriStatus']=='ready' and not d['visualizer'] and d['visualizerWatchers']==0)
 for _ in range(30):
  if not capture_pids():break
  time.sleep(.1)
 assert not capture_pids(),'Capture helper survived reload'
 result={'panel_cycles':20,'audio_open_close_cycles':5,'reload_with_active_capture':True,'old_capture_pids':old,'remaining_capture_pids':capture_pids(),'rss_after_each_cycle_kib':samples,'start':start,'end':snapshot(),'cpu_percent':(snapshot()['ticks']-start['ticks'])/os.sysconf('SC_CLK_TCK')/(time.monotonic()-started)*100,'diagnostics':d}
 print(json.dumps(result));Path('/tmp/nm-phase4-interactions.json').write_text(json.dumps(result,indent=2))
finally:call('launcher','close');call('dock','hide')
