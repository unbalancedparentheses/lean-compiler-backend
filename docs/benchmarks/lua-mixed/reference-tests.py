from pathlib import Path
import subprocess,json,hashlib,shutil,resource
base=Path('/work/lua-mixed-review');r=json.loads((base/'report.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
results={}
def limits():resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,64*1024*1024))
for label in ['gcc-O0','gcc-O2']:
 case=base/label;exe=case/'lua';assert sha(exe)==r['backends'][label]['executable_sha256'];tests=case/'tests';shutil.copytree(base/'tests-original',tests)
 row={}
 for kind,cmd in [('deterministic',[str(exe),str(base/'probe.lua')]),('upstream-portable-soft',[str(exe),'-e','_U=true','all.lua'])]:
  try:
   p=subprocess.run(cmd,cwd=tests,capture_output=True,text=True,timeout=300,preexec_fn=limits);row[kind]={'command':cmd,'exit':p.returncode,'stdout_sha256':hashlib.sha256(p.stdout.encode()).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr.encode()).hexdigest()};(case/(kind+'.stdout')).write_text(p.stdout);(case/(kind+'.stderr')).write_text(p.stderr)
   assert p.returncode==0,(label,kind,p.stderr)
   if kind=='upstream-portable-soft':assert 'final OK !!!' in p.stdout,'upstream completion marker missing'
   if kind=='deterministic':assert p.stdout=='mixed-lua-probe: 50005000 / 42 / 64 / bits / pack / gc / errors\n'
  except Exception as e:
   row['failure']=str(e);results[label]=row;(base/'reference-execution.json').write_text(json.dumps(results,indent=2)+'\n');raise
 results[label]=row;(base/'reference-execution.json').write_text(json.dumps(results,indent=2)+'\n');print(label,'passed',flush=True)
assert results['gcc-O0']['deterministic']['stdout_sha256']==results['gcc-O2']['deterministic']['stdout_sha256']
print('reference checks passed',flush=True)
