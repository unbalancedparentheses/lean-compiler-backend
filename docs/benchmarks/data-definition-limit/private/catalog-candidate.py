from pathlib import Path
import subprocess,json,hashlib,sys
p=Path('/tmp/lcb-data-definition-limit');root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';w=base/'frontend-data-count-probe-v2';out=base/'data-limit-catalog-candidate';out.mkdir(exist_ok=True);sys.path.insert(0,str(p/'scripts'));import docker_sync
rows=[]
def run(cmd,guest=False):
 cmd=list(map(str,cmd))
 if guest:
  docker_sync.sources(cmd,base,'lcb-parity-linux')
  for x in cmd:
   if x.endswith('.s') and Path(x).exists():docker_sync.host_file(x,base,'lcb-parity-linux')
  cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
 r=subprocess.run(cmd,capture_output=True,text=True);rows.append(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,rows[-1]
for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
 asm=out/(label+'.s');exe=out/label;run([p/'.build/data-limit/after',w/'catalog-4095.ssa','--target','aarch64-linux',*flags,'-o',asm]);run(['gcc','-O2',w/'caller-4095.c',asm,'-o',exe],True);run([exe],True)
(out/'report.json').write_text(json.dumps(dict(target='aarch64-linux',definitions=4096,strings_checked_per_mode=4095,commands=rows,bindings={str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in [p/'.build/data-limit/after',w/'catalog-4095.ssa',w/'caller-4095.c',Path(__file__)]}),indent=2))
