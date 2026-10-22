#!/usr/bin/env python3
"""Snapshot and qualify an explicitly identified actual-main compiler; no rebuilding."""
import argparse,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--identity',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--qbe-host',type=Path,required=True);p.add_argument('--qbe-guest',default='/tmp/qbe/qbe');p.add_argument('--container',default='lcb-parity-linux');a=p.parse_args()
 root=a.repo.resolve();base=root/'.build/linux-arm64';out=a.output.resolve();assert out.is_relative_to(base) and not out.exists(),'use a fresh directory below mounted .build/linux-arm64'
 out.mkdir(parents=True);snap=out/'snapshots';snap.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 compiler=snap/'lcb';shutil.copy2(a.compiler,compiler);qbe=snap/'qbe-host';shutil.copy2(a.qbe_host,qbe)
 for name in ['large_aggregate_abi.py','data_relocations.py','fuzz.py','docker_sync.py']:shutil.copy2(root/'scripts'/name,snap/name)
 sys.path.insert(0,str(snap));import large_aggregate_abi as test;import docker_sync
 identity=subprocess.run([str(compiler),'--build-identity'],capture_output=True,text=True,check=True).stdout.strip();assert identity==a.identity,(identity,a.identity)
 origin_paths=[a.compiler.resolve(),a.qbe_host.resolve(),root/'compiler-build.json']+[root/'scripts'/n for n in ['large_aggregate_abi.py','data_relocations.py','fuzz.py','docker_sync.py','check.sh','linux_arm64.py','linux_targets.py','macos_x86.py']]+[root/'LeanCompilerBackend'/(n+'.lean') for n in ['AArch64','AMD64','RV64','AggregateABI','AMD64ABI','RV64ABI']]
 origins={str(x):sha(x) for x in origin_paths}
 bindings={str(x):sha(x) for x in snap.iterdir() if x.is_file()};report=dict(status='running',identity=identity,snapshot_bindings=bindings,original_bindings=origins,targets=[]);report_path=out/'campaign.json'
 def save():report_path.write_text(json.dumps(report,indent=2)+'\n')
 save()
 try:
  for target,cc,runner in [('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
   report['current_target']=target;save();linux=target.endswith('linux')
   def run(cmd,inside=False):
    cmd=list(map(str,cmd))
    if inside and len(cmd)==1:cmd=runner+cmd
    if inside and linux:
     docker_sync.sources(cmd,base,a.container)
     for name in cmd:
      if Path(name).suffix=='.s' and Path(name).exists():docker_sync.host_file(name,base,a.container)
     cmd=['docker','exec',a.container,*[x.replace(str(base),'/work') for x in cmd]]
    return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
   r=test.exercise(compiler,out/target,run,cc,target,True,Path(a.qbe_guest) if linux else qbe)
   assert r['compiler_identity']==identity and r['harness_sha256']==bindings[str(snap/'large_aggregate_abi.py')]
   assert r['executed_matrix_modes']==4 and r['executed_maximum_modes']==6
   path=out/target/'large-aggregate-abi/report.json'
   guest_bindings={}
   if linux:
    guest_dir='/work/'+str((out/target).relative_to(base))
    code='import pathlib,hashlib,json,sys;p=pathlib.Path(sys.argv[1]);print(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob("*") if x.is_file()}))'
    guest_bindings=json.loads(subprocess.run(['docker','exec',a.container,'python3','-c',code,guest_dir],capture_output=True,text=True,timeout=120,check=True).stdout)
    deadline=time.monotonic()+60
    for relative,digest in guest_bindings.items():
     host=out/target/relative
     while not host.is_file() or sha(host)!=digest:
      assert time.monotonic()<deadline,('guest/host artifact barrier failed',host)
      time.sleep(.05)
   artifacts={str(x.relative_to(out/target)):sha(x) for x in (out/target).rglob('*') if x.is_file()}
   report['targets'].append(dict(target=target,path=str(path),sha256=sha(path),artifacts=artifacts,guest_artifacts=guest_bindings));save()
  assert all(sha(path)==digest for path,digest in bindings.items()),'snapshot changed during qualification'
  assert all(sha(path)==digest for path,digest in origins.items()),'original compiler/source/helper/core/hooks changed during qualification'
  report['status']='passed'
 except BaseException as error:
  report['status']='failed';report['error']=repr(error);raise
 finally:save()
 print(report_path)
if __name__=='__main__':main()
