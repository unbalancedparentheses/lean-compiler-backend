from pathlib import Path
import json,hashlib,shutil,struct
p=Path(__file__).parent;sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest();old=p/'report.json';sup=p/'superseded-incomplete-extra-check';sup.mkdir(exist_ok=False)
for n in ['report.json','review.py']:shutil.copy2(p/n,sup/n)
r=json.loads(old.read_text());r['superseded_report_sha256']=sha(sup/'report.json');r['correction']='Earlier independent probe checked expected29-header subset only and failed to reject2extra reference-only custom sections. Its no-extra/complete profile interpretation is withdrawn. This corrected audit requires all31original-QBE/LLVM custom sections; LCB canonicalizes the three equivalent IR spellings into one section, whereas QBE preserves octal/hex spelling under LLVM.'
for t in r['targets']:
 obj=p/(t['target']+'.o');assert sha(obj)==t['object_sha256'];b=obj.read_bytes();off=struct.unpack_from('<Q',b,40)[0];size,count,idx=struct.unpack_from('<HHH',b,58);hs=[struct.unpack_from('<IIQQQQIIQQ',b,off+i*size) for i in range(count)];h=hs[idx];s=b[h[4]:h[4]+h[5]];rows=[{'name':s[h[0]:s.index(b'\0',h[0])].hex(),'flags':h[2],'type':h[1],'size':h[5]} for h in hs];assert rows==t['sections']
 expected=t['expected'].copy();expected[b'd\\040space'.hex()]=3;expected[b'd\\x20space'.hex()]=3;assert len(expected)==31
 matched=[x for x in rows if x['name'] in expected];assert len(matched)==31 and len({x['name'] for x in matched})==31
 for x in matched:assert x['flags']==expected[x['name']] and x['type']==1
 for name in [b'd space',b'd\\040space',b'd\\x20space']:assert next(x for x in matched if x['name']==name.hex())['size']==8
 ordinary={x.hex() for x in [b'',b'.text',b'.data',b'.bss',b'.note.GNU-stack',b'.symtab',b'.strtab',b'.shstrtab']}
 if t['target']=='riscv64-linux':
  attr=next(x for x in rows if x['name']==b'.riscv.attributes'.hex());assert attr['type']==0x70000003 and attr['flags']==0;ordinary.add(attr['name'])
 extra=[x for x in rows if x['name'] not in expected and x['name'] not in ordinary and x['type'] not in [4,9]];assert not extra,extra
 t['expected']=expected;t['custom_section_count']=31;t['unexpected_custom_sections']=[];t['scope']='Unchanged QBE fixture and host LLVM cross-assembler: exact31custom section headers/names/flags with no extras, including separate8-byte d space/d\\040space/d\\x20space. Object-only; no link/runtime or global-symbol-check claim.'
r['status']='passed-corrected-all-custom-headers';old.write_text(json.dumps(r,indent=2));(p/'README.md').write_text('''# Corrected independent original-QBE/LLVM object audit

The initial report is superseded: it checked a 29-name subset and omitted an extra-header rejection. All three saved objects also contained `d\\040space` and `d\\x20space`; the earlier complete-profile interpretation was incorrect.

The corrected audit reparses unchanged bound objects and requires exactly 31 custom sections, exact names/flags/type, 8-byte sizes for each of the three spellings, and no unexpected custom sections. Ordinary metadata/relocation headers are separately allowed; RV attributes require exact type/flags. Unchanged QBE preserves these lexical spellings with LLVM, whereas LCB canonicalizes the equivalent IR strings into one name (29 custom sections). This is a compatibility boundary, not compiler byte-equivalence. No C execution or global-symbol validation was performed by this independent object probe; root's matrix supplies those checks.
''');print('corrected',sha(old),'superseded',sha(sup/'report.json'))
