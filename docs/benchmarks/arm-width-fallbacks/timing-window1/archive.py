from pathlib import Path
import hashlib,json,shutil,sys
w=Path('.build/linux-arm64/zlib-compression-widths');name=sys.argv[1];assert name in ['timing-window1','timing-window2'];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
r=json.loads((w/'timing.json').read_text());m=json.loads((w/'manifest.json').read_text());assert r['status']=='completed' and len(r['samples'])==216 and r['sink_agreement']=='all labels and rounds'
expected={(p['name'],label,i) for p in m['payloads'] if p['timed'] for label in m['successful_builds'] for i in range(9)};actual=[(x['case'],x['label'],x['round']) for x in r['samples']];assert len(actual)==len(set(actual)) and set(actual)==expected
for row in r['samples']:assert row['measurement']['loops'][1:]==[1,1]
for case,labels in r['summary'].items():assert all(set(apis)=={'compress'} for apis in labels.values())
provenance=json.loads((w/'provenance.json').read_text());record=provenance[-1];assert record['stage']=='after_timing' and record['status']=='passed'
for n in ['timing.json','correctness.json']:assert sha(w/n)==record['reports_guest_host_sha256'][n]
a=w/name;a.mkdir()
for n in ['timing.json','timing.log','manifest.json','correctness.json','binding-report.json','provenance.json','caller.c','probe.py','release.json','synthetic-summary-preflight.json']:shutil.copy2(w/n,a/n)
shutil.copy2('/tmp/lcb-arm-width-experiments/zlib_compression_only.py',a/'zlib_compression_only.py');assert sha(a/'zlib_compression_only.py')==m['script_sha256'];assert sha(a/'probe.py')==m['probe_sha256'];assert sha(a/'caller.c')==m['caller_sha256']
shutil.copy2('.build/width-summary-preflight.py',a/'synthetic-summary-preflight.py');shutil.copy2(__file__,a/'archive.py')
(a/'archive.json').write_text(json.dumps({'status':'completed and postvalidated','samples':216,'bound_files':record['bound_files_checked_host_and_guest'],'scope':'New compression-only protocol; uncompress/CRC loops fixed at 1 and excluded from summaries. Full correctness retained.','files':{p.name:sha(p) for p in a.iterdir()}},indent=2)+'\n');print(a)
