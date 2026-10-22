from pathlib import Path
import json,re,hashlib
p=Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64/amd-folded-main-review/zlib');r=json.loads((p/'report.json').read_text());rows=[]
for target,modes in r['targets'].items():
 for mode,labels in modes.items():
  for name,before in labels['before'].items():
   a=p/target/mode/'before'/(name+'.s');b=p/target/mode/'after'/(name+'.s');old=a.read_text();new=b.read_text();expected,n=re.subn(r'(\tmov(?:sbl|swl|zbl|zwl|l) [-0-9]+\(%rax\), %eax\n)\tmovl %eax, %eax\n',r'\1',old);assert expected==new,(target,mode,name);assert mode!='baseline' or n==0
   rows.append({'target':target,'mode':mode,'unit':name,'removed_normalizations':n,'text_before':before['text_bytes'],'text_after':labels['after'][name]['text_bytes'],'assembly_before':before['assembly_sha256'],'assembly_after':labels['after'][name]['assembly_sha256']})
(p/'audit.json').write_text(json.dumps({'status':'passed','rows':rows,'note':'Object text reflects assembler branch relaxation/alignment as well as removed two-byte instructions; static reduction only, no timing.'},indent=2))
for target in r['targets']:
 for mode in r['targets'][target]:
  sub=[x for x in rows if x['target']==target and x['mode']==mode];print(target,mode,sum(x['removed_normalizations'] for x in sub),sum(x['text_after']-x['text_before'] for x in sub))
