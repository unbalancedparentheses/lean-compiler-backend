from pathlib import Path
import subprocess,sys,json,time,hashlib
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');private=Path(__file__).parent;base=root/'.build/linux-arm64';out=base/'amd-folded-loads-private-v1';out.mkdir();sys.path.insert(0,str(private/'scripts'));import amd_folded_loads;sys.path.insert(0,str(root/'scripts'));import docker_sync
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();reports={}
for target in ['x86_64-macos','x86_64-linux']:
 native=target.endswith('macos')
 def run(cmd,inside=False):
  cmd=list(map(str,cmd));actual=cmd
  if inside and not native:
   for x in cmd:
    p=Path(x)
    if p.is_file() and p.is_relative_to(base):docker_sync.host_file(p,base,'lcb-parity-linux')
   actual=[('/work/'+str(Path(x).relative_to(base))) if x.startswith(str(base)+'/') else x for x in cmd]
   if len(cmd)==1:actual=['qemu-x86_64','-L','/usr/x86_64-linux-gnu',*actual]
   actual=['docker','exec','lcb-parity-linux',*actual]
  p=subprocess.run(actual,capture_output=True,text=True,timeout=240)
  if inside and not native and p.returncode==0 and '-o' in cmd:
   dest=Path(cmd[cmd.index('-o')+1]);g='/work/'+str(dest.relative_to(base));h=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',g],text=True).split()[0]
   for _ in range(100):
    if dest.exists() and sha(dest)==h:break
    time.sleep(.05)
   else:raise AssertionError(dest)
  return p
 cc=['/usr/bin/clang','-arch','x86_64'] if native else ['x86_64-linux-gnu-gcc'];qbe=root/'.build/syntax-main-review/qbe-snapshot' if native else Path('/tmp/qbe/qbe')
 reports[target]=amd_folded_loads.exercise(private/'after',out/target,run,cc,target,True,private/'before',qbe);print(target,'passed',flush=True)
(out/'reports.json').write_text(json.dumps(reports,indent=2))
