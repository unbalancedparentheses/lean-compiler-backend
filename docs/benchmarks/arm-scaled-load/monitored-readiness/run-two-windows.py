#!/usr/bin/env python3
"""Prepared monitored timing campaign. Run ONLY after root releases active gates.
Never launches automatically; refuses <18min reserve. Does not stop external jobs.
"""
from pathlib import Path
from datetime import datetime,timezone
import argparse,hashlib,json,subprocess,os,time,shutil,signal

# Emergency cleanup is scoped to the exact campaign probe/driver paths only.
# Raw process data stays in guest memory; only a count is returned.
CLEANUP = r"""
from pathlib import Path
import os,sys,signal,json
work=Path(sys.argv[1]);m=json.loads((work/'manifest.json').read_text())
drivers={str(work/k/'driver') for k in m['backends']};selected=set()
for p in Path('/proc').iterdir():
 if not p.name.isdigit():continue
 try:
  cmd=(p/'cmdline').read_bytes().split(bytes([0]));exe=os.readlink(p/'exe')
  if exe in drivers or (len(cmd)>=4 and cmd[1].decode()==str(work/'probe.py') and cmd[2].decode()==str(work) and cmd[3]==b'time'):selected.add(int(p.name))
 except (FileNotFoundError,ProcessLookupError,PermissionError):pass
for pid in selected:
 try:os.kill(pid,signal.SIGTERM)
 except ProcessLookupError:pass
print(json.dumps({'owned_guest_processes_signalled':len(selected)}))
"""

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--work',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--deadline',default='2026-10-22T14:43:29+00:00');ap.add_argument('--root',type=Path,default=Path('/Users/unbalancedparen/projects/lean-compiler-backend'));a=ap.parse_args();deadline=datetime.fromisoformat(a.deadline).timestamp();remaining=lambda:deadline-time.time();assert remaining()>=18*60,'18-minute reserve unavailable: no monitor or benchmark started';assert not a.out.exists();root=a.root.resolve();work=a.work.resolve();out=a.out.resolve();assert work.is_relative_to(root/'.build/linux-arm64');prepared=Path(__file__).parent;sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 # Verify the frozen preparation and the untouched five-label build manifest.
 binding=json.loads((prepared/'prepared-manifest.json').read_text());assert all(sha(prepared/k)==v for k,v in binding.items());manifest=work/'manifest.json';m=json.loads(manifest.read_text());script=root/'scripts/zlib_inprocess.py';assert sha(script)==m['script_sha256'];assert m['lcb_labels']==['predecessor','combined-scaled'];assert m['backends']['combined-scaled']['compiler_identity']=='e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e';assert m['backends']['predecessor']['compiler_identity'].startswith('4b41bddb');assert not (work/'timing.json').exists(),'fresh prepared timing directory required'
 provenance=json.loads((work/'provenance.json').read_text());assert provenance[-1]['stage']=='after_correctness' and provenance[-1]['status']=='passed' and provenance[-1]['bound_files_checked_host_and_guest']==485
 for name,h in provenance[-1]['reports_guest_host_sha256'].items():assert sha(work/name)==h
 # Discover exactly one real OrbStack VM helper, without persisting process data.
 context=subprocess.check_output(['docker','context','show'],text=True).strip();assert context=='orbstack','unsupported runtime: fail closed'
 expected_vm='/Applications/OrbStack.app/Contents/Frameworks/OrbStack Helper.app/Contents/MacOS/OrbStack Helper'
 def vm_pid():
  raw=subprocess.check_output(['/bin/ps','-axo','pid=,comm='],text=True);matches=[]
  for line in raw.splitlines():
   row=line.strip().split(None,1)
   if len(row)==2 and row[1]==expected_vm:matches.append(int(row[0]))
  assert len(matches)==1,'VM helper identity not unique/available';return matches[0]
 vm=vm_pid();assert remaining()>=18*60,'reserve lost during readiness validation';out.mkdir(parents=True);monout=out/'load-monitor';report={'status':'preflight','protocol':{'windows':2,'rounds':9,'batch_ms':250,'warmups':2,'reserve_minutes':18},'deadline_utc':a.deadline,'manifest_sha256':sha(manifest),'prepared_hashes':binding,'windows':[],'privacy':'No raw process names/PIDs/cwd lists retained; VM verified privately by exact process executable name.'};monitor=None;active=None
 def save():(out/'campaign.json').write_text(json.dumps(report,indent=2))
 def intact():assert sha(manifest)==report['manifest_sha256'] and sha(script)==m['script_sha256'];assert all(sha(prepared/k)==v for k,v in binding.items());assert vm_pid()==vm,'VM process changed'
 def archive(n):
  d=out/f'window{n}';d.mkdir()
  for f in work.iterdir():
   if f.is_file() and f.suffix in ['.json','.log','.py','.c']:shutil.copy2(f,d/f.name)
  shutil.copy2(script,d/'protocol-script.py')
  if (monout/'report.json').exists():shutil.copy2(monout/'report.json',d/'load-monitor-at-end.json')
  return d
 try:
  for f in prepared.glob('*.py'):shutil.copy2(f,out/f.name)
  shutil.copy2(prepared/'protocol.json',out/'protocol.json');shutil.copy2(prepared/'prepared-manifest.json',out/'prepared-manifest.json')
  log=(out/'monitor.log').open('w');monitor=subprocess.Popen(['python3',str(prepared/'monitor.py'),'--work',str(work),'--out',str(monout),'--vm-pid',str(vm),'--controller-pid',str(os.getpid()),'--maximum-seconds',str(int(remaining()-30))],stdout=log,stderr=subprocess.STDOUT);save()
  while not (monout/'READY').exists():
   assert monitor.poll() is None and not (monout/'FAILED').exists(),'operational preflight failed; no benchmark started';assert remaining()>15*60,'insufficient reserve after preflight';time.sleep(.25)
  assert monitor.poll() is None and not (monout/'FAILED').exists();report['status']='measurement';save()
  command=['python3',str(script),'--work',str(work),'--phase','time','--samples','9','--batch-ms','250','--warmups','2','--cpu','0']
  for n in [1,2]:
   intact();assert monitor.poll() is None and not (monout/'FAILED').exists(),'monitor unqualified; no next window';assert remaining()>(8*60 if n==1 else 5*60),'insufficient conservative remaining reserve for next window'
   with (out/f'window{n}-phase.log').open('w') as phase_log:
    active=subprocess.Popen(command,stdout=phase_log,stderr=subprocess.STDOUT,start_new_session=True)
    while active.poll() is None:
     # A load failure disqualifies the whole active window; let its bounded
     # phase complete/postvalidate rather than cherry-picking partial samples.
     assert remaining()>45,'deadline guard reached';time.sleep(.5)
   exitcode=active.returncode;active=None;d=archive(n);assert exitcode==0,('timing phase failed',n,exitcode)
   timing=json.loads((d/'timing.json').read_text());prov=json.loads((d/'provenance.json').read_text());assert timing['status']=='completed' and len(timing['samples'])==135 and timing['sink_agreement']=='all labels and rounds';assert prov[-1]['stage']=='after_timing' and prov[-1]['status']=='passed' and prov[-1]['bound_files_checked_host_and_guest']==485;assert prov[-1]['reports_guest_host_sha256']['timing.json']==sha(d/'timing.json');intact()
   clean=monitor.poll() is None and not (monout/'FAILED').exists();report['windows'].append({'window':n,'command':command,'phase_exit':exitcode,'records':135,'sinks':'passed','own_provenance':'passed','operational_load_qualification':'pending final monitor' if clean else 'unqualified','timing_sha256':sha(d/'timing.json')});save();assert clean,'load monitor failed: retain completed window as unqualified diagnostic; do not start another window'
   print('window',n,'completed and archived; monitoring continues',flush=True)
  (monout/'STOP').write_text('Both windows and own postvalidation completed.\n');assert monitor.wait(timeout=10)==0,'monitor finalization failed';mr=json.loads((monout/'report.json').read_text());assert mr['status']=='passed-operational-load-monitor' and mr['preflight']=='passed';intact()
  report['status']='passed-operationally-monitored';report['claim_limit']='Operational sampled thresholds passed, not proof of exclusive hardware isolation. Publish allAPI/payload effects and dispersion; no universal speed claim.'
  for row in report['windows']:row['operational_load_qualification']='passed-operational-thresholds'
 except BaseException as e:
  report['status']='unqualified';report['error']=type(e).__name__+': '+str(e)
  # Preserve partial outputs; no modification of unrelated processes.
  if active and active.poll() is None:
   try:
    guestwork='/work/'+work.relative_to(root/'.build/linux-arm64').as_posix()
    cleaned=subprocess.run(['docker','exec','lcb-parity-linux','python3','-c',CLEANUP,guestwork],capture_output=True,text=True,timeout=8)
    report['emergency_guest_cleanup']=json.loads(cleaned.stdout) if cleaned.returncode==0 else {'status':'failed','exit':cleaned.returncode}
   except BaseException as cleanup_error:report['emergency_guest_cleanup']={'status':'failed','error':type(cleanup_error).__name__}
   os.killpg(active.pid,signal.SIGTERM)
   try:active.wait(timeout=5)
   except subprocess.TimeoutExpired:os.killpg(active.pid,signal.SIGKILL);active.wait()
   report['partial_timing_path']=str(work/'timing.json')
 finally:
  if monitor and monitor.poll() is None:
   if monout.exists():(monout/'STOP').write_text('Campaign finishing; no timing claim if incomplete.\n')
   try:monitor.wait(timeout=8)
   except subprocess.TimeoutExpired:monitor.terminate();monitor.wait(timeout=5)
  save();(out/'artifact-manifest.json').write_text(json.dumps({str(f.relative_to(out)):sha(f) for f in sorted(out.rglob('*')) if f.is_file() and f.name!='artifact-manifest.json'},indent=2))
 print(report['status'],str(out),flush=True)
 if report['status']!='passed-operationally-monitored':raise SystemExit(1)
if __name__=='__main__':main()
