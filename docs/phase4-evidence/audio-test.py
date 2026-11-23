import subprocess,time,json,select,array,math
module=None; capture=None;playback=None
try:
 module=subprocess.check_output(['pactl','load-module','module-null-sink','sink_name=niri_phase4_test','sink_properties=device.description=NiriPhase4Test'],text=True).strip()
 target='niri_phase4_test'
 time.sleep(.4)
 capture=subprocess.Popen(['python3','/home/jorj/.config/quickshell/niri-monochrome/scripts/audio-levels.py',target],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 time.sleep(.4)
 pcm=array.array('h',(int(5000*math.sin(2*math.pi*440*i/16000)) for i in range(32000)))
 playback=subprocess.Popen(['pw-cat','--playback','--raw','--target',target,'--rate','16000','--channels','1','--format','s16','-'],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 playback.stdin.write(pcm.tobytes());playback.stdin.close()
 values=[];until=time.monotonic()+4
 while time.monotonic()<until:
  ready,_,_=select.select([capture.stdout],[],[],.2)
  if ready:
   line=capture.stdout.readline().strip()
   if not line:break
   values.append(float(line))
 print(json.dumps({'frames':len(values),'peak':max(values) if values else None,'stimulus':'440 Hz PCM routed to a temporary virtual sink; no speaker playback'}))
 if not values or max(values)<.1:
  capture.terminate();print(capture.stderr.read());raise SystemExit('No measured amplitude')
finally:
 for p in [capture,playback]:
  if p and p.poll() is None:
   p.terminate()
   try:p.wait(timeout=3)
   except subprocess.TimeoutExpired:p.kill();p.wait()
 if module:subprocess.run(['pactl','unload-module',module],check=True)
print('Temporary output and capture processes cleaned up')
