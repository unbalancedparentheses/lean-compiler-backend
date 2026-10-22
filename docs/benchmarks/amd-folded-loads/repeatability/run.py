from pathlib import Path
import sys,json,hashlib,subprocess
root=Path.cwd();sys.path.insert(0,str(root/'scripts'));import amd_folded_loads as h
out=root/'.build/amd-helper-repeatability';compiler=root/'.build/lcb-data-limit-main';before=root/'.build/lcb-arm-scaled-main';qbe=root/'.build/syntax-main-review/qbe-snapshot';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();binding={str(p):sha(p) for p in [compiler,before,qbe,root/'scripts/amd_folded_loads.py',Path(__file__)]};reports=[]
for iteration in range(2):
 for target in ['x86_64-linux','x86_64-macos']:
  def guarded(cmd,inside=False):
   assert not inside and Path(cmd[0]) in [compiler,before];return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=240)
  r=h.exercise(compiler,out/'emission'/target,guarded,'/missing-cc',target,False,before,Path('/missing-qbe'));assert all(x['execution']=='not-run' for x in r['rows']);reports.append(r)
 def native(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside and len(cmd)==1:cmd=['arch','-x86_64']+cmd
  return subprocess.run(cmd,capture_output=True,text=True,timeout=240)
 r=h.exercise(compiler,out/'native',native,['cc','-arch','x86_64'],'x86_64-macos',True,before,qbe);assert all(x['execution']=='passed' for x in r['rows']) and r['wrong_signedness_detected'];reports.append(r)
 assert {p:sha(p) for p in binding}==binding
(out/'report.json').write_text(json.dumps({'status':'passed','bindings':binding,'iterations':2,'reports':reports},indent=2)+'\n');print('two consecutive emission and Rosetta execution profiles passed')
