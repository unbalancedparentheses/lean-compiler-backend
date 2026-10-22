#!/usr/bin/env python3
"""Sequential fresh larger-program qualification. Launch only after snapshot release."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,time
ROOT=Path('/Users/unbalancedparen/projects/lean-compiler-backend')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--identity',required=True);p.add_argument('--name',required=True);p.add_argument('--program',choices=['qbe','cproc'],default='qbe');a=p.parse_args()
 assert a.name and all(c.isalnum() or c in '-_' for c in a.name)
 compiler=a.compiler.resolve();actual=subprocess.check_output([str(compiler),'--build-identity'],text=True).strip();assert actual==a.identity,(actual,a.identity)
 base=ROOT/'.build/linux-arm64';work=[base/f'{a.name}-{a.program}-{t}' for t in ['aarch64-linux','x86_64-linux','riscv64-linux']];assert all(not x.exists() for x in work),'all target work directories must be new'
 out=Path('/tmp/lcb-combined-bootstrap-prep')/(a.name+'-'+a.program);out.mkdir(exist_ok=False)
 source_manifest=json.loads((ROOT/'compiler-build.json').read_text());assert source_manifest['identity']==a.identity,'source manifest must match released compiler'
 for name,digest in source_manifest['files'].items():
  source=ROOT/name;assert sha(source)==digest,(name,'live source differs from released manifest');dest=out/'compiler-source'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
 shutil.copy2(ROOT/'compiler-build.json',out/'compiler-build.json');shutil.copy2(compiler,out/'lcb-snapshot');compiler=out/'lcb-snapshot'
 helper=ROOT/'scripts'/f'{a.program}_bootstrap.py';tracked=[helper,ROOT/'scripts/cjson_benchmark.py',ROOT/'scripts/fuzz.py',ROOT/'upstream-lock.json',compiler,Path(__file__)];bindings={str(x):sha(x) for x in tracked};(out/'pre-bindings.json').write_text(json.dumps(bindings,indent=2));summary=[]
 for target,directory in zip(['aarch64-linux','x86_64-linux','riscv64-linux'],work):
  report=directory/'report.json';cmd=['python3',str(helper),'--compiler',str(compiler),'--target',target,'--work',str(directory),'--report',str(report)]
  if a.program=='qbe':cmd+=['--repetitions','1']
  start=time.monotonic();print('START',target,flush=True)
  with (out/(target+'.log')).open('w') as stream:r=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
  row=dict(target=target,command=cmd,exit=r.returncode,elapsed_seconds=time.monotonic()-start,report=str(report));summary.append(row);(out/'status.json').write_text(json.dumps(summary,indent=2));assert r.returncode==0,row
  data=json.loads(report.read_text());assert data['compiler_identity']==a.identity and data['compiler_sha256']==sha(compiler)
  for label in ['baseline','optimized']:
   b=data['backends'][label]
   if a.program=='qbe':assert sum(b['fixture_assembly_matches'].values())==455 and b['self_ir_assembly_matches']==32 and b['original_runner_passes']==58
   else:assert len(b['reproduced_ir'])==19 and b['upstream_tests_passed']==b['upstream_tests_total']==196
  if a.program=='qbe':assert data['status']=='passed' and data['provenance']['guest_host_count']>0
  else:assert data['provenance']['pre_post_validation']==data['provenance']['guest_host_validation']=='passed'
  # The helper barriers precede writing the report. Add a fresh guest/host barrier for that final report.
  guest='/work/'+str(report.relative_to(base));r=subprocess.run(['docker','exec','lcb-parity-linux','sha256sum',guest],capture_output=True,text=True,check=True);assert r.stdout.split()[0]==sha(report)
  row.update(report_sha256=sha(report),report_guest_host='passed');shutil.copy2(report,out/(target+'.json'));(out/'status.json').write_text(json.dumps(summary,indent=2));print('PASS',target,round(row['elapsed_seconds'],1),'seconds',flush=True)
 after={str(x):sha(x) for x in tracked};assert after==bindings;(out/'post-bindings.json').write_text(json.dumps(after,indent=2));(out/'manifest.json').write_text(json.dumps({str(f.relative_to(out)):sha(f) for f in out.rglob('*') if f.is_file() and f.name!='manifest.json'},indent=2))
 print('FINISHED',out,flush=True)
if __name__=='__main__':main()
