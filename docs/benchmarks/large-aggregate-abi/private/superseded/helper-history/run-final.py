from pathlib import Path
import sys,subprocess,json
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');private=Path('/tmp/lcb-large-aggregate');sys.path.insert(0,str(private/'scripts'));import large_aggregate_abi as test
sys.path.insert(0,str(root/'scripts'));import docker_sync
base=root/'.build/linux-arm64';compiler=private/'.build/aggregate-copy/cap-candidate'
for target,cc,runner in [('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
 linux=target.endswith('linux');work=base/('aggregate-copy-final-v3-'+target) if linux else private/'.build/aggregate-copy'/('final-v3-'+target)
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside and len(cmd)==1:cmd=runner+cmd
  if inside and linux:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for p in cmd:
    if Path(p).suffix=='.s' and Path(p).exists():docker_sync.host_file(p,base,'lcb-parity-linux')
   cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
  return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
 qbe=Path('/tmp/qbe/qbe') if linux else root/'.build/syntax-main-review/qbe-snapshot'
 test.exercise(compiler,work,run,cc,target,qbe=qbe)
