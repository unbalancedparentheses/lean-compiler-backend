from pathlib import Path
import sys,subprocess,json
sys.path.insert(0,'scripts');import elf_retain as h
for target in h.QBE_TARGET:
 def run(cmd,inside=False):
  assert not inside,'emission-only invoked external execution tool'
  return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
 r=h.exercise(Path('.build/retain/candidate').resolve(),Path('.build/retain/emission-v1')/target,run,'/missing/cc',target,False,Path('/missing/qbe'),Path('.build/retain/before').resolve());assert r['executed_modes']==0 and r['qbe_sha256'] is None
