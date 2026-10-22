from pathlib import Path
import subprocess,json,hashlib,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');work=root/'.build/linux-arm64/zlib-inprocess-scaled';script=root/'scripts/zlib_inprocess.py';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();script_hash=sha(script)
command=['python3',str(script),'--work',str(work),'--phase','time','--samples','9','--batch-ms','250','--warmups','2']
def finish(archive):
 timing=json.loads((archive/'timing.json').read_text());assert timing['status']=='completed' and len(timing['samples'])==135 and timing['sink_agreement']=='all labels and rounds'
 provenance=json.loads((archive/'provenance.json').read_text());assert provenance[-1]['stage']=='after_timing' and provenance[-1]['status']=='passed' and provenance[-1]['bound_files_checked_host_and_guest']==485
 assert provenance[-1]['reports_guest_host_sha256']['timing.json']==sha(archive/'timing.json')
 assert sha(archive/'protocol-script.py')==script_hash
 (archive/'invocation.json').write_text(json.dumps({'command':command,'script_sha256':script_hash,'phase_returncode':0,'archive_status':'completed'},indent=2))
 (archive/'archive-hashes.json').write_text(json.dumps({p.name:sha(p) for p in archive.iterdir() if p.is_file() and p.name!='archive-hashes.json'},indent=2))
finish(work/'window1')
(work/'window1/archive-wrapper-note.json').write_text(json.dumps({'scope':'archive-only wrapper correction, measurements unchanged','initial_wrapper':'/tmp/lcb-arm-scaled-load/archive-wrapper-v1.py','initial_wrapper_sha256':sha(Path('/tmp/lcb-arm-scaled-load/archive-wrapper-v1.py')),'error':'AssertionError after successful phase return and archive copies: expected status passed, actual completed','benchmark_phase_exit':0,'post_timing_provenance':'passed before wrapper assertion'},indent=2))
finish(work/'window1')
print('window1 archive finalized:135 samples,485-file postvalidation passed',flush=True)
archive=work/'window2';assert not archive.exists()
with (work/'window2.log').open('w') as log:result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
assert result.returncode==0
archive.mkdir()
for path in work.iterdir():
 if path.is_file() and path.suffix in ['.json','.log','.py','.c']:shutil.copy2(path,archive/path.name)
shutil.copy2(script,archive/'protocol-script.py');finish(archive)
assert sha(script)==script_hash
print('window2 completed:135 samples,485-file postvalidation passed; quiet hold RELEASED',flush=True)
