from pathlib import Path
import sys,subprocess,json,hashlib,struct,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(root/'scripts'));import elf_section_names as helper
w=Path(__file__).parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();qbe=w/'qbe';shutil.copy2(root/'.build/syntax-main-review/qbe-snapshot',qbe)
src=w/'input.ssa';text,caller,expected,names=helper.fixture();src.write_text(text);(w/'caller.c').write_text(caller);commands=[];reports=[]
def run(c):
 p=subprocess.run(list(map(str,c)),capture_output=True,text=True,timeout=120);commands.append({'command':list(map(str,c)),'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr});assert p.returncode==0,commands[-1];return p
for target,qtarget in [('aarch64-linux','arm64'),('x86_64-linux','amd64_sysv'),('riscv64-linux','rv64')]:
 asm=w/(target+'.s');obj=w/(target+'.o');run([qbe,'-t',qtarget,'-o',asm,src]);run(['clang','--target='+target+'-gnu','-c',asm,'-o',obj]);b=obj.read_bytes();offset=struct.unpack_from('<Q',b,40)[0];size,count,idx=struct.unpack_from('<HHH',b,58);headers=[struct.unpack_from('<IIQQQQIIQQ',b,offset+i*size) for i in range(count)];strh=headers[idx];table=b[strh[4]:strh[4]+strh[5]];sections=[{'name':table[h[0]:table.index(b'\0',h[0])].hex(),'flags':h[2],'type':h[1],'size':h[5]} for h in headers]
 wanted={bytes.fromhex(n).replace(b'\\',b'\\\\').replace(b'"',b'\\"').hex():f for n,f in expected.items()};actual={x['name']:x for x in sections if x['name'] in wanted};assert len(actual)==29 and all(actual[n]['flags']==f and actual[n]['type']==1 for n,f in wanted.items());assert bytes.fromhex(next(x for x in wanted if b'quote' in bytes.fromhex(x)))==b'dquote\\"name'
 reports.append({'target':target,'profile':'LLVM-literal','expected':wanted,'sections':sections,'assembly_sha256':sha(asm),'object_sha256':sha(obj),'scope':'Unchanged QBE emits fixture; host LLVM cross-assembles exact29 section name bytes/flags. No linking/execution in this independent probe.'})
report={'status':'passed','qbe_sha256':sha(qbe),'input_sha256':sha(src),'helper_sha256_at_import':sha(Path(helper.__file__)),'commands':commands,'targets':reports};(w/'report.json').write_text(json.dumps(report,indent=2));print('all3 unchanged QBE LLVM literal-name objects pass',sha(w/'report.json'))
