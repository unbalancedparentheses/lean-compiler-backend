"""Prepared actual-main qualification; no compilation/build of the compiler itself.
Requires fresh --out beneath repo .build/linux-arm64. Runs only on Apple ARM host
with lcb-parity-linux ARM VM. No timing. Source snapshots and all outputs retained.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys,shutil,time,os,importlib.util
p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--identity',required=True);p.add_argument('--before',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--root',type=Path,default=Path('/Users/unbalancedparen/projects/lean-compiler-backend'));p.add_argument('--helper',type=Path);p.add_argument('--qbe',type=Path);a=p.parse_args()
root=a.root.resolve();base=root/'.build/linux-arm64';out=a.out.resolve();compiler=a.compiler.resolve();before=a.before.resolve();helper=(a.helper or root/'scripts/arm_scaled_load.py').resolve();qbe=(a.qbe or root/'.build/syntax-main-review/qbe-snapshot').resolve();assert out.is_relative_to(base) and out!=base and not out.exists();assert all(x.is_file() for x in [compiler,before,helper,qbe]);out.mkdir(parents=True)
sha=lambda x:hashlib.sha256(Path(x).read_bytes()).hexdigest()
sys.path.insert(0,str(root/'scripts'));import docker_sync
inputs=[compiler,before,helper,qbe,Path(__file__).resolve(),root/'scripts/docker_sync.py',root/'scripts/check.sh',root/'scripts/linux_arm64.py',root/'scripts/emission_only.py',root/'scripts/fuzz.py',root/'lean-toolchain',root/'lakefile.toml']
inputs+=sorted((root/'LeanCompilerBackend').rglob('*.lean'));inputs+=sorted((root/'third_party/qbe').rglob('*.c'));inputs+=sorted((root/'third_party/qbe').rglob('*.h'))
pre={str(x):sha(x) for x in inputs};(out/'inputs-before.json').write_text(json.dumps(pre,indent=2));snap=out/'snapshot';snap.mkdir()
for src,name in [(compiler,'compiler'),(before,'before'),(helper,'arm_scaled_load.py'),(qbe,'qbe'),(Path(__file__),'runner.py')]:shutil.copy2(src,snap/name)
compiler=snap/'compiler';before=snap/'before';qbe=snap/'qbe';helper=snap/'arm_scaled_load.py'
commands=[];report={'status':'running','requested_identity':a.identity,'inputs':pre,'commands':commands,'scope':'Native Apple ARM and native ARM Linux Docker VM; no timing, original QBE legal shifts only; high-spill source unchanged.'}
def save(): (out/'report.json').write_text(json.dumps(report,indent=2))
def run(cmd,inside=False):
 cmd=list(map(str,cmd));actual=cmd
 if inside:
  docker_sync.sources(cmd,base,'lcb-parity-linux')
  for x in cmd:
   f=Path(x)
   if f.is_file() and f.is_relative_to(base):docker_sync.host_file(f,base,'lcb-parity-linux')
  actual=['docker','exec','lcb-parity-linux',*[('/work/'+str(Path(x).relative_to(base))) if x.startswith(str(base)+'/') else x for x in cmd]]
 r=subprocess.run(actual,text=True,capture_output=True,timeout=300,env={**os.environ,'PYTHONPATH':str(root/'scripts')});commands.append({'command':actual,'inside':inside,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr});save()
 if inside and r.returncode==0 and '-o' in cmd:
  f=Path(cmd[cmd.index('-o')+1]);guest='/work/'+str(f.relative_to(base));h=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',guest],text=True).split()[0]
  for _ in range(100):
   if f.exists() and sha(f)==h:break
   time.sleep(.05)
  else:raise AssertionError(('guest output barrier',f))
 return r
try:
 r=run([compiler,'--build-identity']);assert r.returncode==0 and r.stdout.strip()==a.identity
 guest_qbe_before=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum','/tmp/qbe/qbe'],text=True).split()[0];report['guest_qbe_sha256']=guest_qbe_before
 spec=importlib.util.spec_from_file_location('scaled_helper',helper);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 report['matrices']={};report['emission_controls']={}
 for target in ['aarch64-macos','aarch64-linux']:
  native=target.endswith('macos')
  def targetrun(cmd,inside=False):return run(cmd,inside and not native)
  report['matrices'][target]=module.exercise(compiler,out/'matrix'/target,targetrun,os.environ.get('LCB_CC','cc') if native else 'gcc',target,True,before,qbe if native else Path('/tmp/qbe/qbe'))
  def guarded(cmd,inside=False):
   assert not inside and Path(cmd[0])==compiler,('unexpected missing-tools action',cmd)
   return run(cmd)
  e=module.exercise(compiler,out/'emission'/target,guarded,'/missing-cc',target,False,None,Path('/missing-qbe'))
  assert 'qbe_sha256' not in e and all(x['execution']=='not-run' for v in e['profiles'].values() for x in v['backends'].values());report['emission_controls'][target]=e;save()
 # Reuse exact qualified high-spill fixture and runner, changing only explicit paths.
 source=base/'arm-scaled-high-spills';high=out/'high-spills';high.mkdir()
 for name in ['input.ssa','caller.c','generate.py','run.py']:
  shutil.copy2(source/name,high/name)
 report['high_spill_original_bindings']={str(source/n):sha(source/n) for n in ['input.ssa','caller.c','generate.py','run.py']}
 text=(high/'run.py').read_text();text=text.replace("Path('/tmp/lcb-arm-scaled-load/before')",repr(before)).replace("Path('/tmp/lcb-arm-scaled-load/after')",repr(compiler)).replace("qbe=root/'.build/syntax-main-review/qbe-snapshot'",'qbe='+repr(qbe)).replace('from pathlib import Path','from pathlib import Path, PosixPath')
 (high/'run-original.py').write_bytes((high/'run.py').read_bytes());(high/'run.py').write_text(text)
 r=run(['python3',high/'run.py']);assert r.returncode==0;report['high_spills']=json.loads((high/'report.json').read_text());assert report['high_spills']['status']=='passed'
 # CLI uses unchanged helper; explicit original QBE prevents rebuilding its source.
 r=run(['python3',helper,'--compiler',compiler,'--before',before,'--qbe',qbe,'--require-native']);assert r.returncode==0;report['native_default_cli']=json.loads(r.stdout)
 assert {k:sha(k) for k in pre}==pre
 assert all(sha(k)==v for k,v in report['high_spill_original_bindings'].items())
 assert subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum','/tmp/qbe/qbe'],text=True).split()[0]==guest_qbe_before
 report['inputs_after']=pre
 # Hash barrier covers guest-used/generated matrix and high-spill artifacts, not logs being written here.
 barriers={}
 for d in [out/'matrix/aarch64-linux',high]:
  guest='/work/'+str(d.relative_to(base));code='import pathlib,hashlib,json;r=pathlib.Path('+repr(guest)+');print(json.dumps({str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in r.rglob("*") if p.is_file()}))'
  h=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c',code],text=True))
  assert h,('empty guest binding set',d)
  for k,v in h.items():
   for _ in range(100):
    if (d/k).exists() and sha(d/k)==v:break
    time.sleep(.05)
   else:raise AssertionError(('final guest-host barrier',d/k))
  barriers[str(d.relative_to(out))]=h
 report['guest_host_bindings']=barriers;report['status']='passed';save()
 (out/'artifact-hashes.json').write_text(json.dumps({str(f.relative_to(out)):sha(f) for f in sorted(out.rglob('*')) if f.is_file() and f.name!='artifact-hashes.json'},indent=2));print(json.dumps({'status':'passed','out':str(out),'identity':a.identity}))
except BaseException as e:
 report['status']='failed';report['error']=repr(e);save();raise
