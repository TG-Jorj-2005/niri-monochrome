import array,json,math,os,select,subprocess,time
from pathlib import Path
module=None;cap=None;play=None
name='nm_task4_stop_'+str(os.getpid());result={}
try:
 original=subprocess.check_output(['pactl','get-default-sink'],text=True).strip()
 module=subprocess.check_output(['pactl','load-module','module-null-sink','sink_name='+name],text=True).strip()
 cap=subprocess.Popen(['python3','/tmp/nm-task4-probe/scripts/audio-levels.py',name],stdout=subprocess.PIPE)
 play=subprocess.Popen(['pw-cat','--playback','--raw','--target',name,'--rate','16000','--channels','1','--format','s16','-'],stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 # Enough data to keep playback active while the peak is observed, without speaker output.
 pcm=array.array('h',(round(5000*math.sin(2*math.pi*440*i/16000)) for i in range(16000)))
 play.stdin.write(pcm.tobytes());play.stdin.flush()
 os.set_blocking(cap.stdout.fileno(),False)
 def values(seconds):
  data=b'';until=time.monotonic()+seconds
  while time.monotonic()<until:
   if select.select([cap.stdout],[],[],.1)[0]:
    b=os.read(cap.stdout.fileno(),65536)
    if not b:break
    data+=b
  return [float(x) for x in data.splitlines() if x]
 result['during']=values(.6)
 play.terminate();play.wait(timeout=3);play=None
 result['after_stop']=values(4)
 result['default_unchanged']=subprocess.check_output(['pactl','get-default-sink'],text=True).strip()==original
 Path('/tmp/nm-task4-stop-probe.json').write_text(json.dumps(result,indent=2))
 print(json.dumps({k:(dict(frames=len(v),tail=v[-8:]) if isinstance(v,list) else v) for k,v in result.items()}))
finally:
 for proc in [play,cap]:
  if proc and proc.poll() is None:
   proc.terminate()
   try:proc.wait(timeout=3)
   except subprocess.TimeoutExpired:proc.kill();proc.wait()
 if module:subprocess.run(['pactl','unload-module',module],check=True)
