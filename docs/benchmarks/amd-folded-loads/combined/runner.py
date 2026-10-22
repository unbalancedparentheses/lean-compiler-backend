#!/usr/bin/env python3
"""Actual-main correctness/static replay. Prepared only; no timings or builds.
Requires Apple ARM host with Rosetta and lcb-parity-linux QEMU toolchain.
"""
from pathlib import Path
import argparse,subprocess,hashlib,json,shutil,sys,time
ap=argparse.ArgumentParser();ap.add_argument('--compiler',type=Path,required=True);ap.add_argument('--identity',required=True);ap.add_argument('--before',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--root',type=Path,default=Path('/Users/unbalancedparen/projects/lean-compiler-backend'));a=ap.parse_args();root=a.root.resolve();base=root/'.build/linux-arm64';out=a.out.resolve();assert out.is_relative_to(base) and out!=base and not out.exists();out.mkdir(parents=True)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();prepared=Path(__file__).parent
inputs=[a.compiler.resolve(),a.before.resolve(),root/'scripts/amd_folded_loads.py',root/'scripts/docker_sync.py',root/'scripts/check.sh',root/'scripts/linux_targets.py',root/'scripts/macos_x86.py',root/'scripts/emission_only.py',root/'scripts/fuzz.py',root/'scripts/data_relocations.py',root/'compiler-build.json',Path(__file__).resolve(),*sorted(prepared.glob('template-*.py')),*sorted((root/'LeanCompilerBackend').rglob('*.lean'))]
inputs += [root/'.build/syntax-main-review/qbe-snapshot',*[f for f in sorted((root/'third_party/qbe').rglob('*')) if f.is_file() and f.suffix in ['.c','.h']]]
pre={str(p):sha(p) for p in inputs};report={'status':'running','requested_identity':a.identity,'inputs_before':pre,'steps':[]};(out/'scripts').mkdir();shutil.copy2(a.compiler,out/'after');shutil.copy2(a.before,out/'before');shutil.copy2(root/'scripts/amd_folded_loads.py',out/'scripts/amd_folded_loads.py');shutil.copy2(__file__,out/'runner.py')
def save():(out/'replay-report.json').write_text(json.dumps(report,indent=2))
def execute(name,cmd):
 with (out/(name+'.log')).open('w') as log:p=subprocess.run(list(map(str,cmd)),stdout=log,stderr=subprocess.STDOUT,timeout=1200,env={**__import__('os').environ,'PYTHONPATH':str(root/'scripts')})
 report['steps'].append({'name':name,'command':list(map(str,cmd)),'exit':p.returncode,'log_sha256':sha(out/(name+'.log'))});save();assert p.returncode==0,(name,out/(name+'.log'))
def generated(name,source,replacements):
 s=(prepared/source).read_text().replace('/Users/unbalancedparen/projects/lean-compiler-backend',str(root))
 for old,new in replacements:
  assert old in s,(source,old);s=s.replace(old,new)
 dest=out/name;dest.write_text(s);compile(s,str(dest),'exec');return dest
try:
 guest_qbe_before=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum','/tmp/qbe/qbe'],text=True).split()[0];report['guest_qbe_sha256']=guest_qbe_before
 identity=subprocess.check_output([out/'after','--build-identity'],text=True).strip();assert identity==a.identity;report['compiler_identity']=identity;report['before_identity']=subprocess.check_output([out/'before','--build-identity'],text=True).strip();save()
 matrix=generated('matrix.py','template-matrix.py',[("out=base/'amd-folded-loads-private-v4'","out=private/'matrix'")]);execute('matrix',['python3',matrix])
 # Strict emission-only entry checks use only the compiler, despite missing tools.
 sys.path.insert(0,str(out/'scripts'));import amd_folded_loads as helper
 emissions={}
 for target in ['x86_64-linux','x86_64-macos']:
  def guarded(cmd,inside=False):
   assert not inside and Path(cmd[0])==out/'after';return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=240)
  emissions[target]=helper.exercise(out/'after',out/'emission'/target,guarded,'/missing-cc',target,False,None,Path('/missing-qbe'));assert all(x['execution']=='not-run' for x in emissions[target]['rows']) and 'qbe_sha256' not in emissions[target]
 (out/'emission.json').write_text(json.dumps(emissions,indent=2))
 execute('cli-emission',['python3',out/'scripts/amd_folded_loads.py','--compiler',out/'after','--emission-only','--cc','/missing-cc','--qbe','/missing-qbe'])
 execute('cli-rosetta',['python3',out/'scripts/amd_folded_loads.py','--compiler',out/'after','--before',out/'before','--target','x86_64-macos','--cc','/usr/bin/clang -arch x86_64','--runner','arch -x86_64','--qbe',root/'.build/syntax-main-review/qbe-snapshot','--require-native'])
 z=out/'zlib';relative=z.relative_to(base).as_posix()
 build=generated('zlib-build.py','template-zlib.py',[("base/'amd-folded-load-zlib-v2'",'base/'+repr(relative)),("Path('/tmp/lcb-amd-folded-normalization/before')",'Path('+repr(str(out/'before'))+')'),("Path('/tmp/lcb-amd-folded-normalization/after')",'Path('+repr(str(out/'after'))+')')]);execute('zlib-build',['python3',build])
 audit=generated('zlib-audit.py','template-audit.py',[(str(base/'amd-folded-load-zlib-v2'),str(z))]);execute('zlib-audit',['python3',audit])
 execution=generated('zlib-execute.py','template-execute.py',[('/work/amd-folded-load-zlib-v2','/work/'+relative)]);shutil.copy2(execution,z/'execute.py');sys.path.insert(0,str(root/'scripts'));import docker_sync
 for f in [z/'execute.py',z/'report.json']:docker_sync.host_file(f,base,'lcb-parity-linux')
 execute('zlib-execute',['docker','exec','lcb-parity-linux','python3','/work/'+relative+'/execute.py'])
 expected=json.loads((out/'zlib-execute.log').read_text().splitlines()[-1])['report_sha256']
 for _ in range(100):
  if (z/'execution.json').exists() and sha(z/'execution.json')==expected:break
  time.sleep(.05)
 else:raise AssertionError('zlib execution report guest barrier')
 zreport=json.loads((z/'report.json').read_text());ze=json.loads((z/'execution.json').read_text());assert ze['input_postvalidation']=='passed';assert all(sha(k)==h for k,h in zreport['bound_inputs'].items());assert all(sha(k.replace('/work',str(base),1))==h for k,h in ze['initial_files'].items())
 matrixreport=json.loads((out/'matrix/reports.json').read_text());assert all(r['helper_sha256']==sha(out/'scripts/amd_folded_loads.py') and r['compiler_sha256']==sha(out/'after') for r in matrixreport.values())
 barriers={}
 for w in [out/'matrix',z]:
  guest='/work/'+w.relative_to(base).as_posix();code='import pathlib,hashlib,json;r=pathlib.Path('+repr(guest)+');print(json.dumps({str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in r.rglob("*") if p.is_file()}))';gh=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c',code],text=True));assert gh
  for k,h in gh.items():
   for _ in range(100):
    if (w/k).exists() and sha(w/k)==h:break
    time.sleep(.05)
   else:raise AssertionError(('guest/host final binding',w/k))
  barriers[str(w.relative_to(out))]=gh
 assert subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum','/tmp/qbe/qbe'],text=True).split()[0]==guest_qbe_before
 assert {k:sha(k) for k in pre}==pre
 report.update(status='passed',inputs_after=pre,guest_host=barriers,matrix_report_sha256=sha(out/'matrix/reports.json'),zlib_execution_sha256=sha(z/'execution.json'),timing='not run');save()
 (out/'artifact-hashes.json').write_text(json.dumps({str(f.relative_to(out)):sha(f) for f in sorted(out.rglob('*')) if f.is_file() and f.name!='artifact-hashes.json'},indent=2));print('passed',out,sha(out/'replay-report.json'))
except BaseException as e:
 report.update(status='failed',error=repr(e));save();raise
