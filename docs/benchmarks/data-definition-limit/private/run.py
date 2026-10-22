from pathlib import Path
import sys,subprocess,json,hashlib,time
private=Path('/tmp/lcb-data-definition-limit');root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(private/'scripts'));import data_definition_limit as t;import docker_sync
base=root/'.build/linux-arm64';out=private/'.build/data-limit';reports=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
bound=[private/'scripts/data_definition_limit.py',private/'Tests.lean',private/'compiler-build.json',private/'.build/data-limit/after',root/'.build/lcb-arm-scaled-main',Path(__file__)]+[private/x for x in json.loads((private/'compiler-build.json').read_text())['files']]
pre={str(p):sha(p) for p in bound};(out/'pre-bindings.json').write_text(json.dumps(pre,indent=2))
for target,cc,runner in [('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu']),('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64'])]:
 linux=target.endswith('linux');work=base/('data-definition-limit-v1-'+target) if linux else out/'v1'/target
 def run(cmd,inside=False):
  cmd=list(map(str,cmd));original=cmd[:]
  if inside and len(cmd)==1:cmd=runner+cmd
  if inside and linux:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for p in cmd:
    if Path(p).suffix=='.s' and Path(p).exists():docker_sync.host_file(p,base,'lcb-parity-linux')
   cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
  p=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
  if inside and linux and p.returncode==0 and '-o' in original:
   path=Path(original[original.index('-o')+1]);expected=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',str(path).replace(str(base),'/work')],text=True).split()[0]
   for _ in range(100):
    if path.exists() and sha(path)==expected:break
    time.sleep(.05)
   else:raise AssertionError('guest-host output mismatch '+str(path))
  return p
 r=t.exercise(out/'after',work,run,cc,target,qbe=Path('/tmp/qbe/qbe') if linux else root/'.build/syntax-main-review/qbe-snapshot',before=root/'.build/lcb-arm-scaled-main');reports.append(dict(target=target,report=str(work/'data-definition-limit/report.json')));(out/'reports.json').write_text(json.dumps(reports,indent=2));print(target,'passed',flush=True)
 if linux:
  files={str(p.relative_to(work)):sha(p) for p in work.rglob('*') if p.is_file()};guest=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c','import pathlib,hashlib,json,sys;p=pathlib.Path(sys.argv[1]);print(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob("*") if x.is_file()}))',str(work).replace(str(base),'/work')],text=True));assert files==guest;(out/(target+'-guest-host.json')).write_text(json.dumps(files,indent=2))
post={str(p):sha(p) for p in bound};assert pre==post;(out/'post-bindings.json').write_text(json.dumps(post,indent=2))
