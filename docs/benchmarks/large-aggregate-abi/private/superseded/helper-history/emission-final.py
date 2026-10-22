from pathlib import Path
import sys,subprocess
sys.path.insert(0,'scripts');import large_aggregate_abi as h
for target in h.QBE_TARGET:
 def run(cmd,inside=False):
  assert not inside,'emission-only invoked execution tool'
  return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
 r=h.exercise(Path('.build/aggregate-copy/cap-candidate').resolve(),Path('.build/aggregate-copy/final-emission-v3')/target,run,'/missing/cc',target,False,Path('/missing/qbe'))
 assert r['executed_matrix_modes']==r['executed_maximum_modes']==0 and r['qbe_sha256'] is None
