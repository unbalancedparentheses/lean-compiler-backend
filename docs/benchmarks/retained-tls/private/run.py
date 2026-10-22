from pathlib import Path
import sys,subprocess,json
private=Path('/tmp/lcb-retained-tls');root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(private/'scripts'));import retained_tls as t
sys.path.insert(0,str(root/'scripts'));import docker_sync
base=root/'.build/linux-arm64';reports=[]
import hashlib
bound=[private/'scripts/retained_tls.py',private/'LeanCompilerBackend/Section.lean',private/'scripts/custom_tls_sections.py',private/'Tests.lean',private/'compiler-build.json',private/'LeanCompilerBackend/Verified/BuildIdentity.lean',private/'.build/retained-tls/after',root/'.build/lcb-elf-names-main']
before_hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in bound}
(private/'.build/retained-tls/pre-bindings.json').write_text(json.dumps(before_hashes,indent=2))
for target,cc,runner in [('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu']),('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64'])]:
 linux=target.endswith('linux');work=base/('retained-tls-v2-'+target) if linux else private/'.build/retained-tls/v2'/target
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside and len(cmd)==1:cmd=runner+cmd
  if inside and linux:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for p in cmd:
    if Path(p).suffix=='.s' and Path(p).exists():docker_sync.host_file(p,base,'lcb-parity-linux')
   cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
  return subprocess.run(cmd,capture_output=True,text=True,timeout=90)
 r=t.exercise(private/'.build/retained-tls/after',work,run,cc,target,qbe=Path('/tmp/qbe/qbe') if linux else root/'.build/syntax-main-review/qbe-snapshot',before=root/'.build/lcb-elf-names-main');reports.append(dict(target=target,report=str(work/'retained-tls/report.json')));print(target,'passed',flush=True)
(private/'.build/retained-tls/reports.json').write_text(json.dumps(reports,indent=2))

after_hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in bound}
assert after_hashes==before_hashes
(private/".build/retained-tls/post-bindings.json").write_text(json.dumps(after_hashes,indent=2))
