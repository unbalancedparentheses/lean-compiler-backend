"""Private targeted mixed-compression adapter: validate-only by default; --time requires authorized quiet window."""
from pathlib import Path
import argparse,hashlib,json,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--time',action='store_true');p.add_argument('--samples',type=int,default=9);p.add_argument('--batch-ms',type=float,default=500);p.add_argument('--warmups',type=int,default=2);a=p.parse_args()
w=Path(__file__).resolve().parent;base=w.parent;root=base.parent.parent
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def guest(p):return '/work/'+str(Path(p).relative_to(base))
def docker(args):
 r=subprocess.run(['docker','exec','lcb-parity-linux',*map(str,args)],text=True,capture_output=True);assert r.returncode==0,(args,r.returncode,r.stdout,r.stderr);return r.stdout
protocol=json.loads((w/'mixed-protocol.json').read_text());assert sha(__file__)==protocol['adapter_sha256'];assert sha(w/'mixed_probe.py')==protocol['probe_sha256'];assert sha(w/'manifest.json')==protocol['manifest_sha256'];
m=json.loads((w/'manifest.json').read_text());expected=json.loads((w/'bindings.json').read_text());records=json.loads((w/'provenance.json').read_text());prior=next(r for r in reversed(records) if r['stage']=='after_correctness');assert sha(w/'bindings.json')==prior['bindings_sha256'];assert sha(w/'correctness.json')==prior['reports']['correctness.json'];assert sha(root/'scripts/zlib_inprocess.py')==m['script_sha256']
def barrier(p):
 h=docker(['sha256sum',guest(p)]).split()[0]
 for _ in range(100):
  if p.exists() and sha(p)==h:return h
  time.sleep(.05)
 raise AssertionError(str(p))
def validate(stage,names):
 for path,h in expected.items():assert sha(path)==h,('host binding',path)
 code='import sys,json,hashlib;from pathlib import Path;print(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in json.loads(sys.argv[1])}))'
 actual=json.loads(docker(['python3','-c',code,json.dumps([guest(Path(x)) for x in expected])]))
 for path,h in expected.items():assert actual[guest(Path(path))]==h,('guest binding',path)
 assert sha(w/'correctness.json')==prior['reports']['correctness.json']
 record={'stage':stage,'status':'passed','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'bound_files_checked_host_and_guest':len(expected),'bindings_sha256':sha(w/'bindings.json'),'adapter_sha256':sha(__file__),'protocol_sha256':sha(w/'mixed-protocol.json'),'reports':{n:barrier(w/n) for n in names+['mixed-protocol.json','mixed_probe.py']}}
 records.append(record);(w/'provenance.json').write_text(json.dumps(records,indent=2)+'\n')
 wanted=sha(w/'provenance.json')
 for _ in range(100):
  if docker(['sha256sum',guest(w/'provenance.json')]).split()[0]==wanted:break
  time.sleep(.05)
 else:raise AssertionError('provenance report did not synchronize')
validate('before_mixed_timing' if a.time else 'mixed_timing_preflight',['manifest.json','correctness.json'])
if a.time:
 output=docker(['python3',guest(w/'mixed_probe.py'),guest(w),'--samples',a.samples,'--batch-ms',a.batch_ms,'--warmups',a.warmups]);(w/'mixed-timing.log').write_text(output);validate('after_mixed_timing',['manifest.json','correctness.json','mixed-timing.json']);print('timing complete and validated')
else:print('hybrid bindings validated; no timing or driver executed')
