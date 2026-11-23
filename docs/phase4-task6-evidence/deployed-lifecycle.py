"""Non-destructive UI/reload/resource verification of the unlocked real shell."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
pid = 12157
hz = os.sysconf('SC_CLK_TCK')
page = os.sysconf('SC_PAGE_SIZE')
config = Path('/home/jorj/.config/niri-monochrome/config.json')
initial_config = config.read_bytes()
results = []
quiet_samples = []
state_samples = []
own_overlay = ''
own_settings = False

def ipc(target, method, *args):
    return subprocess.check_output(['qs','-c','niri-monochrome','ipc','call',target,method,*map(str,args)],
                                   text=True, stderr=subprocess.PIPE, timeout=4).strip()
def state(): return json.loads(ipc('shell','status'))
def diag(): return json.loads(ipc('shell','diagnostics'))
def unlocked():
    if state()['locked']: raise RuntimeError('Session became locked; no more UI/reload operations')
def focused():
    w = json.loads(subprocess.check_output(['niri','msg','-j','focused-window'],text=True,timeout=3))
    return w.get('id') if w else None
def settings_ids():
    windows = json.loads(subprocess.check_output(['niri','msg','-j','windows'],text=True,timeout=3))
    return [w['id'] for w in windows if w.get('title') == 'NIRI MONOCHROME — Settings']
def sample():
    p = Path('/proc')/str(pid)
    st = (p/'stat').read_text().split(') ',1)[1].split()
    memory = (p/'smaps_rollup').read_text().splitlines()
    private = sum(int(l.split()[1]) for l in memory if l.startswith(('Private_Clean:','Private_Dirty:')))
    fds = list((p/'fd').iterdir())
    watches = {}
    for f in fds:
        try:
            if 'inotify' in os.readlink(f): watches[f.name] = (p/'fdinfo'/f.name).read_text().count('inotify wd:')
        except FileNotFoundError: pass
    status = (p/'status').read_text().splitlines()
    contexts = {l.split(':')[0]:int(l.split()[1]) for l in status if 'ctxt_switches:' in l}
    return dict(t=time.monotonic(),ticks=int(st[11])+int(st[12]),rssKiB=int(st[21])*page//1024,
                privateKiB=private,fds=len(fds),children=(p/'task'/str(pid)/'children').read_text().split(),
                inotify=watches,contexts=contexts)
def save():
    (evidence/'deployed-lifecycle.json').write_text(json.dumps(results,indent=2))
    (evidence/'deployed-quiet-samples.json').write_text(json.dumps(quiet_samples,indent=2))
    (evidence/'deployed-state-samples.json').write_text(json.dumps(state_samples,indent=2))
def record(name, operation):
    before = sample()
    focus_before = focused()
    operation()
    after = sample()
    row = dict(name=name,seconds=after['t']-before['t'],before=before,after=after,
               cpuPercent=(after['ticks']-before['ticks'])/hz/(after['t']-before['t'])*100,
               focusBefore=focus_before,focusAfter=focused(),diagnostics=diag(),state=state())
    results.append(row);save()
    print(json.dumps({k:v for k,v in row.items() if k not in ('before','after')}),flush=True)
def wait_closed():
    for _ in range(30):
        d = diag()
        if not d['overlay'] and not d['dock'] and not d['visualizer'] and d['visualizerWatchers']==0 and d['brightnessWatchers']==0:return
        time.sleep(.05)
    raise AssertionError('UI/capture did not close')
def cycles(target, method, expected):
    global own_overlay, own_settings
    for _ in range(4):
        unlocked()
        d=diag();assert not d['overlay'] and not d['dock'],'User UI opened; preserve it'
        if target == 'settings':
            assert not settings_ids(),'Settings is already open'
            ipc('settings','section',2);own_settings=True
        else:
            ipc(target,method);own_overlay=expected or 'dock'
        time.sleep(.25)
        d=diag()
        if target == 'settings':
            assert settings_ids(),'Settings did not map'
            unlocked();ipc('settings','toggle');own_settings=False
        else:
            if target=='dock':assert d['dock'] and not d['overlay']
            else:assert d['overlay']==expected
            unlocked()
            ipc('dock','hide') if target=='dock' else ipc('launcher','close')
            own_overlay=''
        time.sleep(.2);wait_closed()
def quiet(seconds):
    # IPC at 30-second boundaries only; process samples themselves do not wake QS.
    started=time.monotonic()
    for i in range(seconds):
        time.sleep(1);quiet_samples.append(sample())
        if (i+1)%30==0 or i+1==seconds:
            observation={'t':time.monotonic(),'state':state(),'diagnostics':diag(),'focus':focused()}
            state_samples.append(observation);save()
            if observation['state']['locked']:raise RuntimeError('Natural lock during quiet interval; keep lock intact')
            assert not observation['diagnostics']['overlay'] and not observation['diagnostics']['dock'],'User UI activity during sample'
        if (i+1)%60==0:print(json.dumps({'quietSeconds':i+1,'rssKiB':quiet_samples[-1]['rssKiB'],'unlocked':True}),flush=True)
    assert time.monotonic()-started>=seconds
def reload():
    unlocked();wait_closed();ipc('shell','reload')
    for _ in range(60):
        try:
            d=diag()
            if d['niriStatus']=='ready' and not d['overlay']:return
        except (subprocess.SubprocessError,ValueError):pass
        time.sleep(.1)
    raise RuntimeError('Supported shell reload did not become ready')

try:
    unlocked();assert not settings_ids();wait_closed()
    for target,method,expected in [('launcher','open','launcher'),('settings','open',''),
            ('controlcenter','toggle','control'),('notifications','toggle','notifications'),
            ('shortcuts','open','shortcuts'),('dock','toggle',''),('media','toggle','media')]:
        record(target+'-4-open-close',lambda t=target,m=method,x=expected:cycles(t,m,x))
    record('closed-recovery-30s-before-reload',lambda:quiet(30))
    record('supported-live-reload',reload)
    record('post-reload-closed-300s',lambda:quiet(300))
    assert config.read_bytes()==initial_config,'Config changed during observation; preserve it, do not restore'
    print('PASS real shell cycles, supported unlocked reload, 5-minute recovery; user settings unchanged',flush=True)
except Exception as exc:
    (evidence/'deployed-lifecycle-error.txt').write_text(str(exc)+'\n')
    raise
finally:
    # Close only UI owned by this probe, and only while the session is unlocked.
    if not state()['locked']:
        if own_settings and settings_ids():ipc('settings','toggle')
        current=diag()
        if own_overlay=='dock' and current['dock']:ipc('dock','hide')
        elif own_overlay and current['overlay']==own_overlay:ipc('launcher','close')
    save()
