#!/usr/bin/env python3
"""Deterministic PCM/helper regression. The pw-cat transport here is explicitly simulated."""
import array
import importlib.util
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

sys.dont_write_bytecode = True
helper = Path(__file__).resolve().parents[1]/'scripts/audio-levels.py'
spec = importlib.util.spec_from_file_location('audio_levels', helper)
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)

class AudioHelperTests(unittest.TestCase):
    def test_silence_and_noise_floor(self):
        self.assertEqual(audio.level([]), 0)
        self.assertEqual(audio.level(array.array('h', [0]*533)), 0)
        self.assertEqual(audio.level(array.array('h', [1]*533)), 0)

    def test_known_sine_rms_and_sign(self):
        samples = array.array('h', (round(5000*math.sin(2*math.pi*440*i/16000)) for i in range(16000)))
        expected = (20*math.log10((5000/math.sqrt(2))/32768)+60)/60
        self.assertAlmostEqual(audio.level(samples), expected, places=4)
        self.assertAlmostEqual(audio.level(samples), audio.level(array.array('h', (-x for x in samples))))

    def test_full_scale_bounded(self):
        for value in [-32768, 32767]:
            result = audio.level(array.array('h', [value]*533))
            self.assertGreater(result, .99)
            self.assertLessEqual(result, 1)

    def test_amplitude_is_energy_not_signed_average(self):
        self.assertEqual(audio.level(array.array('h', [-5000, 5000]*266)), audio.level(array.array('h', [5000]*532)))

    def fixture(self, payload, block=False):
        temp = tempfile.TemporaryDirectory(prefix='nm-pcm-')
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        (base/'pcm').write_bytes(payload)
        fake = base/'pw-cat'
        fake.write_text('#!' + sys.executable + '\n' + '''import os,sys,time,json
from pathlib import Path
p=Path(os.environ['NM_PCM_DIR'])
(p/'argv').write_text(json.dumps(sys.argv[1:]))
(p/'pid').write_text(str(os.getpid()))
b=(p/'pcm').read_bytes()
for n in [1,4,17,len(b)]:
 sys.stdout.buffer.write(b[:n]);sys.stdout.buffer.flush();b=b[n:];time.sleep(.002)
if os.environ.get('NM_PCM_BLOCK')=='1':
 while True: time.sleep(1)
''')
        fake.chmod(0o700)
        env = dict(os.environ, PATH=str(base)+os.pathsep+os.environ['PATH'], NM_PCM_DIR=str(base), NM_PCM_BLOCK='1' if block else '0')
        proc = subprocess.Popen([sys.executable, str(helper), 'private-test-sink'], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: self.stop(proc))
        return base, proc

    @staticmethod
    def stop(proc):
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=3)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()
        if proc.stdout: proc.stdout.close()
        if proc.stderr: proc.stderr.close()

    def test_fragmented_complete_pcm_frame(self):
        base, proc = self.fixture(array.array('h', [5000]*533).tobytes())
        stdout, stderr = proc.communicate(timeout=4)
        self.assertEqual(proc.returncode, 3) # complete frame followed by EOF
        self.assertEqual(stdout.splitlines(), [f'{audio.level([5000]*533):.4f}'])
        args = json.loads((base/'argv').read_text())
        self.assertEqual(args[args.index('--target')+1], 'private-test-sink')
        props = json.loads(args[args.index('--properties')+1])
        self.assertTrue(props['stream.capture.sink'])
        self.assertTrue(props['node.dont-reconnect'])
        self.assertTrue(props['node.dont-fallback'])
        self.assertEqual(args[args.index('--format')+1], 's16')
        self.assertEqual(args[args.index('--channels')+1], '1')
        self.assertFalse(stderr)

    def test_truncated_pcm_never_emits_activity(self):
        for payload in [b'', b'\xff', b'\x7f'*1065]:
            _, proc = self.fixture(payload)
            stdout, _ = proc.communicate(timeout=4)
            self.assertEqual(proc.returncode, 3)
            self.assertEqual(stdout, '')

    def test_stop_reaps_blocked_capture_child(self):
        base, proc = self.fixture(b'', block=True)
        until = time.monotonic()+3
        while not (base/'pid').exists() and time.monotonic()<until: time.sleep(.02)
        child = int((base/'pid').read_text())
        proc.terminate(); proc.wait(timeout=3)
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(Path(f'/proc/{child}').exists())

    def test_unavailable_pipewire_emits_no_fake_level(self):
        with tempfile.TemporaryDirectory(prefix='nm-no-pipewire-') as directory:
            env = dict(os.environ, PIPEWIRE_RUNTIME_DIR=directory, PIPEWIRE_REMOTE='missing-server')
            proc = subprocess.run([sys.executable, str(helper), 'missing-sink'], env=env,
                                  capture_output=True, timeout=4)
            self.assertEqual(proc.returncode, 3)
            self.assertEqual(proc.stdout, b'')

    def test_missing_target_rejected(self):
        proc = subprocess.run([sys.executable, str(helper)], capture_output=True, timeout=3)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(proc.stdout, b'')

if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(AudioHelperTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    print(f'RESULT {result.testsRun-len(result.failures)-len(result.errors)}/{result.testsRun} passed')
    raise SystemExit(0 if result.wasSuccessful() else 1)
