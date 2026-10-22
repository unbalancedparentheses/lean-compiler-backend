#!/usr/bin/env python3
"""Fresh QBE then cproc replay; only launch after immutable snapshot release."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,sys
ROOT=Path('/Users/unbalancedparen/projects/lean-compiler-backend')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,x):Path(p).write_text(json.dumps(x,indent=2))
def campaign(a,program):
 compiler=a.compiler.resolve();assert subprocess.check_output([compiler,'--build-identity'],text=True).strip()==a.identity
 source=json.loads((ROOT/'compiler-build.json').read_text());assert source['identity']==a.identity
 for n,d in source['files'].items():assert sha(ROOT/n)==d,('compiler source differs',n)
 base=ROOT/'.build/linux-arm64';targets=['aarch64-linux','x86_64-linux','riscv64-linux'];work=[base/f'{a.name}-{program}-{t}' for t in targets];assert all(not p.exists() for p in work),'all target directories must be fresh'
 out=Path('/tmp/lcb-combined-final-replay')/(a.name+'-'+program);out.mkdir(exist_ok=False);scripts=out/'scripts';scripts.mkdir()
 for n in source['files']:
  p=out/'compiler-source'/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,p)
 shutil.copy2(ROOT/'compiler-build.json',out/'compiler-build.json');shutil.copy2(compiler,out/'lcb-snapshot');assert sha(compiler)==sha(out/'lcb-snapshot')
 helper=ROOT/'scripts'/f'{program}_bootstrap.py'
 for p in [helper,ROOT/'scripts/cjson_benchmark.py',ROOT/'scripts/fuzz.py',ROOT/'scripts/docker_sync.py']:shutil.copy2(p,scripts/p.name)
 frozen_helper=scripts/helper.name;original=frozen_helper.read_text()
 wrapper=out/'invoke.py';wrapper.write_text('import sys,runpy\nfrom pathlib import Path\nsys.path.insert(0,str(Path(__file__).parent/"scripts"))\nimport cjson_benchmark\ncjson_benchmark.ROOT=Path('+repr(str(ROOT))+')\nhelper=sys.argv.pop(1)\nrunpy.run_path(helper,run_name="__main__")\n')
 # Bind both the live sources and the exact frozen executed helper/snapshot.
 tracked=[compiler,Path(__file__),ROOT/'compiler-build.json',ROOT/'upstream-lock.json',helper,ROOT/'scripts/cjson_benchmark.py',ROOT/'scripts/fuzz.py',ROOT/'scripts/docker_sync.py',out/'lcb-snapshot',wrapper,frozen_helper,scripts/'cjson_benchmark.py',scripts/'fuzz.py',scripts/'docker_sync.py']+[ROOT/n for n in source['files']]
 tracked += [p for p in (ROOT/'third_party/qbe').rglob('*') if p.is_file()]
 tracked += list((ROOT/'tests/upstream').glob('qbe-1.3-*.json'))+list((ROOT/'tests/regressions').glob('qbe-*-extern-*'))
 before={str(p):sha(p) for p in tracked};write(out/'pre-bindings.json',before);summary=[]
 sys.path.insert(0,str(scripts));import docker_sync
 for target,directory in zip(targets,work):
  report=directory/'report.json';cmd=[sys.executable,str(wrapper),str(frozen_helper),'--compiler',str(out/'lcb-snapshot'),'--target',target,'--work',str(directory),'--report',str(report)]
  if program=='qbe':cmd+=['--repetitions','1']
  print('START',program,target,flush=True)
  with (out/(target+'.log')).open('w') as stream:r=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
  row=dict(program=program,target=target,command=cmd,exit=r.returncode,report=str(report));summary.append(row);write(out/'status.json',summary);assert r.returncode==0,row
  data=json.loads(report.read_text());assert data['compiler_identity']==a.identity and (data['compiler_sha256'] if program=='qbe' else data['provenance']['compiler_sha256'])==sha(out/'lcb-snapshot')
  reported_helper=data['helper_sha256'] if program=='qbe' else data['provenance']['helper_sha256'];assert reported_helper==sha(frozen_helper)
  for label in ['baseline','optimized']+(['qbe-corrected'] if 'qbe-corrected' in data['backends'] else []):
   b=data['backends'][label]
   if program=='qbe':assert sum(b['fixture_assembly_matches'].values())==455 and b['self_ir_assembly_matches']==32 and b['original_runner_passes']==58
   else:assert len(b['reproduced_ir'])==19 and b['upstream_tests_passed']==b['upstream_tests_total']==196 and data['negative_controls'][label]['detected']
  if program=='qbe':
   assert data['status']=='passed' and data['provenance']['guest_host_count']>0 and data['comparator_control']['status']=='detected'
   assert all(len(x['seconds'])==1 for x in data['runtime'].values()),'expected one mandatory diagnostic sweep'
  else:assert data['provenance']['pre_post_validation']==data['provenance']['guest_host_validation']=='passed'
  # Original QBE failures remain recorded separately; never relabel corrected-QBE passes.
  row['original_qbe_failure']=data['backends'].get('qbe',{}).get('failure');row['original_qbe_build_failure']=data['backends'].get('qbe',{}).get('build_failure')
  docker_sync.host_file(report,base,'lcb-parity-linux');guest='/work/'+str(report.relative_to(base));r=subprocess.run(['docker','exec','lcb-parity-linux','sha256sum',guest],capture_output=True,text=True,check=True);assert r.stdout.split()[0]==sha(report)
  row.update(report_sha256=sha(report),report_guest_host='passed');shutil.copy2(report,out/(target+'.json'));write(out/'status.json',summary);print('PASS',program,target,flush=True)
 after={str(p):sha(p) for p in tracked};assert after==before;write(out/'post-bindings.json',after)
 write(out/'qualification.json',dict(program=program,status='passed',compiler_identity=a.identity,mandatory_diagnostic_repetitions=1 if program=='qbe' else 0,source_helper_compiler_pre_post='passed',target_report_guest_host='passed',limitations='Finite bootstrap corpus. Original and corrected QBE labels remain separate; process/build durations in raw reports are incidental diagnostics, not performance evidence. Linux x86/RV compiler executables run through QEMU; generated upstream ARM runtime tests execute on native ARM.'))
 write(out/'manifest.json',{str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file() and p!=out/'manifest.json'});print('FINISHED',out,flush=True)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--identity',required=True);p.add_argument('--name',required=True);p.add_argument('--program',choices=['both','qbe','cproc'],default='both');a=p.parse_args();assert a.name and all(c.isalnum() or c in '-_' for c in a.name)
 for program in (['qbe','cproc'] if a.program=='both' else [a.program]):campaign(a,program)
if __name__=='__main__':main()
