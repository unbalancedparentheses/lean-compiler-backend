from pathlib import Path
import json,hashlib,subprocess,shutil,time
root=Path.cwd();base=root/'.build/linux-arm64';out=base/'scalar-result-discard-main-review';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for source,name in [(root/'scripts/scalar_result_discard.py','scalar_result_discard.py'),(root/'.build/scalar-discard-main-run.py','run.py'),(root/'.build/scalar-discard-main-finalize.py','finalize.py'),(root/'compiler-build.json','compiler-build.json')]:shutil.copy2(source,out/name)
reports=json.loads((out/'reports.json').read_text());assert len(reports)==5
for target,r in reports.items():
 assert r['compiler_sha256']==sha(out/'compiler') and r['original_qbe']=='passed'
 d=out/target/'scalar-result-discard';assert sha(d/'calls.ssa')==r['source_sha256'] and sha(d/'caller.c')==r['caller_sha256']
 for label,row in r['backends'].items():assert sha(d/(label+'.s'))==row['assembly_sha256'] and row['execution']=='passed'
files={str(p.relative_to(base)):sha(p) for p in out.rglob('*') if p.is_file() and p.name!='qualification.json' and '__pycache__' not in str(p)}
code='import sys,json,hashlib;from pathlib import Path;m=json.load(sys.stdin);print(json.dumps({p:hashlib.sha256(Path("/work",p).read_bytes()).hexdigest() if Path("/work",p).exists() else None for p in m}))'
for _ in range(100):
 p=subprocess.run(['docker','exec','-i','lcb-parity-linux','python3','-c',code],input=json.dumps(files),text=True,capture_output=True);assert p.returncode==0,p.stderr
 if json.loads(p.stdout)==files:break
 time.sleep(.05)
else:raise AssertionError('host/guest final artifact barrier failed')
r={'status':'passed','compiler_identity':next(iter(reports.values()))['compiler_identity'],'compiler_sha256':sha(out/'compiler'),'files':files,'artifact_count':len(files),'checks_per_backend_target':320,'total_c_checks':6400,'scope':'Fresh integrated main execution of 3 LCB modes and unchanged original QBE on all five targets. Native ARM, Rosetta Apple x86, QEMU Linux x86/RV. Defined direct and interpreter-resolved indirect aggregate omission remains rejected. Unknown native signatures remain ABI assumptions.','postvalidation':'Compiler/source/caller/assembly bindings and complete host/guest digest barrier passed.'}
(out/'qualification.json').write_text(json.dumps(r,indent=2)+'\n');print('passed',len(files),'bound files')
