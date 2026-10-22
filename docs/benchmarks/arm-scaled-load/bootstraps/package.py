from pathlib import Path
import json,hashlib,shutil,tarfile
p=Path('/tmp/lcb-combined-bootstrap-prep');out=p/'publication';out.mkdir(exist_ok=False);root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
summary={'compiler_identity':'210a515a50b54c9b78a824349deea8e4a78cc0d0b26f9bde5f61a886f8e6b2b5','compiler_sha256':sha(p/'combined-scaled-v1-qbe/lcb-snapshot'),'campaigns':{}}
for program,attempt in [('qbe','combined-scaled-v1'),('cproc','combined-scaled-v2')]:
 campaign=p/(attempt+'-'+program);dest=out/program;dest.mkdir();summary['campaigns'][program]=[]
 for f in campaign.glob('*'):
  if f.is_file() and f.name!='lcb-snapshot':shutil.copy2(f,dest/f.name)
 for target in ['aarch64-linux','x86_64-linux','riscv64-linux']:
  r=json.loads((campaign/(target+'.json')).read_text());work=base/(attempt+'-'+program+'-'+target)
  with tarfile.open(dest/(target+'-inputs-controls.tar.gz'),'w:gz') as tar:
   for f in work.rglob('*'):
    rel=f.relative_to(work)
    if not f.is_file() or '.git' in rel.parts:continue
    selected=(program=='qbe' and (rel.parts[0]=='ir' or f.name in ['commands.jsonl','probe.py','probe.json'] or (len(rel.parts)==1 and f.suffix=='.log'))) or (program=='cproc' and len(rel.parts)==1 and f.suffix in ['.ssa','.c','.log'])
    if selected:tar.add(f,arcname=str(rel))
  if program=='qbe':row=dict(target=target,units=len(r['translation_units']),qualified_backends=[k for k,v in r['backends'].items() if v.get('original_runner_passes')==58],fixture_assemblies=455,self_ir_assemblies=32,original_runtime_tests=58,original_failure=r['backends']['qbe'].get('failure'),comparator_control=r['comparator_control'],pre_post_bindings=len(r['provenance']['pre_post_bindings']),guest_host_bindings=r['provenance']['guest_host_count'])
  else:row=dict(target=target,units=len(r['translation_units']),qualified_backends=[k for k,v in r['backends'].items() if v.get('upstream_tests_passed')==196],stage2_ir=19,upstream_tests=196,original_failure=r['backends']['qbe'].get('failure'),negative_controls=r['negative_controls'],pre_post_bindings=len(r['provenance']['files']),guest_host_bindings=r['provenance']['guest_host_files'])
  summary['campaigns'][program].append(row)
shutil.copytree(p/'combined-scaled-v1-qbe/compiler-source',out/'compiler-source');shutil.copy2(p/'combined-scaled-v1-qbe/compiler-build.json',out/'compiler-build.json')
for name in ['run.py','run-v2.py','package.py']:shutil.copy2(p/name,out/name)
helper=out/'helpers';helper.mkdir()
for name in ['qbe_bootstrap.py','cproc_bootstrap.py','cjson_benchmark.py','fuzz.py']:shutil.copy2(root/'scripts'/name,helper/name)
shutil.copy2(root/'upstream-lock.json',out/'upstream-lock.json')
for name in ['qbe-1.3-amd64-extern-flags.json','qbe-1.3-arm64-extern-offset.json','qbe-1.3-rv64-extern-offset.json']:shutil.copy2(root/'tests/upstream'/name,helper/name)
pre=out/'wrapper-preflight-cproc-v1';pre.mkdir()
for name in ['aarch64-linux.log','status.json','pre-bindings.json','wrapper-failure.txt']:shutil.copy2(p/'combined-scaled-v1-cproc'/name,pre/name)
shutil.copy2(base/'combined-scaled-v1-cproc-aarch64-linux/report.json',pre/'helper-report.json')
(out/'summary.json').write_text(json.dumps(summary,indent=2))
print(out)
