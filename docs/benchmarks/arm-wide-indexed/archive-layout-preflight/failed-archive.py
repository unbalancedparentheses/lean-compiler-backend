from pathlib import Path
import hashlib,json,shutil,sys
w=Path('.build/linux-arm64/zlib-inprocess-wide-indexed');name=sys.argv[1];assert name in ['timing-window1','timing-window2'];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((w/'timing.json').read_text());assert r['status']=='completed' and len(r['samples'])==162 and r['sink_agreement']=='all labels and rounds'
expected={(case,label,i) for case in ['repeated','random','mixed'] for label in r['labels'] for i in range(9)};actual=[(x['case'],x['label'],x['round']) for x in r['samples']];assert len(actual)==len(set(actual)) and set(actual)==expected
provenance=json.loads((w/'provenance.json').read_text());record=provenance[-1];assert record['stage']=='after_timing' and record['status']=='passed'
for n in ['timing.json','correctness.json']:assert sha(w/n)==record['reports_guest_host_sha256'][n]
a=w/name;a.mkdir()
for n in ['timing.json','timing.log','manifest.json','correctness.json','bindings.json','provenance.json','caller.c','probe.py','release.json','prior-control-equivalence.json']:shutil.copy2(w/n,a/n)
shutil.copy2('scripts/zlib_inprocess.py',a/'zlib_inprocess.py');shutil.copy2(__file__,a/'archive.py');assert sha(a/'zlib_inprocess.py')==json.loads((a/'manifest.json').read_text())['script_sha256']
(a/'archive.json').write_text(json.dumps({'status':'completed and postvalidated','samples':162,'bound_files':record['bound_files_checked_host_and_guest'],'files':{p.name:sha(p) for p in a.iterdir()}},indent=2)+'\n');print(a)
