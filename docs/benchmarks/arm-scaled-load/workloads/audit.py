from pathlib import Path
import hashlib,json,re,collections
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');private=Path('/tmp/lcb-arm-scaled-load');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def audit(before,after):
 a=before.read_text().splitlines();b=after.read_text().splitlines();i=j=0;function='';counts=collections.Counter();sites=[]
 while i<len(a) and j<len(b):
  if re.fullmatch(r'[A-Za-z_]\w*:',a[i]):function=a[i][:-1]
  if a[i]==b[j]:i+=1;j+=1;continue
  old_start=i;new_start=j;spill=False
  read=re.fullmatch(r'\tldr x9, (\[sp, #\d+\])',a[i])
  if read and i+4<len(a):
   shifted=re.fullmatch(r'\tlsl x9, x9, #(\d+)',a[i+1]);stored=re.fullmatch(r'\tstr x9, (\[sp, #\d+\])',a[i+2]);reload=re.fullmatch(r'\tldr x10, (\[sp, #\d+\])',a[i+3])
   assert shifted and stored and reload and stored[1]==reload[1],(before,i,a[i:i+5])
   assert b[j]=='\tldr x10, '+read[1],(before,i,b[j]);j+=1;i+=4
   dest,index,k='10','10',shifted[1];spill=True
  else:
   shift=re.fullmatch(r'\tlsl x(\d+), x(\d+), #(\d+)',a[i]);assert shift,(before,i,a[i:i+3],b[j:j+3])
   dest,index,k=shift.groups();i+=1
   while i<len(a) and re.fullmatch(r'\tldr x(?:9|10), \[sp, #\d+\]',a[i]):
    assert a[i]==b[j] and not a[i].startswith('\tldr x'+index+','),(before,i,'scratch clobber')
    i+=1;j+=1
  load=re.fullmatch(r'\t(ldr(?:b|h|sb|sh|sw)?) ([wx]\d+), \[x(\d+), x(\d+)\]',a[i]);assert load,(before,i,a[i:i+3])
  op,result,left,right=load.groups();assert (left==dest)!=(right==dest),(before,i)
  base=right if left==dest else left
  assert b[j]==f'\t{op} {result}, [x{base}, x{index}, lsl #{k}]',(before,i,b[j])
  size=1 if op in ['ldrb','ldrsb'] else 2 if op in ['ldrh','ldrsh'] else 4 if op=='ldrsw' or result.startswith('w') else 8
  assert int(k)==0 or 1<<int(k)==size
  counts[function]+=1;sites.append({'function':function,'old_line':old_start+1,'new_line':new_start+1,'old':a[old_start:i+1],'new':b[new_start:j+1],'bytes':size,'spilled_shift':spill});i+=1;j+=1
 assert i==len(a) and j==len(b),(before,'trailing changes')
 return {'before_sha256':sha(before),'after_sha256':sha(after),'folds':sum(counts.values()),'functions':dict(counts),'sites':sites}

z=root/'.build/linux-arm64/arm-scaled-main-zlib-review';old=root/'.build/linux-arm64/arm-scaled-load-zlib';rows=[];bridge=[]
for target in ['aarch64-linux','aarch64-macos']:
 for mode in ['baseline','allocated','optimized']:
  for a in sorted((z/target/mode/'before').glob('*.s')):
   b=a.parent.parent/'after'/a.name;rows.append({'target':target,'mode':mode,'unit':a.stem,**audit(a,b)})
   for label in ['before','after']:
    new=z/target/mode/label/a.name;prior=old/target/mode/label/a.name
    same=new.read_bytes()==prior.read_bytes();bridge.append({'target':target,'mode':mode,'unit':a.stem,'label':label,'identical':same,'main_sha256':sha(new),'private_sha256':sha(prior)})
    assert same,(new,'private bridge differs')
(z/'delta-audit.json').write_text(json.dumps({'status':'passed','rows':rows,'private_bridge':bridge},indent=2))
print('all102before-after pairs audited;204private/main assembly bridges identical;folds',sum(r['folds'] for r in rows))
