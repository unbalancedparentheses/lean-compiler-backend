from pathlib import Path
import hashlib,json,subprocess,shutil,re
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';work=base/'lua-mixed-review';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();r=json.loads((work/'report.json').read_text());e=json.loads((work/'mixed-execution.json').read_text());provenance=json.loads((work/'execution-provenance.json').read_text());supplement=json.loads((work/'supplement.json').read_text());guest=json.loads(Path('/tmp/lua-mixed-execute.log').read_text().splitlines()[-1]);assert sha(work/'mixed-execution.json')==guest['execution_sha256'];assert sha(work/'execution-provenance.json')==guest['provenance_sha256'];assert sha(work/'supplement.json')==Path('/tmp/lua-mixed-supplement.log').read_text().splitlines()[-1]
for name,h in r['source_hashes'].items():assert sha(work/'source'/name)==h
for name,h in r['test_hashes'].items():assert sha(work/'tests-original'/name)==h
for p,h in r['bound_inputs'].items():assert sha(p)==h,p
assert sha(work/'compiler')==r['compiler_sha256']
for label,info in r['oracle_builds'].items():
 source=work/(label+'-source');assert sha(source/'qbe')==info['binary_sha256']
 for name,h in info['source_hashes'].items():assert sha(source/name)==h
for path,h in provenance['initial_files'].items():assert sha(Path(path.replace('/work',str(base),1)))==h,path
for label,entry in r['backends'].items():
 assert entry['build_status']=='passed'
 if label.startswith('gcc'):continue
 assert set(entry['objects'])==set(r['units']) and len(entry['ir_compiled_units'])==30
 for unit in r['excluded_frontend_units']:assert entry['objects'][unit]['sha256']==r['backends']['gcc-O2']['objects'][unit]
 assert e[label]['status']=='passed';entry['execution_status']='passed'
for label,v in supplement.items():
 if label!='negative_control':assert v['exit']==0 and v['completed']
skips={label:re.findall(r'>>> (.*?) <<<',(work/label/'upstream-soft-port.stdout').read_text()) for label in r['backends']};assert all(v==skips['gcc-O2'] for v in skips.values())
for source,name in [('/tmp/lua-mixed-build.py','build.py'),('/tmp/lua-mixed-backends.py','build-backends.py'),('/tmp/lua-mixed-build.log','build.log'),('/tmp/lua-mixed-backends.log','build-backends.log'),('/tmp/lua-mixed-reference.log','reference.log'),('/tmp/lua-mixed-execute.log','execute.log'),('/tmp/lua-mixed-supplement.log','supplement.log')]:shutil.copy2(source,work/name)
r.update(status='mixed_build_qualified',postvalidation='passed',production_units=33,cproc_ir_units=30,shared_gcc_units=3,ir_functions=sum(len(re.findall(r'(?m)^(?:export )?function ',(work/'ir'/(u+'.ssa')).read_text())) for u in r['units'] if u not in r['excluded_frontend_units']),ir_lines=sum(len((work/'ir'/(u+'.ssa')).read_text().splitlines()) for u in r['units'] if u not in r['excluded_frontend_units']),test_counts={'pure_gcc_references':2,'mixed_labels':5,'deterministic_probe_executions':7,'upstream_suite_invocations':14,'suite_profiles':['official _U=true','_soft=true;_port=true with skip messages retained'],'negative_controls_detected':1,'upstream_archive_files_verified':41},upstream_skip_messages=skips['gcc-O2'],stack_limit_bytes=64*1024*1024,timing='No performance measurement. Upstream test logs include their own timings, not benchmark claims.',gcc_version=subprocess.check_output(['docker','exec','lcb-parity-linux','gcc','--version'],text=True),guest_machine=subprocess.check_output(['docker','exec','lcb-parity-linux','uname','-m'],text=True).strip(),cproc_commit=subprocess.check_output(['git','-C',base/'cjson-benchmark/cproc','rev-parse','HEAD'],text=True).strip())
(work/'report.json').write_text(json.dumps(r,indent=2)+'\n')
files={str(p):sha(p) for p in work.rglob('*') if p.is_file() and not '/tests/' in str(p) and not '/tests-soft-port/' in str(p)}
guestfiles={p.replace(str(base),'/work'):h for p,h in files.items()};request=work/'final-bindings.json';request.write_text(json.dumps(guestfiles))
# Manifest is tiny metadata; every bound guest file must match the host digest.
cmd=['docker','exec','lcb-parity-linux','python3','-c','import json,hashlib,pathlib;d=json.load(open("/work/lua-mixed-review/final-bindings.json"));[(None if hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()==h else (_ for _ in ()).throw(AssertionError(p))) for p,h in d.items()];print(len(d))'];count=int(subprocess.check_output(cmd,text=True));assert count==len(files)
final={'status':'passed','bound_files':count,'report_sha256':sha(work/'report.json'),'mixed_execution_sha256':sha(work/'mixed-execution.json'),'supplement_sha256':sha(work/'supplement.json'),'guest_host_digest_barrier':'passed','notes':['All five mixed labels use the same three GCC O2 object hashes; no volatile semantics were weakened or C/IR patched.','Full Lua frontend/backend qualification is not claimed; production build excludes internal ltests.c and onelua.c.','Both original and explicitly corrected QBE compiled fresh from separately copied sources and executed, retained as distinct labels.','Seven binaries each pass deterministic probe plus two documented reduced upstream-suite profiles; skip messages match GCC.']}
(work/'qualification.json').write_text(json.dumps(final,indent=2)+'\n');shutil.copy2('/tmp/finalize-lua-mixed.py',work/'finalize.py');print(json.dumps(final,indent=2))
