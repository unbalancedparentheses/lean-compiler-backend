from pathlib import Path
import json,hashlib,subprocess
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';compiler=root/'.build/lcb-aggregate-main';out=root/'.build/aggregate-main-workload-bridge';out.mkdir(exist_ok=False);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();initial=sha(compiler);identity=subprocess.check_output([compiler,'--build-identity'],text=True).strip();rows=[]
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
assert len(rows)==132 and sha(compiler)==initial
r={'status':'passed','compiler_identity':identity,'compiler_sha256':initial,'assemblies':rows,'count':len(rows),'private_zlib_qualification_sha256':sha(z/'qualification.json'),'private_lua_qualification_sha256':sha(l/'qualification.json'),'private_compiler_identity':zr['after_identity'],'scope':'Actual integrated main emits byte-identical assembly for all private zlib and optimized mixed-Lua workload cases. Prior privately linked/executed objects supply runtime evidence; this is not a fresh main workload link or execution. Five-target independent aggregate matrices are separately run with the actual main compiler.'};(out/'report.json').write_text(json.dumps(r,indent=2)+'\n');print(identity,len(rows),'identical workload assemblies')
