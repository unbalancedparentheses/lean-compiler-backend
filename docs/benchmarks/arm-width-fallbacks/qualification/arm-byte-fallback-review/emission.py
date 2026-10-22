from pathlib import Path
import sys,subprocess,json
sys.path.insert(0,'/tmp/lcb-arm-byte-fallback/scripts');from arm_indexed_load import exercise
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');out=root/'.build/linux-arm64/arm-byte-fallback-review'
def run(cmd,inside=False):
 assert not inside,cmd
 return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
r={}
for target in ['aarch64-macos','aarch64-linux']:
 r[target]=exercise(out/'compiler',out/'emission'/target,run,Path('/missing/cc'),target,False,before=root/'.build/lcb-symbol-placement',qbe=Path('/missing/qbe'))
 assert r[target]['case_groups_per_mode']==0 and r[target]['original_qbe']=='not-run'
(out/'emission-only.json').write_text(json.dumps(r,indent=2)+'\n');print('both ARM emission-only passed')
