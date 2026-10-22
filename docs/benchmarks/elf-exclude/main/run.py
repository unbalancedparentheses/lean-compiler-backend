from pathlib import Path
import subprocess,json,sys,hashlib,time
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');private=root;base=root/'.build/linux-arm64';out=base/'elf-exclude-main';sys.path.insert(0,str(private/'scripts'));import elf_exclude
from docker_sync import host_file
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();compiler=root/'.build/lcb-elf-exclude-main';before=root/'.build/aarch64-module-refactor/after';report={'status':'running','bindings':{str(p):sha(p) for p in [compiler,before,private/'scripts/elf_exclude.py',Path(__file__)]},'rows':[]};commands=[]
def save():(out/'qualification.json').write_text(json.dumps(report,indent=2)+'\n')
configs=[('aarch64-linux','gcc','aarch64-linux-gnu',[]),('x86_64-linux','x86_64-linux-gnu-gcc','x86_64-linux-gnu',['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux','riscv64-linux-gnu-gcc','riscv64-linux-gnu',['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]
for target,gcc,triple,runner in configs:
 for profile in ['GNU','LLVM']:
  d=out/(target+'-'+profile);d.mkdir(exist_ok=True)
  def run(cmd,inside=False):
   if inside:
    for x in cmd[1:]:
     p=Path(x)
     if p.is_relative_to(base) and p.is_file():host_file(p,base,'lcb-parity-linux')
    if profile=='LLVM' and cmd[0]==gcc and '-c' in cmd:
     actual=['/usr/bin/clang','--target='+triple,*cmd[1:]];p=subprocess.run(actual,capture_output=True,text=True,timeout=180)
     if p.returncode==0:host_file(cmd[cmd.index('-o')+1],base,'lcb-parity-linux')
    else:
     converted=[str(x).replace(str(base),'/work') for x in cmd];actual=['docker','exec','lcb-parity-linux',*(runner if converted[0].startswith('/work/') else []),*converted];p=subprocess.run(actual,capture_output=True,text=True,timeout=180)
     if p.returncode==0 and '-o' in cmd:
      dest=Path(cmd[cmd.index('-o')+1]);guest=str(dest).replace(str(base),'/work');wanted=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',guest],text=True).split()[0]
      for _ in range(100):
       if dest.exists() and sha(dest)==wanted:break
       time.sleep(.05)
      else:raise AssertionError(('guest output synchronization',dest))
   else:actual=cmd;p=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
   commands.append({'command':list(map(str,actual)),'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr});return p
  r=elf_exclude.exercise(compiler,d,run,gcc,target,True,Path('/tmp/qbe/qbe'),before);report['rows'].append({'target':target,'assembler':profile,'linker':'GNU via target GCC','report_sha256':sha(d/'elf-exclude/report.json'),'status':'passed'});save();print(target,profile,'passed',flush=True)
for target in ['aarch64-macos','x86_64-macos']:
 def local(cmd,inside=False):return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
 r=elf_exclude.exercise(compiler,out/target,local,'/missing-cc',target,False,None,before);report['rows'].append({'target':target,'scope':'Apple grammar and before/after assembly preservation','status':'passed'});save()
assert all(sha(p)==h for p,h in report['bindings'].items());report['status']='passed';report['commands']=commands;save()
