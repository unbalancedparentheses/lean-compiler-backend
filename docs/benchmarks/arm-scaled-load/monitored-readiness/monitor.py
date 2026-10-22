#!/usr/bin/env python3
"""Privacy-preserving operational-load monitor. Does NOT launch a benchmark.
Prepared only. Run after gates stop; any threshold/read failure is fail-closed.
Raw process names/PIDs are used only in memory, never written to reports.
"""
import argparse,ctypes,hashlib,json,os,queue,subprocess,threading,time
from pathlib import Path
GUEST=r'''
import os,time,json,sys
from pathlib import Path
work=Path(sys.argv[1]);period=float(sys.argv[2]);hz=os.sysconf('SC_CLK_TCK');mine=os.getpid();known={};previous=0
manifest=json.loads((work/'manifest.json').read_text());drivers={str(work/label/'driver') for label in manifest['backends']};probe=str(work/'probe.py')
def snap():
 global previous
 processes={};controllers=set()
 for path in Path('/proc').iterdir():
  if not path.name.isdigit():continue
  try:
   raw=(path/'stat').read_text();tail=raw[raw.rfind(')')+2:].split();pid=int(path.name);own=int(tail[11])+int(tail[12]);children=int(tail[13])+int(tail[14]);parent=int(tail[1]);cmd=(path/'cmdline').read_bytes().split(bytes([0]));exe=os.readlink(path/'exe');processes[pid]=(parent,own,children,exe)
   if len(cmd)>=4 and cmd[1].decode()==probe and cmd[3]==b'time':controllers.add(pid)
  except (FileNotFoundError,ProcessLookupError,PermissionError):continue
 for pid in controllers:
  parent,own,dead,exe=processes[pid];live=sum(row[1]+row[2] for child,row in processes.items() if row[0]==pid and row[3] in drivers)
  # Re-read controller after children: changed waited-child count means this
  # sample raced a child exit. Fail closed instead of subtracting twice.
  raw=Path('/proc',str(pid),'stat').read_text();t=raw[raw.rfind(')')+2:].split();assert int(t[13])+int(t[14])==dead,'controller child-accounting race'
  value=own+dead+live;assert value>=known.get(pid,0),'nonmonotonic controller CPU';known[pid]=value
 allowed=sum(known.values())+processes.get(mine,(0,0,0,''))[1];assert allowed>=previous,'nonmonotonic allowed CPU';previous=allowed
 cpu={};running=None
 for line in Path('/proc/stat').read_text().splitlines():
  if line.startswith('procs_running '):running=int(line.split()[1])
  if line.startswith('cpu'):
   fields=line.split();cpu[fields[0]]=[int(x) for x in fields[1:9]]
 return {'monotonic':time.monotonic(),'utc':time.time(),'hz':hz,'cpu':cpu,'allowed_ticks':allowed,'active_controllers':len(controllers),'process_count':len(processes),'runnable_count':running,'load':os.getloadavg()}
while True:
 try:print(json.dumps(snap()),flush=True)
 except BaseException as e:print(json.dumps({'error':'guest snapshot unavailable: '+type(e).__name__}),flush=True);break
 time.sleep(period)
'''

def cpu_seconds(text):
 days=0
 if '-' in text:day,text=text.split('-',1);days=int(day)
 parts=[float(x) for x in text.split(':')];assert 1<=len(parts)<=3
 return days*86400+sum(x*60**i for i,x in enumerate(reversed(parts)))

def host_snapshot(lib):
 count=ctypes.c_uint32(4);values=(ctypes.c_uint32*4)();rc=lib.host_statistics(lib.mach_host_self(),3,values,ctypes.byref(count));assert rc==0 and count.value==4,'host CPU counters unavailable'
 raw=subprocess.check_output(['/bin/ps','-axo','pid=,ppid=,time=,comm='],text=True);rows={}
 for line in raw.splitlines():
  fields=line.strip().split(None,3)
  if len(fields)==4:rows[int(fields[0])]=(int(fields[1]),cpu_seconds(fields[2]),fields[3])
 return {'monotonic':time.monotonic(),'ticks':list(values),'rows':rows,'load':os.getloadavg()}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',required=True,type=Path);p.add_argument('--out',required=True,type=Path);p.add_argument('--vm-pid',required=True,type=int);p.add_argument('--controller-pid',type=int);p.add_argument('--container',default='lcb-parity-linux');p.add_argument('--preflight-seconds',type=float,default=120);p.add_argument('--maximum-seconds',type=float,default=1200);a=p.parse_args();assert a.preflight_seconds==120 and a.maximum_seconds>=120
 assert not a.out.exists();a.out.mkdir(parents=True);work=a.work.resolve();base=Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64');assert work.is_relative_to(base)
 manifest=work/'manifest.json';manifest_hash=hashlib.sha256(manifest.read_bytes()).hexdigest();lib=ctypes.CDLL('/usr/lib/libSystem.B.dylib');lib.mach_host_self.restype=ctypes.c_uint32;lib.host_statistics.argtypes=[ctypes.c_uint32,ctypes.c_int,ctypes.POINTER(ctypes.c_uint32),ctypes.POINTER(ctypes.c_uint32)];cores=int(subprocess.check_output(['/usr/sbin/sysctl','-n','hw.logicalcpu'],text=True))
 period=2.;guestwork='/work/'+work.relative_to(base).as_posix();child=subprocess.Popen(['docker','exec',a.container,'python3','-u','-c',GUEST,guestwork,str(period)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);messages=queue.Queue()
 def reader():
  for line in child.stdout:messages.put(line)
  messages.put(None)
 threading.Thread(target=reader,daemon=True).start();report={'status':'running','qualification':'operational load thresholds only, not hardware isolation','manifest_sha256':manifest_hash,'monitor_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'logical_cpus':cores,'thresholds':{'external_host_aggregate_core_equivalents':.25,'external_host_max_process_core_equivalents':.10,'guest_nonbenchmark_core_equivalents':.10,'maximum_gap_seconds':5},'samples':[]};start=time.monotonic();prior=None;ready=False
 def save():(a.out/'report.json').write_text(json.dumps(report,indent=2))
 try:
  while time.monotonic()-start<a.maximum_seconds:
   raw=messages.get(timeout=5);assert raw is not None,'guest monitor ended';g=json.loads(raw);assert 'error' not in g,g.get('error');h=host_snapshot(lib);assert a.vm_pid in h['rows'],'VM process disappeared'
   vm_name=h['rows'][a.vm_pid][2];assert vm_name.endswith('/OrbStack Helper') or vm_name.endswith('/com.docker.virtualization') or vm_name.endswith('/qemu-system-aarch64'),'unrecognized VM process; do not guess exclusions'
   excluded={a.vm_pid,os.getpid()}
   if a.controller_pid:
    assert a.controller_pid in h['rows'],'controller disappeared';excluded.add(a.controller_pid)
   # Only descendants of this monitor and the explicit benchmark wrapper
   # (protocol helper/ps/docker clients) are additional exclusions.
   descendants={os.getpid()} | ({a.controller_pid} if a.controller_pid else set())
   for _ in range(4):descendants|={pid for pid,row in h['rows'].items() if row[0] in descendants}
   excluded|=descendants
   if prior:
    oldh,oldg=prior;dt=h['monotonic']-oldh['monotonic'];gd=g['monotonic']-oldg['monotonic'];assert 0<dt<=5 and 0<gd<=5,'monitor gap'
    ticks=[(x-y)&0xffffffff for x,y in zip(h['ticks'],oldh['ticks'])];assert sum(ticks)>0,'host counter stalled';host_busy=cores*(sum(ticks)-ticks[2])/sum(ticks)
    deltas={pid:max(0,row[1]-oldh['rows'].get(pid,(0,0,''))[1])/dt for pid,row in h['rows'].items()};allowed=sum(deltas.get(pid,0) for pid in excluded);outside=max(0,host_busy-allowed);maxoutside=max([v for pid,v in deltas.items() if pid not in excluded] or [0])
    gt=[x-y for x,y in zip(g['cpu']['cpu'],oldg['cpu']['cpu'])];assert min(gt)>=0,'guest counters reversed';guestbusy=(sum(gt)-gt[3]-gt[4])/g['hz']/gd;guestallowed=(g['allowed_ticks']-oldg['allowed_ticks'])/g['hz']/gd;assert guestallowed>=0;guestoutside=max(0,guestbusy-guestallowed)
    percore={}
    for key,current in g['cpu'].items():
     if key=='cpu':continue
     delta=[x-y for x,y in zip(current,oldg['cpu'][key])];assert min(delta)>=0;percore[key]=(sum(delta)-delta[3]-delta[4])/sum(delta) if sum(delta) else 0
    sample={'utc':g['utc'],'host_total_core_equivalents':host_busy,'outside_host_core_equivalents':outside,'maximum_outside_process_core_equivalents':maxoutside,'host_load':h['load'],'host_process_count':len(h['rows']),'guest_busy_core_equivalents':guestbusy,'guest_nonbenchmark_core_equivalents':guestoutside,'guest_per_core_busy_fractions':percore,'guest_steal_delta_seconds':gt[7]/g['hz'],'guest_runnable_count':g['runnable_count'],'guest_load':g['load'],'guest_process_count':g['process_count'],'guest_active_controllers':g['active_controllers'],'host_gap_seconds':dt,'guest_gap_seconds':gd}
    violations=[]
    if outside>.25:violations.append('host aggregate load')
    if maxoutside>.10:violations.append('host individual load')
    if guestoutside>.10:violations.append('guest nonbenchmark load')
    sample['violations']=violations;report['samples'].append(sample);save();assert not violations,', '.join(violations)
    if not ready and time.monotonic()-start>=a.preflight_seconds:
     ready=True;report['preflight']='passed';(a.out/'READY').write_text('Operational thresholds passed; not exclusive hardware isolation. Monitor remains active.\n');save()
   prior=(h,g)
   if (a.out/'STOP').exists():assert ready,'stopped before readiness';report['status']='passed-operational-load-monitor';break
  else:raise AssertionError('monitor maximum duration reached without explicit completion marker')
  assert hashlib.sha256(manifest.read_bytes()).hexdigest()==manifest_hash,'manifest changed'
 except BaseException as e:
  report['status']='unqualified';report['error']=type(e).__name__+': '+str(e)
  (a.out/'FAILED').write_text(report['error']+'\n')
 finally:
  child.terminate()
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  save()
 if report['status']!='passed-operational-load-monitor':raise SystemExit(1)
if __name__=='__main__':main()
