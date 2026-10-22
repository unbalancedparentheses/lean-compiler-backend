from pathlib import Path
import json,hashlib,subprocess
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';compiler=root/'.build/lcb-elf-names-main';out=root/'.build/elf-names-main-workload-bridge-v2';out.mkdir(exist_ok=False);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();initial=sha(compiler);identity=subprocess.check_output([compiler,'--build-identity'],text=True).strip();rows=[]
def check(source,target,mode,old,wanted):
 assert sha(old)==wanted,old
 name=f'{len(rows)}-{target}-{mode}.s';assembly=out/name;flags={'baseline':[],'allocated':['--allocate'],'optimized':['--optimize']}[mode];subprocess.run([compiler,source,'--target',target,*flags,'-o',assembly],check=True,capture_output=True,text=True,timeout=300);assert assembly.read_bytes()==old.read_bytes(),(source,target,mode)
 rows.append({'source':str(source),'source_sha256':sha(source),'target':target,'mode':mode,'assembly':name,'assembly_sha256':sha(assembly),'private_assembly':str(old)})
z=base/'unused-call-results-zlib-review';zr=json.loads((z/'report.json').read_text())
for target,modes in zr['targets'].items():
 for mode,labels in modes.items():
  for unit,row in labels['after'].items():check(z/'ir'/(unit+'.ssa'),target,mode,z/target/mode/'after'/(unit+'.s'),row['assembly_sha256'])
l=base/'unused-call-results-lua-review';lr=json.loads((l/'report.json').read_text())
for unit,row in lr['labels']['after']['objects'].items():
 if not row['gcc_shared']:check(l/'ir'/(unit+'.ssa'),'aarch64-linux','optimized',l/'after'/(unit+'.s'),row['assembly_sha256'])
cproc_reports={}
for tag,target in [('arm','aarch64-linux'),('x86','x86_64-linux'),('rv','riscv64-linux')]:
 cdir=base/('cproc-aggregate-refresh-v2-'+tag);cr=json.loads((cdir/'report.json').read_text());cproc_reports[tag]=sha(cdir/'report.json')
 assert cr['compiler_identity']=='a23afe3b4889b9da79c50d5ddf5b7e3e4affe2ba26d1e2c5072ed14c73cbdaaa'
 for mode in ['baseline','optimized']:
  assert cr['backends'][mode]['upstream_tests_passed']==196
  for unit,meta in cr['translation_units'].items():
   source=cdir/(unit+'.ssa');old=cdir/(unit+'-'+mode+'.s');assert sha(source)==meta['sha256']
   check(source,target,mode,old,cr['provenance']['files'][str(old.resolve())])
qbe_reports={}
for target in ['aarch64-linux','x86_64-linux','riscv64-linux']:
 qdir=base/('qbe-bootstrap-elf-main-v3-'+target);qr=json.loads((qdir/'report.json').read_text());qbe_reports[target]=sha(qdir/'report.json')
 assert qr['compiler_identity']=='5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e'
 for mode in ['baseline','optimized']:
  assert qr['backends'][mode]['original_runner_passes']==58
  for unit,meta in qr['translation_units'].items():
   stem=unit.removesuffix('.c').replace('/','-');source=qdir/'ir'/(stem+'.ssa');old=qdir/(stem+'-'+mode+'.s');assert sha(source)==meta['ir_sha256']
   check(source,target,mode,old,qr['provenance']['pre_post_bindings'][str(old.resolve())])
assert len(rows)==432 and sha(compiler)==initial
r={'status':'passed','compiler_identity':identity,'compiler_sha256':initial,'assemblies':rows,'count':len(rows),'qbe_report_sha256':qbe_reports,'cproc_report_sha256':cproc_reports,'private_zlib_qualification_sha256':sha(z/'qualification.json'),'private_lua_qualification_sha256':sha(l/'qualification.json'),'private_compiler_identity':zr['after_identity'],'scope':'Actual integrated main emits byte-identical assembly for 102 zlib, 30 optimized mixed-Lua and 108 three-Linux baseline/optimized cproc units and 192 QBE units. Prior privately linked/executed objects supply runtime evidence; this is not a fresh main workload link or execution. Separate ELF section matrices execute the new cases with actual main. Cproc objects/executables are reused from the prior exact-assembly qualification, not freshly linked or executed here.'};(out/'report.json').write_text(json.dumps(r,indent=2)+'\n');print(identity,len(rows),'identical workload assemblies')
