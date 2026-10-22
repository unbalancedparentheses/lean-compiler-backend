from pathlib import Path
import sys,subprocess,json
p=Path(__file__).parent;sys.path.insert(0,str(p/'scripts'));import amd_folded_loads as h
reports={}
for target in ['x86_64-linux','x86_64-macos']:
 def run(cmd,inside=False):
  assert not inside and Path(cmd[0])==p/'after',cmd
  return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=240)
 reports[target]=h.exercise(p/'after',p/'.build/emission-v4'/target,run,'/missing-cc',target,False,None,Path('/missing-qbe'))
 assert all(x['execution']=='not-run' for x in reports[target]['rows']);assert 'qbe_sha256' not in reports[target]
r=subprocess.run(['python3',p/'scripts/amd_folded_loads.py','--compiler',p/'after','--emission-only','--cc','/missing-cc','--qbe','/missing-qbe'],capture_output=True,text=True,timeout=240);assert r.returncode==0,r.stderr
reports['default_cli']=json.loads(r.stdout);(p/'.build/controls-v4.json').write_text(json.dumps(reports,indent=2));print('bothmissingtoolguards+defaultCLIpassed')
