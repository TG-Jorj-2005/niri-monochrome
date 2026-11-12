import json, os, sys, time
from pathlib import Path
pid, duration, dest = int(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
hz = os.sysconf('SC_CLK_TCK'); page=os.sysconf('SC_PAGE_SIZE')
def sample():
 p=Path('/proc')/str(pid)
 s=(p/'stat').read_text().split(') ',1)[1].split()
 children=(p/'task'/str(pid)/'children').read_text().split()
 return dict(t=time.monotonic(),ticks=int(s[11])+int(s[12]),rss_kib=int(s[21])*page//1024,children=children,fds=len(list((p/'fd').iterdir())))
samples=[sample()]
for i in range(duration):
 time.sleep(1); samples.append(sample())
 if (i+1)%60==0: print(json.dumps({'elapsed':i+1,'rss_kib':samples[-1]['rss_kib']}),flush=True)
a,b=samples[0],samples[-1]
result=dict(pid=pid,seconds=b['t']-a['t'],cpu_percent=(b['ticks']-a['ticks'])/hz/(b['t']-a['t'])*100,rss_start_kib=a['rss_kib'],rss_end_kib=b['rss_kib'],rss_min_kib=min(s['rss_kib'] for s in samples),rss_max_kib=max(s['rss_kib'] for s in samples),children_start=a['children'],children_end=b['children'],fds_start=a['fds'],fds_end=b['fds'],samples=samples)
dest.write_text(json.dumps(result,indent=2)); print(json.dumps({k:v for k,v in result.items() if k!='samples'}),flush=True)
