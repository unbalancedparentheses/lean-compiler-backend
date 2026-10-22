from pathlib import Path
import sys,subprocess,json
p=Path('/tmp/lcb-data-definition-limit');sys.path.insert(0,str(p/'scripts'));import data_definition_limit as h
rows=[]
def run(cmd,inside=False):
 assert not inside,cmd
 return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
for target in h.TARGETS:
 r=h.exercise(p/'.build/data-limit/after',p/'.build/data-limit/emission'/target,run,Path('/nonexistent/cc'),target,False,Path('/nonexistent/qbe'))
 assert r['checks_per_backend']==0 and r['before_equivalence']=='skipped: no before snapshot';rows.append(target)
(p/'.build/data-limit/emission.json').write_text(json.dumps(rows,indent=2));print(rows)
