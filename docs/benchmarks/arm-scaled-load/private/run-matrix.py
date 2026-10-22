import sys,subprocess,json,os,time,hashlib
from pathlib import Path
sys.path.insert(0,'/tmp/lcb-arm-scaled-load/scripts');import arm_scaled_load
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';work=base/'arm-scaled-load-private-v4';work.mkdir()
sys.path.insert(0,str(root/'scripts'));import docker_sync
compiler=Path('/tmp/lcb-arm-scaled-load/after');before=compiler.with_name('before')
def run(cmd,inside=False):
 cmd=list(map(str,cmd))
 if inside:
  docker_sync.sources(cmd,base,'lcb-parity-linux')
  for x in cmd:
   if x.endswith('.s'):docker_sync.host_file(x,base,'lcb-parity-linux')
  translated=[('/work/'+str(Path(x).relative_to(base))) if x.startswith(str(base)+'/') else x for x in cmd]
  p=subprocess.run(['docker','exec','lcb-parity-linux',*translated],capture_output=True,text=True,timeout=240)
  if p.returncode==0 and '-o' in cmd:
   path=Path(cmd[cmd.index('-o')+1]);guest='/work/'+str(path.relative_to(base));expected=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',guest],text=True).split()[0]
   for _ in range(100):
    if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==expected:break
    time.sleep(.05)
   else:raise AssertionError(path)
  return p
 p=subprocess.run(cmd,capture_output=True,text=True,timeout=240)
 if p.returncode==0 and '-o' in cmd:docker_sync.host_file(cmd[cmd.index('-o')+1],base,'lcb-parity-linux')
 return p
results={}
for target in ['aarch64-macos','aarch64-linux']:
 def native(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=240)
 result=arm_scaled_load.exercise(compiler,work/target,native if target.endswith('macos') else run,os.environ.get('LCB_CC','cc') if target.endswith('macos') else 'gcc',target,True,before,root/'.build/syntax-main-review/qbe-snapshot' if target.endswith('macos') else Path('/tmp/qbe/qbe'))
 results[target]=result;print(target,'passed',flush=True)
(work/'reports.json').write_text(json.dumps(results,indent=2))
