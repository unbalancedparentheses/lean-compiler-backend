from pathlib import Path
import sys,subprocess,json,hashlib,time
private=Path('/tmp/lcb-elf-retain');root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(private/'scripts'));import elf_retain as h;import docker_sync
base=root/'.build/linux-arm64';compiler=private/'.build/retain/candidate';before=private/'.build/retain/before';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();frozen={str(p):sha(p) for p in [compiler,before,Path(h.__file__),private/'LeanCompilerBackend/Section.lean',private/'Tests.lean']};reports=[]
for target,cc,runner in [('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
 linux=target.endswith('linux');work=base/('elf-retain-v1-'+target) if linux else private/'.build/retain'/('matrix-v1-'+target);assert not work.exists()
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside and cmd[0].startswith(str(work)+'/'):cmd=runner+cmd
  if inside and linux:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for p in cmd:
    if Path(p).suffix=='.s' and Path(p).exists():docker_sync.host_file(p,base,'lcb-parity-linux')
   cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
  return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
 r=h.exercise(compiler,work,run,cc,target,True,Path('/tmp/qbe/qbe') if linux else None,before)
 guest={}
 if linux:
  code='import pathlib,hashlib,json,sys;p=pathlib.Path(sys.argv[1]);print(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob("*") if x.is_file()}))';guest=json.loads(subprocess.run(['docker','exec','lcb-parity-linux','python3','-c',code,'/work/'+str(work.relative_to(base))],capture_output=True,text=True,check=True).stdout);end=time.monotonic()+60
  for rel,digest in guest.items():
   p=work/rel
   while not p.exists() or sha(p)!=digest:
    assert time.monotonic()<end,p
    time.sleep(.05)
 reports.append(dict(target=target,report=str(work/'elf-retain/report.json'),execution='native Linux ARM VM' if target=='aarch64-linux' else ('QEMU user-mode' if linux else 'emission equivalence only'),guest_artifacts=guest))
assert all(sha(p)==v for p,v in frozen.items())
(private/'.build/retain/matrix.json').write_text(json.dumps(dict(status='passed',bindings=frozen,reports=reports),indent=2)+'\n')
