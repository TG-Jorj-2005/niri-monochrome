#!/usr/bin/env python3
"""Isolated QML tests: private session bus, runtime/config/state; UI surfaces are disabled."""
import json
import re
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
    for sub in ('config/niri-monochrome', 'config/niri', 'state', 'runtime', 'wallpapers'):
        (base/sub).mkdir(parents=True, exist_ok=True)
    (base/'runtime').chmod(0o700)
    if source.name == 'selftest-wallpaper.qml':
        def chunk(kind, payload):
            return struct.pack('!I', len(payload)) + kind + payload + struct.pack('!I', zlib.crc32(kind+payload))
        png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 1, 1, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b'\0\xff\xff\xff')) + chunk(b'IEND', b'')
        (base/'wallpapers/a-bad.png').write_text('not an image')
        (base/'wallpapers/b-good.png').write_bytes(png)
    if source.name in ('selftest-overlay.qml', 'selftest-interactions.qml', 'selftest-shortcut-ui.qml', 'selftest-shortcut-focus.qml'):
        (base/'config/niri/binds.kdl').write_text('binds {\n Mod+D hotkey-overlay-title="Launcher" { spawn "fuzzel"; }\n Mod+A hotkey-overlay-title="Dock" { spawn "qs"; }\n}\n')
    # The glass-only fixture instantiates no desktop services: exercise missing-file recovery.
    if source.name != 'selftest-glass.qml':
        (base/'config/niri-monochrome/config.json').write_text(json.dumps({
            'shortcuts': {'writeNiriInclude': False}, 'notifications': {'server': False},
            'bar': {'enabled': False}, 'dock': {'enabled': False},
            'wallpaper': {'enabled': False, 'shuffle': False, 'directory': str(base/'wallpapers')},
            'system': {'batteryWarnings': False}, 'nightLight': {'enabled': False},
            'security': {'useShellLock': False}}))
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', XDG_CONFIG_HOME=str(base/'config'),
               XDG_STATE_HOME=str(base/'state'), XDG_RUNTIME_DIR=str(base/'runtime'))
    env.pop('NM_GLASS_RESTORE', None)
    env.pop('NM_SETTINGS_RESTORE', None)
    if source.name == 'selftest-settings-search.qml':
        # DesktopEntries watches only this private writable application directory.
        apps = base/'data/applications'
        apps.mkdir(parents=True)
        env['XDG_DATA_HOME'] = str(base/'data')
        for suffix in ('alpha', 'beta'):
            (apps/('nm-task6-' + suffix + '.desktop')).write_text(
                '[Desktop Entry]\nType=Application\nName=NM Task6 ' + suffix.title() +
                '\nExec=true\nIcon=application-x-executable\n')
        config_file = base/'config/niri-monochrome/config.json'
        config = json.loads(config_file.read_text())
        config['dock']['favorites'] = []
        config_file.write_text(json.dumps(config))
    env['PIPEWIRE_RUNTIME_DIR'] = os.environ.get('PIPEWIRE_RUNTIME_DIR', os.environ.get('XDG_RUNTIME_DIR', ''))
    if source.name != 'selftest-niri.qml':
        env['NIRI_SOCKET'] = ''
    # Do not activate the host's desktop portals, keyring, or GVFS in a test bus.
    bus_config = base/'bus.conf'
    bus_config.write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>'
                          '<policy context="default"><allow send_destination="*"/>'
                          '<allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
    env['QT_QPA_PLATFORMTHEME'] = ''
    if source.name in ('shell.qml', 'selftest-qml.qml', 'selftest-wallpaper.qml', 'selftest-phase4.qml', 'selftest-overlay.qml', 'selftest-interactions.qml', 'selftest-shortcut-ui.qml', 'selftest-shortcut-focus.qml'):
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
                appearance_file = base/'config/niri/niri-monochrome-appearance.kdl'
                if appearance_file.exists():
                    subprocess.run(['niri','validate','-c',str(appearance_file)],env=env,check=True,capture_output=True)
                    print('PASS generated appearance KDL validation')
                print('PASS actual shell entrypoint + 3 isolated reloads')
            else:
                proc.wait(timeout=20)
                if proc.returncode != 0:
                    raise RuntimeError('QML process exited ' + str(proc.returncode))
                if source.name == 'selftest-settings-search.qml':
                    restore_env = dict(env, NM_SETTINGS_RESTORE='1')
                    proc = subprocess.Popen(['dbus-run-session', '--config-file=' + str(bus_config),
                                             '--', 'qs', '-p', str(source), '--no-color'],
                                            env=restore_env, stdout=log, stderr=subprocess.STDOUT,
                                            start_new_session=True)
                    proc.wait(timeout=20)
                    if proc.returncode != 0:
                        raise RuntimeError('Settings restore process exited ' + str(proc.returncode))
                if source.name == 'selftest-shortcut-ui.qml':
                    restore = source.with_name('selftest-shortcut-restore.qml')
                    proc = subprocess.Popen(['dbus-run-session', '--config-file=' + str(bus_config),
                                             '--', 'qs', '-p', str(restore), '--no-color'],
                                            env=env, stdout=log, stderr=subprocess.STDOUT,
                                            start_new_session=True)
                    proc.wait(timeout=20)
                    if proc.returncode != 0:
                        raise RuntimeError('Shortcut restore process exited ' + str(proc.returncode))
                    subprocess.run(['niri', 'validate', '-c', str(base/'config/niri/config.kdl')],
                                   env=env, check=True, capture_output=True)
                    print('PASS private shortcut source configuration validates after process restart')
                if source.name == 'selftest-glass.qml':
                    appearance_file = base/'config/niri/niri-monochrome-appearance.kdl'
                    before_restart = appearance_file.stat().st_mtime_ns
                    subprocess.run(['niri', 'validate', '-c', str(appearance_file)], env=env,
                                   check=True, capture_output=True)
                    # Restart the actual singleton with the same private persisted settings.
                    restart_env = dict(env, NM_GLASS_RESTORE='1')
                    proc = subprocess.Popen(['dbus-run-session', '--config-file=' + str(bus_config),
                                             '--', 'qs', '-p', str(source), '--no-color'],
                                            env=restart_env, stdout=log, stderr=subprocess.STDOUT,
                                            start_new_session=True)
                    proc.wait(timeout=20)
                    if proc.returncode != 0:
                        raise RuntimeError('QML restore process exited ' + str(proc.returncode))
                    assert appearance_file.stat().st_mtime_ns == before_restart, 'Appearance rewritten on restart'
                    print('PASS generated glass KDL validation + no rewrite across process restart')
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
    for passed, total in re.findall(r'RESULT (\d+)/(\d+) passed', output):
        if passed != total:
            raise SystemExit('Incomplete or failed assertion count')
    if source.name != 'shell.qml' and 'QMLCHECK DONE'  not in output and 'RESULT' not in output:
        raise SystemExit('QML test did not reach its result marker')
