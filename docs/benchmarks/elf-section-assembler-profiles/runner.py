from pathlib import Path
import subprocess,sys,json,hashlib,time,shutil
root=Path.cwd();base=root/'.build/linux-arm64';out=base/'elf-name-assembler-profiles-v3';out.mkdir(exist_ok=False);sys.path.insert(0,str(root/'scripts'));import elf_section_names as helper;import docker_sync
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();compiler=root/'.build/lcb-retained-tls-main';bindings={str(p):sha(p) for p in [compiler,root/'scripts/elf_section_names.py',root/'scripts/docker_sync.py',Path(__file__).resolve()]};report=dict(status='running',bindings=bindings,matrices=[],commands=[])
def save():(out/'campaign.json').write_text(json.dumps(report,indent=2)+'\n')
def guest_path(p):return '/work/'+str(Path(p).relative_to(base))
def invoke(cmd):
 r=subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180);report['commands'].append(dict(command=list(map(str,cmd)),exit=r.returncode,stdout=r.stdout,stderr=r.stderr));return r
clang=Path('/usr/bin/clang');report['clang_version']=invoke([clang,'--version']).stdout
try:
 for target,cc,runner,triple in [('aarch64-linux','gcc',[],'aarch64-linux-gnu'),('x86_64-linux','x86_64-linux-gnu-gcc',['qemu-x86_64','-L','/usr/x86_64-linux-gnu'],'x86_64-linux-gnu'),('riscv64-linux','riscv64-linux-gnu-gcc',['qemu-riscv64','-L','/usr/riscv64-linux-gnu'],'riscv64-linux-gnu')]:
  for profile in ['GNU-decoded','LLVM-literal']:
   work=out/target/profile
   def run(cmd,inside=False):
    cmd=list(map(str,cmd));original=cmd[:]
    if inside and cmd[0]==cc and profile=='LLVM-literal':
     sources=[(i,Path(x)) for i,x in enumerate(cmd) if x.endswith('.s')]
     if '-c' in cmd:
      assert len(sources)==1;return invoke([clang,'--target='+triple,'-c',sources[0][1],'-o',cmd[cmd.index('-o')+1]])
     for i,src in sources:
      obj=src.with_suffix('.llvm.o');r=invoke([clang,'--target='+triple,'-c',src,'-o',obj])
      if r.returncode:return r
      cmd[i]=str(obj)
    if inside and len(cmd)==1:cmd=runner+cmd
    if inside:
     docker_sync.sources(cmd,base,'lcb-parity-linux')
     for x in cmd:
      p=Path(x)
      if p.is_relative_to(base) and p.is_file():docker_sync.host_file(p,base,'lcb-parity-linux')
     r=invoke(['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]])
     if r.returncode==0 and '-o' in original:
      p=Path(original[original.index('-o')+1]);wanted=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',guest_path(p)],text=True).split()[0];deadline=time.monotonic()+60
      while not p.exists() or sha(p)!=wanted:
       assert time.monotonic()<deadline,p
       time.sleep(.05)
     return r
    return invoke(cmd)
   r=helper.exercise(compiler,work,run,[cc],target,True,Path('/tmp/qbe/qbe'))
   assert r['section_name_profile']['name']==profile and r['executed_modes']==4
   code='import pathlib,json,hashlib;r=pathlib.Path('+repr(guest_path(work))+');print(json.dumps({str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in r.rglob("*") if p.is_file()}))'
   g=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c',code],text=True));h={str(p.relative_to(work)):sha(p) for p in work.rglob('*') if p.is_file()};assert h==g
   report['matrices'].append(dict(target=target,profile=profile,report=str(work/'elf-section-names/report.json'),artifacts=h));save();print(target,profile,'passed',flush=True)
 assert all(sha(p)==h for p,h in bindings.items());report['status']='passed'
except BaseException as error:report['error']=repr(error);report['status']='failed';raise
finally:save()
