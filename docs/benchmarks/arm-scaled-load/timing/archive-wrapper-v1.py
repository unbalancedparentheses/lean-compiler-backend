from pathlib import Path
import subprocess,json,hashlib,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');work=root/'.build/linux-arm64/zlib-inprocess-scaled';script=root/'scripts/zlib_inprocess.py';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();script_hash=sha(script)
for number in [1,2]:
 archive=work/f'window{number}';assert not archive.exists()
 command=['python3',str(script),'--work',str(work),'--phase','time','--samples','9','--batch-ms','250','--warmups','2']
 assert sha(script)==script_hash
 with (work/f'window{number}.log').open('w') as log:result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
 assert result.returncode==0,(number,result.returncode)
 archive.mkdir()
 for path in work.iterdir():
  if path.is_file() and (path.suffix in ['.json','.log','.py','.c']):shutil.copy2(path,archive/path.name)
 shutil.copy2(script,archive/'protocol-script.py')
 timing=json.loads((archive/'timing.json').read_text());assert timing['status']=='passed' and len(timing['samples'])==135
 (archive/'invocation.json').write_text(json.dumps({'command':command,'script_sha256':script_hash,'returncode':result.returncode},indent=2))
 (archive/'archive-hashes.json').write_text(json.dumps({p.name:sha(p) for p in archive.iterdir() if p.is_file()},indent=2))
 print(f'window{number} complete:135 samples, archive {archive}',flush=True)
assert sha(script)==script_hash
print('both timing windows complete; quiet hold released',flush=True)
