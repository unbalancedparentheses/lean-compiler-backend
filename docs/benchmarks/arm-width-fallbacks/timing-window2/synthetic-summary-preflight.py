from pathlib import Path
import json,hashlib,random,statistics,textwrap
w=Path('.build/linux-arm64/zlib-compression-widths');manifest=json.loads((w/'manifest.json').read_text());probe=(w/'probe.py').read_text();assert hashlib.sha256(probe.encode()).hexdigest()==manifest['probe_sha256'];labels=manifest['successful_builds'];cases=[p for p in manifest['payloads'] if p['timed']];samples=[{'case':p['name'],'label':label,'round':i,'measurement':{'compress_ns':1000+i+j,'uncompress_ns':200,'crc32_ns':100,'loops':[2,1,1],'sink':7}} for p in cases for j,label in enumerate(labels) for i in range(9)];result={'samples':samples,'summary':{}};rng=random.Random(20261022)
start=probe.index(' def stats(xs):');end=probe.index(" result['environment'].update",start);fragment=textwrap.dedent(probe[start:end]);exec(fragment)
assert result['sink_agreement']=='all labels and rounds' and len(samples)==216
for case,s in result['summary'].items():
 assert set(s)==set(labels)
 for label,apis in s.items():assert set(apis)=={'compress'} and set(apis['compress']['paired_ratios'])=={'gcc','qbe-original','qbe-corrected','indexed'}
(w/'synthetic-summary-preflight.json').write_text(json.dumps({'status':'passed','scope':'Synthetic216rows exercise exact extracted summaryand sink-validation code; no actualtiming orperformance evidence. Protocolunchanged.','protocol_sha256':manifest['script_sha256'],'probe_sha256':manifest['probe_sha256'],'test_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'labels':labels,'rows':len(samples)},indent=2)+'\n');print('synthetic summary passed')
