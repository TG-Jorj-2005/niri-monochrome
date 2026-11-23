"""Profile only an owned private copy while the real session is locked.

Uses the actual shell entrypoint, private session bus/config/state and real Wayland.
Never calls a lock/power/device action or changes real user settings.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

source = Path('/tmp/nm-task6-probe')
evidence = Path(__file__).resolve().parent
hz = os.sysconf('SC_CLK_TCK')
page = os.sysconf('SC_PAGE_SIZE')
results = []
with tempfile.TemporaryDirectory(prefix='nm-task6-lifecycle-') as temp:
    base = Path(temp)
    project = base/'project'
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', 'docs'))
    shell = project/'shell.qml'
    text = shell.read_text().replace('    Settings {}', '    Settings { id: task6Settings }')
    # Test-only observation/input adapter; production shell is never edited by this harness.
    adapter = '''
    function task6Field(item) {
        if (item.placeholder === "Add application…") return item
        for (const child of item.children || []) { const f = task6Field(child); if (f) return f }
        return null
    }
    IpcHandler { target: "task6"
        function info(): string { return JSON.stringify({settings:ShellState.settingsOpen,
            settingsSection:ShellState.settingsSection,locked:LockService.locked,
            playing:MediaService.playing,query:root.task6Field(task6Settings.contentItem)?.text || ""}) }
        function query(text: string): void { root.task6Field(task6Settings.contentItem).text = text }
    }
'''
    shell.write_text(text.rsplit('}', 1)[0] + adapter + '}\n')
    for sub in ('config/niri-monochrome', 'config/niri', 'state', 'runtime'):
        (base/sub).mkdir(parents=True)
    (base/'runtime').chmod(0o700)
    config = {'security': {'useShellLock': False}, 'shortcuts': {'writeNiriInclude': False},
              'notifications': {'server': False, 'shellServerApproved': False},
              'bar': {'enabled': False}, 'dock': {'enabled': True},
              'wallpaper': {'enabled': False, 'shuffle': False},
              'nightLight': {'enabled': False}, 'system': {'batteryWarnings': False}}
    (base/'config/niri-monochrome/config.json').write_text(json.dumps(config))
    config_before = (base/'config/niri-monochrome/config.json').read_bytes()
    for name in ('config.kdl', 'input.kdl', 'binds.kdl', 'niri-monochrome.kdl'):
        original = Path('/home/jorj/.config/niri')/name
        if original.exists(): shutil.copy2(original, base/'config/niri'/name)
    bus = base/'bus.conf'
    bus.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                   '<policy context="default"><allow send_destination="*"/>'
                   '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    env = dict(os.environ, XDG_CONFIG_HOME=str(base/'config'), XDG_STATE_HOME=str(base/'state'),
               XDG_RUNTIME_DIR=str(base/'runtime'), PIPEWIRE_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],
               WAYLAND_DISPLAY=str(Path(os.environ['XDG_RUNTIME_DIR'])/os.environ['WAYLAND_DISPLAY']),
               QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='', NIRI_SOCKET='')
    def ipc(target, method, *args):
        p = subprocess.run(['qs', '-p', str(shell), 'ipc', 'call', target, method, *map(str, args)],
                           env=env, capture_output=True, text=True, timeout=4)
        if p.returncode: raise RuntimeError(p.stderr + p.stdout)
        return p.stdout.strip()
    def diag(): return json.loads(ipc('shell', 'diagnostics'))
    def sample():
        p = Path('/proc')/str(pid)
        st = (p/'stat').read_text().split(') ', 1)[1].split()
        memory = (p/'smaps_rollup').read_text().splitlines()
        private = sum(int(l.split()[1]) for l in memory if l.startswith(('Private_Clean:', 'Private_Dirty:')))
        fds = list((p/'fd').iterdir())
        watches = {}
        for f in fds:
            try:
                if 'inotify' in os.readlink(f): watches[f.name] = (p/'fdinfo'/f.name).read_text().count('inotify wd:')
            except FileNotFoundError: pass
        return dict(t=time.monotonic(), ticks=int(st[11])+int(st[12]), rssKiB=int(st[21])*page//1024,
                    privateKiB=private, fds=len(fds), children=(p/'task'/str(pid)/'children').read_text().split(),
                    inotify=watches)
    def record(name, operation):
        before = sample()
        operation()
        after = sample()
        row = dict(name=name, seconds=after['t']-before['t'], before=before, after=after,
                   cpuPercent=(after['ticks']-before['ticks'])/hz/(after['t']-before['t'])*100,
                   diagnostics=diag(), info=json.loads(ipc('task6', 'info')))
        results.append(row)
        (evidence/'private-lifecycle.json').write_text(json.dumps(results, indent=2))
        print(json.dumps({k:v for k,v in row.items() if k not in ('before','after')}), flush=True)
    def quiet(seconds):
        # Sampling each second bounds process/resource observations without polling the shell.
        for _ in range(seconds): time.sleep(1); quiet_samples.append(sample())
    def cycles(target, method, close_target, close_method, expected):
        for _ in range(12):
            ipc(target, method); time.sleep(.2)
            d = diag()
            assert not json.loads(ipc('task6','info'))['locked']
            if expected: assert d['overlay'] == expected
            if target == 'dock': assert d['dock'] and not d['overlay']
            ipc(close_target, close_method); time.sleep(.2)
            d = diag(); assert d['overlay'] == '' and not d['dock']
            assert not d['visualizer'] and d['visualizerWatchers'] == 0
    quiet_samples = []
    proc = None
    pid = None
    log = (evidence/'private-lifecycle-qml.log').open('w')
    try:
        proc = subprocess.Popen(['dbus-run-session', '--config-file='+str(bus), '--', 'qs', '-p', str(shell), '--no-color'],
                                env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        for _ in range(60):
            try:
                candidates = (Path('/proc')/str(proc.pid)/'task'/str(proc.pid)/'children').read_text().split()
                pid = next(int(c) for c in candidates if str(shell).encode() in (Path('/proc')/c/'cmdline').read_bytes())
                if diag()['overlay'] == '': break
            except (OSError, StopIteration, RuntimeError, ValueError): pass
            time.sleep(.1)
        else: raise RuntimeError('Private shell did not become ready')
        time.sleep(3)
        record('private-closed-initial-30s', lambda: quiet(30))
        for target, method, closer, close_method, expected in [
            ('launcher','open','launcher','close','launcher'),
            ('settings','open','settings','toggle',''),
            ('controlcenter','toggle','launcher','close','control'),
            ('notifications','toggle','launcher','close','notifications'),
            ('shortcuts','open','shortcuts','close','shortcuts'),
            ('dock','toggle','dock','hide',''),
            ('media','toggle','launcher','close','media')]:
            record(target+'-12-open-close', lambda t=target,m=method,c=closer,cm=close_method,x=expected: cycles(t,m,c,cm,x))
        def queries():
            ipc('settings','section',2);time.sleep(.3)
            for _ in range(20):
                for q in ('fire','term','nau','settings'): ipc('task6','query',q)
            ipc('settings','toggle'); time.sleep(.3)
        record('settings-dock-80-search-assignments', queries)
        record('closed-recovery-30s', lambda: quiet(30))
        record('closed-recovery-next-60s', lambda: quiet(60))
        def reload():
            assert not json.loads(ipc('task6','info'))['locked']
            ipc('shell','reload')
            for _ in range(60):
                try:
                    if diag()['overlay']=='':return
                except (RuntimeError, ValueError):pass
                time.sleep(.1)
            raise RuntimeError('Private reload did not recover')
        record('supported-private-reload', reload)
        record('post-reload-closed-60s', lambda: quiet(60))
        assert (base/'config/niri-monochrome/config.json').read_bytes() == config_before
        print('PASS private settings unchanged; actual entrypoint lifecycle and reload complete',flush=True)
    finally:
        (evidence/'private-lifecycle-quiet-samples.json').write_text(json.dumps(quiet_samples,indent=2))
        if proc:
            try: os.killpg(proc.pid, signal.SIGTERM);proc.wait(timeout=5)
            except ProcessLookupError:pass
            except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
        log.close()
