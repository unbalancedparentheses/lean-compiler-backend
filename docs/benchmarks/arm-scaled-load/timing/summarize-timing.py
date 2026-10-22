from pathlib import Path
import json,hashlib,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');work=root/'.build/linux-arm64/zlib-inprocess-scaled';out=Path('/tmp/lcb-arm-scaled-load/timing-publication');out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[]
for n in (1,2):
 source=work/f'window{n}';r=json.loads((source/'timing.json').read_text());assert r['status']=='completed' and len(r['samples'])==135
 p=json.loads((source/'provenance.json').read_text());assert p[-1]['stage']=='after_timing' and p[-1]['status']=='passed'
 (source/'archive-hashes.json').write_text(json.dumps({x.name:sha(x) for x in source.iterdir() if x.is_file() and x.name!='archive-hashes.json'},indent=2))
 shutil.copytree(source,out/f'window{n}')
 for case,labels in r['summary'].items():
  for api,measurement in labels['scaled'].items():
   rows.append({'window':n,'payload':case,'api':api,'scaled_ns_per_call':measurement['ns_per_call'],'comparisons':measurement['paired_ratios']})
for name in ['archive-wrapper-v1.py','archive-and-window2.py','summarize-timing.py']:shutil.copy2(Path('/tmp/lcb-arm-scaled-load')/name,out/name)
(out/'summary.json').write_text(json.dumps({'scope':'Native Linux ARM in Docker VM, two separate quiet windows; nine randomized paired rounds, three payloads, five labels, 250ms GCC calibration, two warmups, three APIs. Ratios are elapsed scaled/reference; lower is faster. Bootstrap intervals descriptive, no multiple-comparison correction. No universal performance claim.','rows':rows},indent=2))
lines=['# ARM scaled-load timing','', 'Two separate quiet windows, 9 randomized paired rounds per payload, 250 ms GCC calibration, 2 warmups, five labels. All 135 records/window agreed on sinks; each window passed its own 485-file host/guest postvalidation. Ratios below compare elapsed scaled / names; lower is faster. Intervals are descriptive bootstrap 95% intervals, without multiple-comparison correction. Raw per-label comparisons including GCC, original QBE and corrected QBE remain in summary.json and each timing.json.','', 'The first archive wrapper expected status `passed` instead of the protocol’s `completed` and exited after successful measurement postvalidation. Its error is retained separately; a new wrapper finalized the archive and ran window 2 without changing protocol or binaries. No samples were removed or rerun for this wrapper error.','', '| Window | Payload | API | Ratio | Interval | Paired CV |','|---|---|---|---:|---|---:|']
for row in rows:
 s=row['comparisons']['names'];lo,hi=s['median_bootstrap95'];lines.append(f"| {row['window']} | {row['payload']} | {row['api']} | {s['median']:.4f} | {lo:.4f}–{hi:.4f} | {s['cv']:.3f} |")
(out/'README.md').write_text('\n'.join(lines)+'\n')
(out/'manifest.json').write_text(json.dumps({str(p.relative_to(out)):sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json'},indent=2))
print((out/'README.md').read_text());print('manifest',sha(out/'manifest.json'))
