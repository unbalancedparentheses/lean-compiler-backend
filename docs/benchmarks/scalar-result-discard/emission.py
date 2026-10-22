from pathlib import Path
import subprocess,json,sys
sys.path.insert(0,'/tmp/lcb-scalar-discard/scripts')
from scalar_result_discard import exercise
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');out=root/'.build/linux-arm64/scalar-result-discard-review'
def run(cmd,inside=False):
 assert not inside,cmd
 return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
r={}
for target in ['aarch64-macos','aarch64-linux','x86_64-macos','x86_64-linux','riscv64-linux']:
 r[target]=exercise(out/'compiler',out/'emission'/target,run,Path('/nonexistent/cc'),target,False,Path('/nonexistent/qbe'))
 assert r[target]['checks_per_backend']==0 and r[target]['original_qbe']=='not-run'
(out/'emission-only.json').write_text(json.dumps(r,indent=2)+'\n');print('all five emission-only passed')
