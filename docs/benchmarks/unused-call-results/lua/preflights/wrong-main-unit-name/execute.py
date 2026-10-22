from pathlib import Path
import subprocess,json,hashlib,shutil,resource,re
w=Path('/work/unused-call-results-lua-review');r=json.loads((w/'report.json').read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
paths=[p for p in w.rglob('*') if p.is_file() and p.name not in ['execution.json','execution.log']];initial={str(p):sha(p) for p in paths};results={}
def limit():resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,64*1024*1024))
expected='mixed-lua-probe: 50005000 / 42 / 64 / bits / pack / gc / errors\n'
for label,entry in r['labels'].items():
 case=w/label;exe=case/'lua';assert sha(exe)==entry['executable_sha256'];results[label]={}
 for name,args in [('probe',[str(w/'probe.lua')]),('user',['-e','_U=true','all.lua']),('soft-port',['-e','_soft=true;_port=true','all.lua'])]:
  cwd=case/('tests-'+name);shutil.copytree(w/'tests-original',cwd);p=subprocess.run([str(exe),*args],cwd=cwd,capture_output=True,text=True,timeout=300,preexec_fn=limit);(case/(name+'.stdout')).write_text(p.stdout);(case/(name+'.stderr')).write_text(p.stderr);assert p.returncode==0,(label,name,p.returncode,p.stderr);assert (p.stdout==expected if name=='probe' else 'final OK !!!' in p.stdout),(label,name,p.stdout[-200:]);results[label][name]={'exit':p.returncode,'stdout_sha256':hashlib.sha256(p.stdout.encode()).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr.encode()).hexdigest(),'skip_messages':re.findall(r'>>> (.*?) <<<',p.stdout)}
 print(label,'passed probe +2 reduced suiteprofiles',flush=True)
for name in ['user','soft-port']:
 assert all(results[label][name]['skip_messages']==results['gcc-O2'][name]['skip_messages'] for label in results),(name,'skip mismatch')
# Retain candidate library objects, replace only the CLI translation unit with
# an empty main. A successful exit without the exact probe output must fail.
c=w/'wrong-main.c';c.write_text('int main(void){return 0;}\n');objects=[w/'after'/(u+'.o') for u in r['units'] if u!='lua.c'];exe=w/'wrong-main';p=subprocess.run(['gcc',str(c),*map(str,objects),'-lm','-ldl','-o',str(exe)],capture_output=True,text=True);assert p.returncode==0,p.stderr
p=subprocess.run([str(exe),str(w/'probe.lua')],capture_output=True,text=True,timeout=30,preexec_fn=limit);assert p.returncode==0 and p.stdout!=expected
for path,h in initial.items():assert sha(path)==h,path
report={'status':'passed','results':results,'pre_post_bound_files':initial,'negative_control':{'empty_main_exit':p.returncode,'stdout':p.stdout,'detected':True,'executable_sha256':sha(exe)},'scope':'Fresh before/after optimized mixed Lua,30LCB units+3identicalGCC volatile units; reused unchanged GCC O0/O2 and original/corrected QBE executable references freshly executed.6probes+12reduced upstream invocations; notfullLua or timing qualification.','stack_limit':64*1024*1024,'per_invocation_timeout_seconds':300};(w/'execution.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'execution_sha256':sha(w/'execution.json'),'bound_files':len(initial)}),flush=True)
