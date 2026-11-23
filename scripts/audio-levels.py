#!/usr/bin/env python3
"""Real PipeWire sink-monitor RMS at ~30 Hz. Emits one bounded normalized level per line.
This is amplitude history, not an FFT. No microphone or auto-target fallback is used.
"""
import array
import ctypes
import math
import os
import signal
import subprocess
import sys

def level(samples):
    if not samples: return 0.0
    rms=math.sqrt(sum(v*v for v in samples)/len(samples))/32768
    return max(0.0,min(1.0,(20*math.log10(max(rms,1e-9))+60)/60))

def parent_guard():
    # Kernel cleanup also applies if the owning QML/Python process crashes.
    ctypes.CDLL(None).prctl(1,signal.SIGTERM)
    if os.getppid()==1: os._exit(1)

def main():
    if len(sys.argv)!=2 or not sys.argv[1]: return 2
    parent_guard()
    def stop(*_): raise KeyboardInterrupt
    signal.signal(signal.SIGTERM,stop)
    command=['pw-cat','--record','--raw','--target',sys.argv[1],
             '--rate','16000','--channels','1','--format','s16',
             '--properties','{"stream.capture.sink":true,"node.dont-reconnect":true,"node.dont-fallback":true,"node.passive":true,"media.role":"Analyzer","node.name":"niri-monochrome-visualizer"}','-']
    child=None
    try:
        child=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,preexec_fn=parent_guard)
        while True:
            frame=child.stdout.read(1066)
            if len(frame)!=1066: return 3
            samples=array.array('h');samples.frombytes(frame)
            if sys.byteorder!='little': samples.byteswap()
            print(f'{level(samples):.4f}',flush=True)
    except (KeyboardInterrupt,BrokenPipeError): return 0
    except OSError: return 2
    finally:
        if child is not None:
            child.terminate()
            try: child.wait(timeout=2)
            except subprocess.TimeoutExpired: child.kill();child.wait()

if __name__=='__main__': sys.exit(main())
