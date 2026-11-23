import subprocess,time,json,os,signal
from pathlib import Path
helper=Path('/home/jorj/.config/quickshell/niri-monochrome/scripts/audio-levels.py')
def run(*cmd):return subprocess.check_output(cmd,text=True).strip()
def graph():
 data=json.loads(run('pw-dump')); nodes={x['id']:x.get('info',{}).get('props',{}) for x in data if x['type'].endswith(':Node')}
 captures={i:p for i,p in nodes.items() if str(p.get('application.process.id'))==str(capture_child) or p.get('node.name')=='niri-monochrome-visualizer'}
 links=[]
 for x in data:
  if not x['type'].endswith(':Link'):continue
  a=x.get('info',{}).get('output-node-id');b=x.get('info',{}).get('input-node-id')
  if b in captures: links.append({'from':nodes.get(a,{}).get('node.name'),'to':b})
 return dict(nodes=captures,links=links)
module=None;cap=None;capture_child=None;result={};original=run('pactl','get-default-sink')
try:
 module=run('pactl','load-module','module-null-sink','sink_name=nm_task4_probe','sink_properties=device.description=NMTask4Probe')
 cap=subprocess.Popen(['python3',str(helper),'nm_task4_probe'],stdout=subprocess.DEVNULL,start_new_session=True)
 for _ in range(30):
  children=Path(f'/proc/{cap.pid}/task/{cap.pid}/children').read_text().split()
  if children:capture_child=int(children[0]);break
  time.sleep(.05)
 time.sleep(.6);result['before_removal']=graph()
 run('pactl','unload-module',module);module=None
 time.sleep(1.2);result['after_removal']=graph();result['helper_returncode']=cap.poll()
 assert run('pactl','get-default-sink')==original
 print(json.dumps(result,indent=2));Path('/tmp/nm-task4-target-before.json').write_text(json.dumps(result,indent=2))
finally:
 if cap and cap.poll() is None:
  cap.terminate()
  try:cap.wait(timeout=3)
  except subprocess.TimeoutExpired:os.killpg(cap.pid,signal.SIGKILL);cap.wait()
 if module:run('pactl','unload-module',module)
