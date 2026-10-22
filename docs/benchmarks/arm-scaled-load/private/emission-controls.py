from pathlib import Path
import sys,subprocess,json
sys.path.insert(0,str(Path(__file__).parent/'scripts'));import arm_scaled_load
root=Path(__file__).parent;reports={}
for target in ['aarch64-linux','aarch64-macos']:
 def run(cmd,inside=False):
  assert not inside,('unexpected guest/tool action',cmd)
  assert Path(cmd[0])==root/'after',('unexpected external tool',cmd)
  return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
 reports[target]=arm_scaled_load.exercise(root/'after',root/'.build/emission'/target,run,'/missing-cc',target,False,None,Path('/missing-qbe'))
 assert 'qbe_sha256' not in reports[target]
 assert all(v['execution']=='not-run' for p in reports[target]['profiles'].values() for v in p['backends'].values())
(root/'.build/emission.json').write_text(json.dumps(reports,indent=2))
print('both missing-tool emission controls passed')
