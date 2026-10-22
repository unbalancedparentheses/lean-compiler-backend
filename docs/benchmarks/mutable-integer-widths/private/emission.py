from pathlib import Path
import sys,subprocess,json
root=Path('/tmp/lcb-mutable-widths');sys.path.insert(0,str(root/'scripts'));import mutable_integer_widths as t
rows=[]
def run(cmd,inside=False):
 assert not inside,cmd
 return subprocess.run(list(map(str,cmd)),capture_output=True,text=True)
for target in ['aarch64-linux','x86_64-linux','riscv64-linux','aarch64-macos','x86_64-macos']:
 r=t.exercise(root/'.build/mutable-widths/after',root/'.build/mutable-widths/emission'/target,run,Path('/missing/cc'),target,False,Path('/missing/qbe'));assert r['checks_per_backend']==0;rows.append(r)
(root/'.build/mutable-widths/emission.json').write_text(json.dumps(rows,indent=2))
