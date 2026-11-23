#!/usr/bin/env python3
"""Opt-in real PipeWire/Quickshell lifecycle test using temporary null sinks.
Only AudioService's selection/availability is simulated in a private project copy.
The actual MediaControls, visualizer service, PCM helper and pw-cat are exercised.
Never changes the user's default output or routes playback to hardware.
"""
import argparse
import array
import json
import math
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--profile', action='store_true', help='Add 30-second workloads and 60-second recovery')
parser.add_argument('--evidence', type=Path, required=True)
args = parser.parse_args()
def interrupted(*_):
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, interrupted)
args.evidence.mkdir(parents=True, exist_ok=True)
source = Path(__file__).resolve().parents[1]
passed = 0
records = []
modules = {}
playback = None
proc = None
qs_pid = None
seen_capture_pids = set()
hz = os.sysconf('SC_CLK_TCK')
page = os.sysconf('SC_PAGE_SIZE')

def check(name, ok, detail=None):
    global passed
    if not ok:
        raise AssertionError(name + ': ' + str(detail))
    passed += 1
    print('PASS ' + name, flush=True)
    records.append(dict(check=name, detail=detail))

def run(*cmd):
    return subprocess.check_output(cmd, text=True, timeout=8).strip()

def children(pid):
    try: return [int(x) for x in Path(f'/proc/{pid}/task/{pid}/children').read_text().split()]
    except FileNotFoundError: return []

def descendants(pid):
    result = []
    for child in children(pid):
        result.append(child)
        result.extend(descendants(child))
    return result

def command(pid):
    try: return Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0')
    except FileNotFoundError: return []

def captures():
    found = [p for p in descendants(qs_pid) if str(root/'scripts/audio-levels.py').encode() in command(p)]
    seen_capture_pids.update(found)
    return found

def alive(pid):
    try: return Path(f'/proc/{pid}/stat').read_text().split(') ', 1)[1][0] != 'Z'
    except FileNotFoundError: return False

def ipc(action, *values):
    result = subprocess.run(['qs', '-p', str(root/'selftest-visualizer.qml'), 'ipc', 'call', 'audioTest', action, *map(str, values)],
                            env=env, capture_output=True, text=True, timeout=4)
    result.check_returncode()
    return result.stdout.strip()

def state(): return json.loads(ipc('state'))

def wait_for(predicate, timeout=4):
    until = time.monotonic()+timeout
    last = None
    while time.monotonic()<until:
        try:
            last = state()
            if predicate(last): return last
        except (ValueError, subprocess.CalledProcessError):
            if proc.poll() is not None: raise RuntimeError('Fixture exited')
        time.sleep(.05)
    raise AssertionError('Timed out waiting for fixture: '+str(last))

def stopped():
    wait_for(lambda s: not s['running'] and s['watchers']==0)
    until = time.monotonic()+3
    while captures() and time.monotonic()<until: time.sleep(.03)
    return not captures()

def graph():
    data = json.loads(run('pw-dump'))
    nodes = {x['id']:x.get('info', {}).get('props', {}) for x in data if x['type'].endswith(':Node')}
    owned = {i:p for i,p in nodes.items() if p.get('node.name')=='niri-monochrome-visualizer' and p.get('target.object') in names}
    links = []
    for item in data:
        if item['type'].endswith(':Link'):
            info = item.get('info', {})
            if info.get('input-node-id') in owned:
                links.append(nodes.get(info.get('output-node-id'), {}).get('node.name'))
    return dict(nodes=owned, sources=links)

def stop_playback():
    global playback
    if playback and playback.poll() is None:
        playback.terminate()
        try: playback.wait(timeout=3)
        except subprocess.TimeoutExpired: playback.kill(); playback.wait()
    playback = None

def play(target, silent=False):
    global playback
    stop_playback()
    playback = subprocess.Popen(['pw-cat', '--playback', '--raw', '--target', target, '--rate', '16000',
                                 '--channels', '1', '--format', 's16', str(base/('silence.raw' if silent else 'tone.raw'))],
                                stdout=subprocess.DEVNULL, stderr=playback_log)

def snapshot(pid):
    result = {}
    for current in [pid]+descendants(pid):
        try:
            p = Path('/proc')/str(current)
            st = (p/'stat').read_text().split(') ', 1)[1].split()
            result[current] = dict(ticks=int(st[11])+int(st[12]), rss_kib=int(st[21])*page//1024,
                                   fds=len(list((p/'fd').iterdir())), command=(p/'comm').read_text().strip())
        except FileNotFoundError: pass
    return result

def measure(name, duration):
    start = time.monotonic(); samples = []
    first = snapshot(qs_pid)
    for _ in range(duration):
        time.sleep(1)
        samples.append(dict(t=time.monotonic()-start, processes=snapshot(qs_pid), state=state()))
    elapsed = time.monotonic()-start
    last = samples[-1]['processes']
    result = dict(name=name, seconds=elapsed, qs_pid=qs_pid,
                  cpu_percent=(last[qs_pid]['ticks']-first[qs_pid]['ticks'])/hz/elapsed*100,
                  group_cpu_percent=sum(last[p]['ticks']-first[p]['ticks'] for p in first.keys() & last.keys())/hz/elapsed*100,
                  rss_start_mib=first[qs_pid]['rss_kib']/1024, rss_end_mib=last[qs_pid]['rss_kib']/1024,
                  fds_start=first[qs_pid]['fds'], fds_end=last[qs_pid]['fds'], samples=samples)
    (args.evidence/(name+'.json')).write_text(json.dumps(result, indent=2))
    print('MEASURE '+json.dumps({k:v for k,v in result.items() if k!='samples'}), flush=True)

original_sink = run('pactl', 'get-default-sink')
original_source = run('pactl', 'get-default-source')
original_streams = json.loads(run('pactl', '-f', 'json', 'list', 'sink-inputs'))
original_routes = {x['index']:x['sink'] for x in original_streams}

def sink(name):
    modules[name] = run('pactl', 'load-module', 'module-null-sink', 'sink_name='+name,
                        'sink_properties=device.description=NMTask4Virtual')
    assert run('pactl', 'get-default-sink') == original_sink

def remove(name):
    run('pactl', 'unload-module', modules.pop(name))

try:
    with tempfile.TemporaryDirectory(prefix='nm-audio-live-') as temp:
        base = Path(temp); root = base/'project'; root.mkdir()
        for directory in ['components', 'services', 'config', 'scripts']:
            shutil.copytree(source/directory, root/directory, ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copy2(source/'tests/fixtures/visualizer-live.qml', root/'selftest-visualizer.qml')
        (root/'services/AudioService.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    // Selection simulation only; actual PCM transport remains unchanged.
    property string testTarget: Quickshell.env("NM_TEST_TARGET")
    property bool ready: true
    readonly property var sink: testTarget ? ({name:testTarget}) : null
}
''')
        for sub in ['config/niri-monochrome', 'config/niri', 'state', 'runtime']:
            (base/sub).mkdir(parents=True, exist_ok=True)
        (base/'runtime').chmod(0o700)
        (base/'config/niri-monochrome/config.json').write_text(json.dumps({
            'notifications':{'server':False}, 'shortcuts':{'writeNiriInclude':False},
            'wallpaper':{'enabled':False}, 'security':{'useShellLock':False}}))
        bus_config = base/'bus.conf'
        bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><policy context="default">'
                              '<allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        names = ['nm_task4_a_'+str(os.getpid()), 'nm_task4_b_'+str(os.getpid())]
        for name in names: sink(name)
        # Test tones exist only in a temporary directory and target only the null sink.
        tone = array.array('h', (round(5000*math.sin(2*math.pi*440*i/16000)) for i in range(16000)))
        (base/'tone.raw').write_bytes(tone.tobytes()*40)
        (base/'silence.raw').write_bytes(b'\0'*(16000*2*40))
        env = dict(os.environ, XDG_CONFIG_HOME=str(base/'config'), XDG_STATE_HOME=str(base/'state'),
                   XDG_RUNTIME_DIR=str(base/'runtime'), PIPEWIRE_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],
                   QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='', NIRI_SOCKET='',
                   NM_AUDIO_LIFECYCLE='1', NM_TEST_TARGET=names[0])
        env.pop('WAYLAND_DISPLAY', None)
        with (args.evidence/'qml.log').open('w+') as log, (args.evidence/'playback.log').open('w') as playback_log:
            proc = subprocess.Popen(['dbus-run-session', '--config-file='+str(bus_config), '--', 'qs', '-p',
                                     str(root/'selftest-visualizer.qml'), '--no-color'], env=env, stdout=log,
                                    stderr=subprocess.STDOUT, start_new_session=True)
            try:
                for _ in range(60):
                    found = [p for p in descendants(proc.pid) if Path(f'/proc/{p}/comm').exists() and Path(f'/proc/{p}/comm').read_text().strip()=='qs']
                    if found: qs_pid=found[0]; break
                    time.sleep(.05)
                assert qs_pid is not None
                wait_for(lambda s: s['status']=='idle')
                check('closed MediaControls starts no capture', stopped())
                if args.profile: measure('closed-idle', 30)
                ipc('open'); wait_for(lambda s:s['running'] and s['watchers']==1)
                time.sleep(.4)
                first_capture = captures()
                check('open starts exactly one real capture', len(first_capture)==1, first_capture)
                g=graph(); check('real graph links only selected sink monitor', bool(g['sources']) and set(g['sources'])=={names[0]}, g)
                if args.profile: measure('open-no-playback', 30)
                play(names[0]); observed=wait_for(lambda s:s['amplitude']>.1)
                check('real virtual-sink PCM produces amplitude', observed['amplitude']>.1, observed)
                if args.profile: measure('open-real-playback', 30)
                stop_playback()
                paused=wait_for(lambda s:s['amplitude']==0 and s['status']=='listening', timeout=4)
                check('suspended sink clears stale amplitude without fabricated PCM', paused['amplitude']==0 and not paused['levels'])
                play(names[0]);wait_for(lambda s:s['amplitude']>.1)

                ipc('appearance'); time.sleep(.4)
                check('appearance changes do not restart capture', captures()==first_capture)
                play(names[0], silent=True); calm=wait_for(lambda s:s['amplitude']==0, timeout=5)
                check('actual silent PCM returns calm state', calm['amplitude']==0)
                stop_playback(); ipc('duplicate','true');wait_for(lambda s:s['watchers']==2)
                check('two visible views share a single capture', len(captures())==1)
                ipc('enabled','false');check('disable stops capture with views open', stopped())
                ipc('close');ipc('enabled','true');time.sleep(.3)
                check('reenable while hidden stays stopped', stopped())
                ipc('open');wait_for(lambda s:s['running']);time.sleep(.2)
                ipc('select',names[1]);wait_for(lambda s:s['running'] and s['target']==names[1] and s['status'] in ['listening','ready'], timeout=5)
                time.sleep(.4);g=graph()
                check('output selection change replaces obsolete monitor', bool(g['sources']) and set(g['sources'])=={names[1]} and len(captures())==1, g)
                ipc('available','false');wait_for(lambda s:not s['running']);time.sleep(.2)
                check('backend unavailable stops capture', not captures())
                ipc('available','true');wait_for(lambda s:s['running']);time.sleep(.2)
                check('backend reconnection resumes one capture', len(captures())==1)
                # Real target removal: must never relink to the user's hardware output.
                remove(names[1]);time.sleep(.6);g=graph()
                check('removed target never falls back to hardware', not g['sources'], g)
                sink(names[1]);wait_for(lambda s:s['running'] and s['target']==names[1] and s['status'] in ['listening','ready'], timeout=5)
                time.sleep(.3);g=graph()
                check('same-name output reconnection restores its monitor', bool(g['sources']) and set(g['sources'])=={names[1]}, g)
                # Each visibility activation owns a bounded retry budget. Isolate this
                # failure sequence from the earlier real target-removal retry.
                ipc('close'); assert stopped()
                ipc('open'); wait_for(lambda s:s['running'] and s['attempts']==0); time.sleep(.2)
                # Kill only the helper owned by this private test shell; never an audio daemon.
                for attempt in range(4):
                    owned=captures();assert len(owned)==1
                    crashed_children=descendants(owned[0]) if attempt==0 else []
                    os.kill(owned[0], signal.SIGKILL if attempt==0 else signal.SIGTERM)
                    wait_for(lambda s:s['attempts']>=attempt+1)
                    if attempt<3:
                        wait_for(lambda s:s['running'] and s['status'] in ['listening','ready'], timeout=4)
                        time.sleep(.1)
                    if attempt==0:
                        check('helper crash terminates pw-cat through parent-death guard', all(not alive(p) for p in crashed_children))
                exhausted=wait_for(lambda s:s['attempts']==4 and not s['running'])
                time.sleep(2.3)
                check('unexpected exits stop after three bounded retries', not captures() and state()['attempts']==4, exhausted)
                ipc('close');check('close after exhausted retries cleans state', stopped())
                ipc('open');wait_for(lambda s:s['running']);time.sleep(.3)
                ipc('close');check('close stops real backend', stopped())
                if args.profile: measure('closed-after-playback', 30)
                for _ in range(12):
                    ipc('open');time.sleep(.08);assert len(captures())<=1
                    ipc('close');time.sleep(.08)
                check('rapid media cycles leave no duplicate or orphan', stopped())
                if args.profile: measure('media-recovery-60s', 60)
                ipc('open');wait_for(lambda s:s['running']);time.sleep(.2)
                exit_children=captures()+[p for c in captures() for p in descendants(c)]
                ipc('quit');proc.wait(timeout=4);time.sleep(.3)
                check('isolated shell exit terminates active capture tree', all(not alive(p) for p in exit_children))
            finally:
                stop_playback()
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGTERM)
                    try:proc.wait(timeout=4)
                    except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
                log.flush();log.seek(0);output=log.read()
                assert not any(x in output for x in ['ReferenceError','TypeError','Binding loop','SyntaxError','ERROR']), output
finally:
    stop_playback()
    for module in list(modules.values()):
        subprocess.run(['pactl','unload-module',module],check=True,capture_output=True)
    remaining = [p for p in seen_capture_pids if alive(p)]
    check('all test capture helpers stopped', not remaining, remaining)
    check('default output and input preserved', run('pactl','get-default-sink')==original_sink and run('pactl','get-default-source')==original_source)
    current = {x['index']:x['sink'] for x in json.loads(run('pactl','-f','json','list','sink-inputs'))}
    check('preexisting playback routes unchanged', all(current[i]==sink_id for i,sink_id in original_routes.items() if i in current))
    (args.evidence/'results.json').write_text(json.dumps(dict(passed=passed,checks=records),indent=2))
print(f'RESULT {passed}/{passed} passed', flush=True)
