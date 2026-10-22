from pathlib import Path
import subprocess,json,hashlib,shutil,resource
base=Path('/work/lua-mixed-review');r=json.loads((base/'report.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();results={}
paths=[p for p in base.rglob('*') if p.is_file() and (p.suffix in ['.c','.h','.ssa','.s','.o'] or p.name in ['lua','compiler','cproc','cproc-qbe','qbe','probe.lua'])];initial={str(p):sha(p) for p in paths}
def limits():resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,64*1024*1024))
for label in ['lcb-baseline','lcb-allocated','lcb-optimized','qbe-original','qbe-corrected']:
 row={};results[label]=row;entry=r['backends'][label]
 if entry['build_status']!='passed':row['status']='unbuilt';continue
 case=base/label;exe=case/'lua';assert sha(exe)==entry['executable_sha256'];tests=case/'tests';shutil.copytree(base/'tests-original',tests)
 for kind,cmd in [('deterministic',[str(exe),str(base/'probe.lua')]),('upstream-portable-soft',[str(exe),'-e','_U=true','all.lua'])]:
  try:
   p=subprocess.run(cmd,cwd=tests,capture_output=True,text=True,timeout=300,preexec_fn=limits);row[kind]={'command':cmd,'exit':p.returncode,'stdout_sha256':hashlib.sha256(p.stdout.encode()).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr.encode()).hexdigest()};(case/(kind+'.stdout')).write_text(p.stdout);(case/(kind+'.stderr')).write_text(p.stderr)
   passed=p.returncode==0 and (p.stdout=='mixed-lua-probe: 50005000 / 42 / 64 / bits / pack / gc / errors\n' if kind=='deterministic' else 'final OK !!!' in p.stdout)
   row[kind]['status']='passed' if passed else 'failed'
   if not passed:row['status']='failed';break
  except subprocess.TimeoutExpired as e:
   row[kind]={'status':'timeout','timeout_seconds':300};row['status']='failed';break
 row.setdefault('status','passed');(base/'mixed-execution.json').write_text(json.dumps(results,indent=2)+'\n');print(label,row['status'],flush=True)
for p,h in initial.items():assert sha(Path(p))==h,p
report={'results':results,'initial_files':initial,'file_postvalidation':'passed','stack_limit_bytes':64*1024*1024,'tests':'Unmodified upstream all.lua with official _U=true portable/soft/user profile; internal ltests excluded. Deterministic independent probe exact GCC output.','report_sha256':sha(base/'mixed-execution.json')}
(base/'execution-provenance.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'execution_sha256':sha(base/'mixed-execution.json'),'provenance_sha256':sha(base/'execution-provenance.json')}),flush=True)
assert all(results[k]['status']=='passed' for k in ['lcb-baseline','lcb-allocated','lcb-optimized','qbe-corrected']),results
