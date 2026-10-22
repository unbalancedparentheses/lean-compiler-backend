from pathlib import Path
import sys,subprocess,json,shutil,hashlib
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';out=base/'unused-call-results-main-review';out.mkdir(exist_ok=True);sys.path.insert(0,str(root/'scripts'));from docker_sync import sources,host_file
from unused_call_results import exercise
compiler=out/'compiler';shutil.copy2(root/'.build/lcb-unused-call-results-main',compiler)
reports={}
for target in ['aarch64-macos','aarch64-linux','x86_64-macos','x86_64-linux','riscv64-linux']:
 case=out/target;case.mkdir(exist_ok=True);linux=target.endswith('linux');isa=target.split('-')[0]
 if linux:cc='gcc' if isa=='aarch64' else isa+'-linux-gnu-gcc';qbe='/tmp/qbe/qbe'
 else:
  cc=case/'cc';cc.write_text('#!/bin/sh\nexec cc -arch '+('arm64' if isa=='aarch64' else 'x86_64')+' "$@"\n');cc.chmod(0o755);qbe=base/'lua-mixed-review/qbe-original-source/qbe'
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside and linux:
   sources(cmd,base,'lcb-parity-linux')
   if cmd[0].startswith(str(case)+'/') and isa!='aarch64':cmd=['qemu-'+isa,'-L','/usr/'+isa+'-linux-gnu',*cmd]
   cmd=['docker','exec','lcb-parity-linux']+[x.replace(str(base),'/work') for x in cmd]
  p=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
  if p.returncode==0 and not inside and cmd[0]==str(compiler) and '-o' in cmd:host_file(cmd[cmd.index('-o')+1],base,'lcb-parity-linux')
  return p
 reports[target]=exercise(compiler,case,run,cc,target,True,qbe);(out/'reports.json').write_text(json.dumps(reports,indent=2)+'\n');print(target,'passed',flush=True)
