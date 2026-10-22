from pathlib import Path
import subprocess,json,hashlib,re,sys,shutil,time
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(root/'scripts'))
from docker_sync import host_file
base=root/'.build/linux-arm64';out=base/'amd-folded-main-review/zlib';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def cmd(c):
 p=subprocess.run(list(map(str,c)),capture_output=True,timeout=300)
 if p.returncode:
  (out/'error.json').write_text(json.dumps({'command':list(map(str,c)),'returncode':p.returncode,'stdout':p.stdout.decode(errors='replace'),'stderr':p.stderr.decode(errors='replace')},indent=2));raise RuntimeError(p.stderr.decode(errors='replace'))
 if str(c[0])=='docker' and '-o' in c:
  guest=str(c[c.index('-o')+1])
  if guest.startswith('/work/'):
   host=base/guest[len('/work/'):]
   expected=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',guest],text=True).split()[0]
   for _ in range(100):
    if host.exists() and sha(host)==expected:break
    time.sleep(.05)
   else:raise AssertionError(('guest output barrier',host))
 return p.stdout
def inside(p):return str(p).replace(str(base),'/work')
binding=root/'.build/zlib-cse-profit-x86.json';bound=json.loads(binding.read_text());work=base/'zlib-benchmark-x86_64';paths={binding:sha(binding)}
for group in ['source_hashes','configuration_hashes']:
 for name,h in bound[group].items():
  p=work/'zlib'/name;assert sha(p)==h,(p,'source changed');paths[p]=h
assert len(bound['translation_units'])==17
(out/'ir').mkdir()
for name,row in bound['translation_units'].items():
 p=work/'ir'/(name.replace('/','-')+'.ssa');assert sha(p)==row['sha256'],p;paths[p]=sha(p);shutil.copy2(p,out/'ir'/p.name)
compilers={}
for label,p in [('before',Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64/amd-folded-main-review/before')),('after',Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64/amd-folded-main-review/after'))]:
 paths[p]=sha(p);q=out/('compiler-'+label);shutil.copy2(p,q);compilers[label]=q
for n in ['example','minigzip']:
 p=work/'gcc'/n;paths[p]=sha(p)
report={'before_identity':cmd([compilers['before'],'--build-identity']).decode().strip(),'after_identity':cmd([compilers['after'],'--build-identity']).decode().strip(),'compiler_hashes':{k:sha(v) for k,v in compilers.items()},'binding_sha256':sha(binding),'zlib_commit':bound['zlib_commit'],'frontend_defines':bound['frontend_defines'],'configuration_hashes':bound['configuration_hashes'],'source_hashes':bound['source_hashes'],'reference_executable_hashes':{n:sha(work/'gcc'/n) for n in ['example','minigzip']},'targets':{},'baseline_identical':0}
shutil.copy2(binding,out/'binding-report.json')
for target in ['x86_64-linux','x86_64-macos']:
 report['targets'][target]={}
 for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
  rows={};report['targets'][target][mode]=rows
  for label,compiler in compilers.items():
   case=out/target/mode/label;case.mkdir(parents=True);rows[label]={}
   for src in sorted((out/'ir').glob('*.ssa')):
    asm=case/(src.stem+'.s');obj=case/(src.stem+'.o');cmd([compiler,src,'--target',target,*flags,'-o',asm])
    if target.endswith('linux'):
     host_file(asm,base,'lcb-parity-linux');cmd(['docker','exec','lcb-parity-linux','x86_64-linux-gnu-gcc','-c',inside(asm),'-o',inside(obj)])
     sizes=cmd(['docker','exec','lcb-parity-linux','size','-A',inside(obj)]).decode();text=int(re.search(r'^\.text\s+(\d+)',sizes,re.M)[1])
    else:
     cmd(['/usr/bin/clang','-arch','x86_64','-c',asm,'-o',obj]);sizes=cmd(['size','-m',obj]).decode();text=int(re.search(r'Section \(__TEXT, __text\): (\d+)',sizes)[1])
    rows[label][src.stem]={'ir_sha256':sha(src),'assembly_sha256':sha(asm),'object_sha256':sha(obj),'text_bytes':text,'instructions':sum(bool(re.match(r'\t[a-z]',l)) for l in asm.read_text().splitlines())}
    if mode=='baseline' and label=='after':assert asm.read_bytes()==(case.parent/'before'/asm.name).read_bytes();report['baseline_identical']+=1
   if target.endswith('linux'):
    objects=[inside(case/(n.replace('/','-')+'.o')) for n in bound['translation_units'] if not n.startswith('test/')]
    for name in ['example','minigzip']:cmd(['docker','exec','lcb-parity-linux','x86_64-linux-gnu-gcc',*objects,inside(case/('test-'+name+'.o')),'-o',inside(case/name)])
   print(target,mode,label,sum(r['text_bytes'] for r in rows[label].values()),flush=True)
  (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
for p,h in paths.items():assert sha(p)==h,(p,'postvalidation changed')
report['input_postvalidation']='passed';report['bound_inputs']={str(p):h for p,h in paths.items()}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
