from pathlib import Path
import sys,subprocess,json,hashlib
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');work=root/'.build/linux-arm64/aggregate-main-review';snap=work/'snapshots';sys.path.insert(0,str(snap));import large_aggregate_abi as h
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();bindings={str(p):sha(p) for p in snap.iterdir() if p.is_file()};rows=[]
for target in h.QBE_TARGET:
 def run(cmd,inside=False):
  assert not inside,'emission-only attempted external tool execution'
  return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
 r=h.exercise(snap/'lcb',work/'emission-only'/target,run,'/missing/cc',target,False,Path('/missing/qbe'));assert r['executed_matrix_modes']==r['executed_maximum_modes']==0 and r['qbe_sha256'] is None
 rows.append(dict(target=target,report=str(work/'emission-only'/target/'large-aggregate-abi/report.json')))
cmd=[sys.executable,str(snap/'large_aggregate_abi.py'),'--compiler',str(snap/'lcb'),'--work',str(work/'native-cli'),'--require-native']
r=subprocess.run(cmd,capture_output=True,text=True,timeout=300);assert r.returncode==0,(r.stdout,r.stderr)
assert all(sha(Path(p))==digest for p,digest in bindings.items())
(work/'supplement.json').write_text(json.dumps(dict(status='passed',snapshot_bindings=bindings,emission=rows,native_cli=dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr)),indent=2)+'\n')
print('all-five emission-only and native default CLI passed',flush=True)
