from pathlib import Path
import hashlib,json,subprocess,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');private=Path('/tmp/lcb-amd-leaf-bank/.build/review');work=root/'.build/linux-arm64/amd-leaf-bank-x86-zlib-review';out=Path('/tmp/lcb-amd-main-equivalence');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def cmd(c):
 r=subprocess.run(list(map(str,c)),capture_output=True,text=True,timeout=180)
 if r.returncode:(out/'error.json').write_text(json.dumps({'cmd':list(map(str,c)),'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr},indent=2));raise RuntimeError(r.stderr)
 return r.stdout
retained=work/'report.json';old=json.loads(retained.read_text());reference=root/'.build/linux-arm64/zlib-x86_64.json';ref=json.loads(reference.read_text());manifest=private.parent/'profile-x86/manifest.json';manifest_data=json.loads(manifest.read_text());assert sha(reference)==manifest_data['references'][str(reference)]['sha256']
paths={p:sha(p) for p in [retained,reference,manifest,work/'execution-report.json',work/'execution-payload-report.json',private/'zlib-arm-input-refusal.json']}
source=root/'.build/linux-arm64/zlib-benchmark-x86_64'
for group in ['source_hashes','configuration_hashes']:
 for name,h in ref[group].items():
  p=source/'zlib'/name;assert sha(p)==h,p;paths[p]=h
compilers={}
for label,p in [('private',private/'after'),('main',root/'.build/lcb-amd-leaf')]:
 q=out/('compiler-'+label);shutil.copy2(p,q);paths[p]=sha(p);compilers[label]=q
assert sha(compilers['private'])==old['after_sha256']
ids={k:cmd([p,'--build-identity']).strip() for k,p in compilers.items()};assert ids['private']==old['after_identity'];assert ids['main']=='1fb34f883f3d1b0a8cec71544974df3fc5a9b4a23c7c300a144677eae3e4bcfc'
assert len(old['rows'])==51 and len({r['unit'] for r in old['rows']})==17
rows=[]
for row in old['rows']:
 unit,mode=row['unit'],row['mode'];p=source/'ir'/(unit+'.ssa');assert sha(p)==row['ir_sha256']==sha(work/p.name);paths[p]=sha(p);paths[work/p.name]=sha(p)
 key=unit.replace('test-','test/',1) if unit.startswith('test-') else unit;assert sha(p)==ref['translation_units'][key]['sha256']
 ir=out/p.name;shutil.copy2(p,ir);flags={'baseline':[],'allocated':['--allocate'],'optimized':['--optimize']}[mode]
 hashes={}
 for label,compiler in compilers.items():
  asm=out/(unit+'-'+mode+'-'+label+'.s');cmd([compiler,'--target','x86_64-linux',*flags,ir,'-o',asm]);hashes[label]=sha(asm)
 retained_asm=Path(row['after']['path']);assert sha(retained_asm)==row['after']['assembly_sha256'];paths[retained_asm]=sha(retained_asm)
 assert hashes['main']==hashes['private']==row['after']['assembly_sha256'],(unit,mode,hashes,row['after'])
 rows.append({'unit':unit,'mode':mode,'ir_sha256':sha(ir),'assembly_sha256':hashes['main'],'retained_assembly_sha256':row['after']['assembly_sha256'],'byte_identical':True})
for p,h in paths.items():assert sha(p)==h,p
report={'status':'passed','target':'x86_64-linux','compiler_identities':ids,'compiler_hashes':{k:sha(v) for k,v in compilers.items()},'unit_count':17,'mode_count':3,'comparisons':51,'fresh_emissions':102,'rows':rows,'bound_paths':{str(p):h for p,h in paths.items()},'postvalidation':'passed','scope':'Fresh exact assembly equivalence links combined-main identity to private executed correctly x86-configured workload. No executable or QBE execution performed in this equivalence task. Historical original/corrected QBE statuses remain reference-only.','excluded_preflight':'Original ARM-configured IR attempt is unqualified and excluded, retained zlib-arm-input-refusal.json hash bound here.','commands':['python3 /tmp/qualify-amd-main-equivalence.py']}
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n');shutil.copy2('/tmp/qualify-amd-main-equivalence.py',out/'qualify.py');print(json.dumps({'status':'passed','comparisons':51,'identities':ids}))
