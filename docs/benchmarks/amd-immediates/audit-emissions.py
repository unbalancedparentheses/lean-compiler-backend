import argparse,json,re
from pathlib import Path
pattern=re.compile(r'\tmov(absq|l) \$(\d+), %(rcx|ecx)\n\t(add|sub|imul|and|or|xor|shl|shr|sar)(q|l) %(?:rcx|ecx|cl), %(rax|eax)\n')
def expected(text):
 changed=[]
 def sub(m):
  form,n,reg,op,s,dest=m.groups();n=int(n);bits=64 if s=='q' else 32
  value=n%(1<<bits);value=value-(1<<bits) if value>=(1<<(bits-1)) else value
  if op in ('shl','shr','sar'):immediate=n%bits
  elif -(1<<31)<=value<(1<<31):immediate=value
  else:return m.group(0)
  changed.append(op)
  return f'\t{op}{s} ${immediate}, %{dest}'+(f', %{dest}' if op=='imul' else '')+'\n'
 return pattern.sub(sub,text),changed
p=argparse.ArgumentParser();p.add_argument('raw_report',type=Path);p.add_argument('output',type=Path);args=p.parse_args()
r=json.loads(args.raw_report.read_text());work=Path(r['work']);inputs=sorted(set(x['input'] for x in r['cases']));counts={};operations={}
for row in r['cases']:
 if row['status']=='identical_refusal':continue
 assert row['before']['exit']==row['after']['exit']==0,row
 stem=f'{inputs.index(row["input"])}-{row["target"]}-{row["mode"]}'
 old=(work/(stem+'-before.s')).read_text();new=(work/(stem+'-after.s')).read_text()
 if row['target'].startswith('x86_64-'):
  transformed,ops=expected(old);assert transformed==new,stem
  for op in ops:operations[op]=operations.get(op,0)+1
 else:assert old==new,stem
 if old!=new:counts[row['target']]=counts.get(row['target'],0)+1
out={'status':'passed','compilers':r['compilers'],'cases':len(r['cases']),'unchanged_assemblies':r['identical_assemblies'],'matching_refusals':r['identical_refusals'],'expected_changed_assemblies':counts,'immediate_replacements':operations,'note':'Raw exact comparison reports intended differences. This separate audit accepts only encodable immediate substitutions for constant loads plus matching arithmetic/bitwise/shift instructions. All other bytes unchanged. Not a semantic proof.'}
args.output.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
