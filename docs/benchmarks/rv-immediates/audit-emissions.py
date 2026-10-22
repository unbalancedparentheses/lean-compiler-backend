from pathlib import Path
import json,re
import argparse
p=argparse.ArgumentParser();p.add_argument('raw_report',type=Path);p.add_argument('output',type=Path);args=p.parse_args()
r=json.loads(args.raw_report.read_text());work=Path(r['work'])
inputs=sorted(set(x['input'] for x in r['cases']));counts={};total=0
pat=re.compile(r'\tli t1, (\d+)\n\t(addw?|subw?|and|or|xor|sllw?|srlw?|sraw?) t0, t0, t1\n')
for row in r['cases']:
 if row['status']=='identical_refusal':continue
 assert row['before']['exit']==row['after']['exit']==0,row
 i=inputs.index(row['input']);stem=f'{i}-{row["target"]}-{row["mode"]}'
 old=(work/(stem+'-before.s')).read_text();new=(work/(stem+'-after.s')).read_text()
 transformed=[0]
 def change(m):
  n=int(m[1]);op=m[2];word=op.endswith('w') or (op in ['and','or','xor'] and old[m.end():].startswith('\tslli t0, t0, 32\n\tsrli t0, t0, 32\n'))
  bits=32 if word else 64;value=n%(1<<bits)
  if value>=1<<(bits-1):value-=1<<bits
  base=op.removesuffix('w');suffix='w' if word and base not in ['and','or','xor'] else ''
  if base in ['sll','srl','sra']:imm=n%bits;mnemonic=base+'i'+suffix
  else:
   imm=-value if base=='sub' else value
   if not -2048<=imm<=2047:return m[0]
   mnemonic=('add' if base=='sub' else base)+'i'+suffix
  transformed[0]+=1
  return f'\t{mnemonic} t0, t0, {imm}\n'
 if row['target']=='riscv64-linux':
  a=b=0
  while a<len(old):
   end=old.index('\n',a)+1
   line=old[a:end]
   if new.startswith(line,b):a=end;b+=len(line);continue
   m=pat.match(old,a);assert m,(row['input'],row['mode'],a)
   replacement=change(m);assert replacement!=m[0] and new.startswith(replacement,b),(row['input'],row['mode'],a)
   a=m.end();b+=len(replacement)
  assert b==len(new)
 else:assert old==new
 if old!=new:counts[row['target']]=counts.get(row['target'],0)+1
 total+=transformed[0]
out={'status':'passed','compilers':r['compilers'],'cases':len(r['cases']),'unchanged_assemblies':r['identical_assemblies'],'matching_refusals':r['identical_refusals'],'expected_changed_assemblies':counts,'immediate_replacements':total,'raw_report':'assembly-comparison-raw.json','note':'Raw exact-equivalence gate intentionally reports changed assembly. Separate audit accepts only exact constant-load/register-operation replacement by corresponding encodable immediate, preserving all other bytes. Not a semantic proof.'}
args.output.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out))
