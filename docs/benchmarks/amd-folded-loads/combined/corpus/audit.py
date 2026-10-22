from pathlib import Path
import json,re,hashlib
p=Path('/Users/unbalancedparen/projects/lean-compiler-backend');r=json.loads((p/'.build/amd-folded-main-corpus-raw.json').read_text());w=Path(r['work']);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();index={sha(x):x for x in w.glob('*-before.s')};rows=[]
def audit(a,b):
 old=a.read_text();new=b.read_text();expected,n=re.subn(r'(\tmov(?:sbl|swl|zbl|zwl|l) [-0-9]+\(%rax\), %eax\n)\tmovl %eax, %eax\n',r'\1',old);assert expected==new,(a,'unexplained change');return n
for row in r['cases']:
 if row['status']=='failed':
  assert row['target'].startswith('x86_64-') and row['mode']!='baseline';a=index[row['before']['assembly_sha256']];b=a.with_name(a.name.replace('-before.s','-after.s'));assert sha(b)==row['after']['assembly_sha256'];n=audit(a,b);assert n;rows.append({**row,'deleted_redundant_normalizations':n})
result={'status':'passed','raw_comparator_status':r['status'],'identical_assemblies':r['identical_assemblies'],'identical_refusals':r['identical_refusals'],'changed':rows,'scope':'Every difference is exactly deletion of redundant EAX self-copy after displacement word load. All baseline and nonAMD bytes unchanged.'};Path('/tmp/lcb-amd-folded-main-evidence/corpus-audit.json').write_text(json.dumps(result,indent=2));print(r['identical_assemblies'],r['identical_refusals'],len(rows),sum(x['deleted_redundant_normalizations'] for x in rows))
