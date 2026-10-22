from pathlib import Path
import json,hashlib,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');out=root/'.build/linux-arm64/arm-indexed-main-zlib-review';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();r=json.loads((out/'report.json').read_text());execution=json.loads((out/'execution.json').read_text());guest=json.loads(Path('/tmp/arm-indexed-main-zlib-execution.log').read_text());assert sha(out/'execution.json')==guest['report_sha256']
summary={}
for target,modes in r['targets'].items():
 summary[target]={}
 for mode,labels in modes.items():
  totals={k:sum(x['text_bytes'] for x in v.values()) for k,v in labels.items()};totals['delta']=totals['after']-totals['before'];totals['crc32']={k:v['crc32']['text_bytes'] for k,v in labels.items()};totals['changed']={n:labels['after'][n]['text_bytes']-row['text_bytes'] for n,row in labels['before'].items() if labels['after'][n]['text_bytes']!=row['text_bytes']};summary[target][mode]=totals
  for label,units in labels.items():
   for unit,row in units.items():
    for suffix,key in [('.s','assembly_sha256'),('.o','object_sha256')]:
     p=out/target/mode/label/(unit+suffix);g=str(p).replace(str(root/'.build/linux-arm64'),'/work');assert sha(p)==row[key]==execution['initial_files'][g]
for p,h in r['bound_inputs'].items():assert sha(p)==h,p
for label,h in r['compiler_hashes'].items():assert sha(out/('compiler-'+label))==h
for source,name in [('/tmp/qualify-arm-indexed-main-zlib.py','qualify.py'),('/tmp/arm-indexed-main-zlib.log','build.log'),('/tmp/arm-indexed-main-zlib-execution.log','execution.log')]:shutil.copy2(source,out/name)
qualification={'status':'passed','compiler_before':r['before_identity'],'compiler_after':r['after_identity'],'baseline_assemblies_identical':r['baseline_identical'],'assemblies_and_objects':204,'object_report_guest_host_checks':408,'execution_report_guest_host_sha256':sha(out/'execution.json'),'postvalidation':'Original source/configuration/IR/binary/reference paths and immutable compiler copies unchanged; all reported object and assembly hashes equal host files and guest execution binding.','execution':'6 native ARM Linux upstream example executions and72 exact GCC-compressed profiles with Python decompression and own-backend decompression; Apple ARM objects assembled only.','timing':'Not run. No runtime performance claim.','commands':['python3 /tmp/qualify-arm-indexed-main-zlib.py','docker exec lcb-parity-linux python3 /work/arm-indexed-main-zlib-review/execute.py','python3 /tmp/finalize-arm-indexed-main-zlib.py'],'script_sha256':sha(out/'qualify.py'),'probe_sha256':sha(out/'execute.py'),'prior_private_evidence':'Earlier15ce→3506 preserved separately; not reused or relabelled. This is fresh combined-main1fb34f→e1166 qualification.'}
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(out/'qualification.json').write_text(json.dumps(qualification,indent=2)+'\n');shutil.copy2('/tmp/finalize-arm-indexed-main-zlib.py',out/'finalize.py');print(json.dumps({'qualification':qualification,'summary':summary},indent=2))
