#!/usr/bin/env python3
"""Isolated QML tests: private session bus, runtime/config/state; UI surfaces are disabled."""
import json
import struct
import zlib
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

source = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='nm-qml-') as temp:
    base = Path(temp)
    for sub in ('config/niri-monochrome', 'state', 'runtime', 'wallpapers'):
        (base/sub).mkdir(parents=True, exist_ok=True)
    (base/'runtime').chmod(0o700)
    if source.name == 'selftest-wallpaper.qml':
        def chunk(kind, payload):
            return struct.pack('!I', len(payload)) + kind + payload + struct.pack('!I', zlib.crc32(kind+payload))
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 1, 1, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b'\0\xff\xff\xff')) + chunk(b'IEND', b'')
        (base/'wallpapers/a-bad.png').write_text('not an image')
        (base/'wallpapers/b-good.png').write_bytes(png)
    (base/'config/niri-monochrome/config.json').write_text(json.dumps({
        'shortcuts': {'writeNiriInclude': False}, 'notifications': {'server': False},
        'bar': {'enabled': False}, 'dock': {'enabled': False},
        'wallpaper': {'enabled': False, 'shuffle': False, 'directory': str(base/'wallpapers')},
        'system': {'batteryWarnings': False}, 'nightLight': {'enabled': False},
        'security': {'useShellLock': False}}))
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CONFIG_HOME=str(base/'config'),
               XDG_STATE_HOME=str(base/'state'), XDG_RUNTIME_DIR=str(base/'runtime'))
    env['PIPEWIRE_RUNTIME_DIR'] = os.environ.get('PIPEWIRE_RUNTIME_DIR', os.environ.get('XDG_RUNTIME_DIR', ''))
    if source.name != 'selftest-niri.qml':
        env['NIRI_SOCKET'] = ''
    # Do not activate the host's desktop portals, keyring, or GVFS in a test bus.
    bus_config = base/'bus.conf'
    bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                          '<policy context="default"><allow send_destination="*"/>'
                          '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    env['QT_QPA_PLATFORMTHEME'] = ''
    if source.name in ('shell.qml', 'selftest-qml.qml', 'selftest-wallpaper.qml'):
        display = os.environ.get('WAYLAND_DISPLAY', '')
        if not display:
            raise SystemExit('Wayland backend required for PanelWindow load validation')
        env['QT_QPA_PLATFORM'] = 'wayland'
        env['WAYLAND_DISPLAY'] = display if display.startswith('/') else os.path.join(os.environ['XDG_RUNTIME_DIR'], display)
    else:
        env.pop('WAYLAND_DISPLAY', None)
    with (base/'qml.log').open('w+') as log:
        proc = subprocess.Popen(['dbus-run-session', '--config-file=' + str(bus_config), '--', 'qs', '-p', str(source), '--no-color'],
                                env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            if source.name == 'shell.qml':
                def ipc(*args):
                    return subprocess.run(['qs', '-p', str(source), 'ipc', 'call', 'shell', *args],
                                          env=env, text=True, capture_output=True, timeout=3)
                def ready():
                    for _ in range(40):
                        result = ipc('diagnostics')
                        if result.returncode == 0 and result.stdout.strip().startswith('{'):
                            state = json.loads(result.stdout)
                            assert not state['shellLock'] and not state['shellServerApproved']
                            return
                        if proc.poll() is not None:
                            break
                        time.sleep(.25)
                    raise RuntimeError('shell IPC did not become ready')
                ready()
                for _ in range(3):
                    assert ipc('reload').returncode == 0
                    time.sleep(.5)
                    ready()
                print('PASS actual shell entrypoint + 3 isolated reloads')
            else:
                proc.wait(timeout=20)
                if proc.returncode != 0:
                    raise RuntimeError('QML process exited ' + str(proc.returncode))
        finally:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
                proc.wait(timeout=3)
            except ProcessLookupError:
                pass
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
            log.seek(0)
            output = log.read()
            print(output)
    checked_output = '\n'.join(line for line in output.splitlines() if '[UserConfig]  config.json is not valid JSON:' not in line)
    if any(token in checked_output for token in ('ERROR', 'FAIL', 'ReferenceError', 'TypeError', 'SyntaxError', 'Binding loop')):
        raise SystemExit(1)
    if source.name != 'shell.qml' and 'QMLCHECK DONE' not in output and 'RESULT' not in output:
        raise SystemExit('QML test did not reach its result marker')
