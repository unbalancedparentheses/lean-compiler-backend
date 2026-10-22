from pathlib import Path
import json,hashlib,subprocess,datetime
base=Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64');root=base/'zlib-inprocess-leaf';m=json.loads((root/'manifest.json').read_text());expected={}
def add(p,h):expected[str(p)]=h
for n,h in m['source_hashes'].items():add(root/'source'/n,h)
for n,h in m['configuration_hashes'].items():add(root/'source'/n,h)
for n,h in m['ir_hashes'].items():add(root/'ir'/(n+'.ssa'),h)
for n,h in m['payload_hashes'].items():add(root/n,h)
for n,k in [('caller.c','caller_sha256'),('caller.o','caller_object_sha256'),('probe.py','probe_sha256'),('negative-driver','negative_driver_sha256'),('binding-report.json','binding_report_sha256')]:add(root/n,m[k])
for label,b in m['backends'].items():
 for n,o in b['objects'].items():add(root/label/(n+'.o'),o['sha256'])
 add(root/label/'driver',b['executable_sha256'])
 if label in m['lcb_labels']:add(root/('compiler-'+label),b['compiler_sha256'])
 if label.startswith('qbe-'):
  add(root/(label+'-source')/'qbe',b['oracle_binary_sha256'])
  for n,h in b['source_files'].items():add(root/(label+'-source')/n,h)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha('/tmp/lcb-cross-fallthrough/scripts/zlib_inprocess.py')==m['script_sha256']
for p,h in expected.items():assert sha(p)==h,p
paths=[p.replace(str(base),'/work') for p in expected]
code='import sys,json,hashlib;from pathlib import Path;print(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in json.loads(sys.argv[1])}))'
guest=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c',code,json.dumps(paths)],text=True))
for p,h in expected.items():assert guest[p.replace(str(base),'/work')]==h,p
reports={}
for name in ['manifest.json','correctness.json','timing.json']:
 p=root/name;g=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',str(p).replace(str(base),'/work')],text=True).split()[0];assert sha(p)==g;reports[name]=g
r=json.loads((root/'timing.json').read_text());assert r['status']=='completed' and len(r['samples'])==135
for case in r['summary']:
 xs=[s for s in r['samples'] if s['case']==case];assert len(set(x['measurement']['sink'] for x in xs))==1
out={'status':'passed','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Independent post-run verifier; initial prechecks covered executable/caller/probe/payload, source/config/IR/compilers/oracles independently checked after run. Fresh hardened repeat adds full prechecks.','host_and_guest_bound_files':len(expected),'reports_guest_host_sha256':reports,'script_sha256':m['script_sha256'],'sink_agreement':'all labels/rounds','expected_sha256':hashlib.sha256(json.dumps(expected,sort_keys=True).encode()).hexdigest()}
Path('/tmp/zlib-inprocess-first-postvalidation.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
