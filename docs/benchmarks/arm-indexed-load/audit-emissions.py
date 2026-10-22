#!/usr/bin/env python3
"""Audit this corpus: every change must be an adjacent add/load contraction."""
import json,re,sys
from pathlib import Path
r=json.loads(Path(sys.argv[1]).read_text());work=Path(r['work']);inputs=sorted({x['input'] for x in r['cases']});rows=[]
pattern=re.compile(r'\tadd x(\d+), x(\d+), x(\d+)\n\t(ldr(?:b|h|sb|sh|sw)?) ([wx]\d+), \[x\1\]\n')
for row in r['cases']:
 if row['status']!='failed':continue
 assert row['target'].startswith('aarch64-') and row['mode']!='baseline'
 assert row['before']['exit']==row['after']['exit']==0
 i=inputs.index(row['input']);stem=f"{i}-{row['target']}-{row['mode']}"
 before=(work/(stem+'-before.s')).read_text();after=(work/(stem+'-after.s')).read_text()
 # Permit selection of any subset of matching adjacent pairs, while preserving
 # every other byte. Not every syntactic pair necessarily has sole-use IR.
 pos=0;out=[];count=0
 for m in pattern.finditer(before):
  out.append(before[pos:m.start()]);replacement=f'\t{m[4]} {m[5]}, [x{m[2]}, x{m[3]}]\n'
  prefix=''.join(out)
  if after.startswith(prefix+replacement):out.append(replacement);count+=1
  else:out.append(m[0])
  pos=m.end()
 out.append(before[pos:]);assert ''.join(out)==after,(row['input'],row['target'],row['mode'])
 rows.append({'input':row['input'],'target':row['target'],'mode':row['mode'],'contractions':count})
assert len(rows)==20
Path(sys.argv[2]).write_text(json.dumps({'changed_assemblies':len(rows),'instructions_removed':sum(x['contractions'] for x in rows),'rows':rows},indent=2)+'\n')
print(len(rows),'changed assemblies audited')
