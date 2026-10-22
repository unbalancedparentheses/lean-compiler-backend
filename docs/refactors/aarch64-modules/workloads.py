from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,json,hashlib
root=Path.cwd();out=root/'.build/aarch64-module-refactor';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
compilers={k:out/k for k in ['before','after']};bindings={str(p):sha(p) for p in compilers.values()};bindings[str(Path(__file__))]=sha(__file__)
jobs=[]
for workload,targets in [('zlib',['aarch64-linux','aarch64-macos']),('lua',['aarch64-linux'])]:
 base=root/'.build/linux-arm64'/f'arm-scaled-main-{workload}-review'
 rp=base/('binding-report.json' if workload=='zlib' else 'report.json');r=json.loads(rp.read_text());bindings[str(rp)]=sha(rp)
 expected={k.replace('/','-')+'.ssa':v['sha256'] for k,v in r['translation_units'].items()} if workload=='zlib' else {Path(k).name:v for k,v in r['bound_original_inputs'].items() if k.endswith('.ssa')}
 assert len(expected)==(17 if workload=='zlib' else 30)
 for name,h in expected.items():
  p=base/'ir'/name;assert sha(p)==h;bindings[str(p)]=h
  for target in targets:
   for mode in ['baseline','allocated','optimized']:jobs.append((workload,p,target,mode))
(out/'workload-assemblies').mkdir(exist_ok=False)
def compare(job):
 workload,p,target,mode=job;flags=[] if mode=='baseline' else ['--allocate' if mode=='allocated' else '--optimize'];row={'workload':workload,'input':str(p.relative_to(root)),'source_sha256':sha(p),'target':target,'mode':mode};outputs={}
 for label,compiler in compilers.items():
  dest=out/'workload-assemblies'/f'{workload}-{p.stem}-{target}-{mode}-{label}.s';c=[str(compiler),str(p),'--target',target,*flags,'-o',str(dest)];r=subprocess.run(c,capture_output=True,timeout=180);assert r.returncode==0,(c,r.stderr.decode());outputs[label]=dest;row[label+'_sha256']=sha(dest)
 assert outputs['before'].read_bytes()==outputs['after'].read_bytes(),row
 row['status']='identical_assembly';return row
with ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(compare,jobs))
assert all(sha(p)==h for p,h in bindings.items())
report={'status':'passed','compiler_identities':{k:subprocess.check_output([v,'--build-identity'],text=True).strip() for k,v in compilers.items()},'bindings':bindings,'cases':rows,'identical_assemblies':len(rows),'notes':['Both compilers consume identical retained IR; frontend and runtime not rerun in this assembly-equivalence campaign.','Lua covers30 frontend-admitted units; three GCC-built volatile units remain excluded.','Byte equality is finite evidence, not a semantic preservation theorem.']};(out/'workloads.json').write_text(json.dumps(report,indent=2)+'\n');print(len(rows),'identical workload assemblies',flush=True)
