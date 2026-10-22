from pathlib import Path
import subprocess,struct,json,hashlib
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');w=root/'.build/linux-arm64/octal-readonly-probe';w.mkdir(exist_ok=True);qbe=root/'.build/syntax-main-review/qbe-snapshot';lcb=root/'.build/lcb-aggregate-main';commands=[]
def run(cmd):
 p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);r=dict(command=list(map(str,cmd)),exit=p.returncode,stdout=p.stdout,stderr=p.stderr);commands.append(r);return r

def object_data(p):
 b=p.read_bytes()
 if b[:4]==b'\x7fELF':
  off=struct.unpack_from('<Q',b,40)[0];sz,n,idx=struct.unpack_from('<HHH',b,58);heads=[struct.unpack_from('<IIQQQQIIQQ',b,off+i*sz) for i in range(n)];h=heads[idx];strings=b[h[4]:h[4]+h[5]]
  h=next(h for h in heads if strings[h[0]:strings.index(b'\0',h[0])]==b'.data');return b[h[4]:h[4]+h[5]]
 assert struct.unpack_from('<I',b)[0]==0xfeedfacf
 ncmds=struct.unpack_from('<I',b,16)[0];pos=32
 for _ in range(ncmds):
  cmd,size=struct.unpack_from('<II',b,pos)
  if cmd==0x19:
   nsects=struct.unpack_from('<I',b,pos+64)[0]
   for i in range(nsects):
    h=pos+72+i*80;name=b[h:h+16].split(b'\0')[0]
    if name==b'__data':size,offset=struct.unpack_from('<QI',b,h+40);return b[offset:offset+size]
  pos+=size
 raise AssertionError('data section missing')

wide='A'+''.join('\\%03o'%i for i in range(256,512))+'Z'+r'X\378Y\4000Z\000Q\7777R'
wide_bytes=b'A'+bytes(range(256))+b'ZX\x1f8Y\x000Z\x00Q\xff7R'
narrow=r'X\000Y\377Z\378Q\0400R';narrow_bytes=b'X\x00Y\xffZ\x1f8Q 0R'
rows=[]
for case,token,expected in [('wide',wide,wide_bytes),('narrow',narrow,narrow_bytes)]:
 src=w/(case+'.ssa');src.write_text('export data $octets = { b "'+token+'" }\n');caller=w/(case+'.c');caller.write_text('#include <stdio.h>\nextern unsigned char octets[];static const unsigned char expected[]={'+','.join(map(str,expected))+'};int main(void){int fail=0;for(unsigned i=0;i<sizeof expected;i++){printf("%02x",octets[i]);fail|=octets[i]!=expected[i];}puts("");return fail;}\n')
 for target,qt,cc,runner in [('aarch64-macos','arm64_apple',['cc'],[]),('x86_64-macos','amd64_apple',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux','arm64',['gcc'],[]),('x86_64-linux','amd64_sysv',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux','rv64',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
  linux=target.endswith('linux')
  def native(cmd):return run(['docker','exec','lcb-parity-linux',*[str(x).replace(str(root/'.build/linux-arm64'),'/work') for x in cmd]]) if linux else run(cmd)
  for label in ['lcb','qbe']:
   asm=w/f'{case}-{target}-{label}.s';obj=asm.with_suffix('.o');exe=w/f'{case}-{target}-{label}';r=dict(case=case,target=target,label=label,expected_hex=expected.hex())
   r['emit']=run([qbe,'-t',qt,'-o',asm,src] if label=='qbe' else [lcb,src,'--target',target,'-o',asm])
   if r['emit']['exit']==0:
    r['assemble']=native([*cc,'-c',asm,'-o',obj])
    if r['assemble']['exit']==0:
     data=object_data(obj);r['object_hex']=data.hex();r['object_matches']=data==expected
     r['link']=native([*cc,caller,obj,'-o',exe])
     if not r['link']['exit']:r['execute']=native([*runner,exe]);r['runtime_matches']=r['execute']['exit']==0 and r['execute']['stdout'].strip()==expected.hex()
   rows.append(r)
report=dict(lcb_identity=subprocess.check_output([lcb,'--build-identity'],text=True).strip(),qbe_sha256=hashlib.sha256(qbe.read_bytes()).hexdigest(),rows=rows)
Path('/tmp/lcb-octal-probe/report.json').write_text(json.dumps(report,indent=2));print([(r['case'],r['target'],r['label'],r['emit']['exit'],r.get('assemble',{}).get('exit'),r.get('object_matches'),r.get('runtime_matches'),len(r.get('assemble',{}).get('stderr',''))) for r in rows])
