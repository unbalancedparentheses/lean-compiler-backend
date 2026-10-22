from pathlib import Path
import sys,subprocess,json,argparse
a=argparse.ArgumentParser();a.add_argument('--expected-identity',required=True);args=a.parse_args()
private=Path('/tmp/lcb-custom-tls');root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(root/'scripts'));import custom_tls_sections as t
compiler=root/'.build/lcb-custom-tls-main'
assert subprocess.check_output([compiler,'--build-identity'],text=True).strip()==args.expected_identity
sys.path.insert(0,str(root/'scripts'));import docker_sync
base=root/'.build/linux-arm64';reports=[]
for target,cc,runner in [('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu']),('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64'])]:
 linux=target.endswith('linux');work=base/('custom-tls-main-'+target) if linux else root/'.build/custom-tls-main-review'/target
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside and len(cmd)==1:cmd=runner+cmd
  if inside and linux:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for p in cmd:
    if Path(p).suffix=='.s' and Path(p).exists():docker_sync.host_file(p,base,'lcb-parity-linux')
   cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
  return subprocess.run(cmd,capture_output=True,text=True,timeout=90)
 r=t.exercise(compiler,work,run,cc,target,qbe=Path('/tmp/qbe/qbe') if linux else None,before=root/'.build/lcb-unused-call-results-main');reports.append(dict(target=target,report=str(work/'custom-tls-sections/report.json')));print(target,'passed',flush=True)
(root/'.build/custom-tls-main-review/reports.json').write_text(json.dumps(reports,indent=2))
