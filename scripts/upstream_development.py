#!/usr/bin/env python3
"""Supplementary independent callers for three unchanged QBE development fixtures.

These are not original upstream executable-driver tests. Private functions are
exposed solely by a tail-branch adapter appended to emitted assembly.
"""
from pathlib import Path
import hashlib,json,re
FIXTURES=['_gcm1.ssa','_fix3.ssa','_fix4.ssa']
CALLERS={
'_gcm1.ssa':'''#include <stdint.h>
extern uint32_t ifmv(uint32_t,uint32_t,uint32_t),hoist1(uint32_t,uint32_t,uint32_t),hoist2(uint32_t,uint32_t,uint32_t);
int main(void){uint64_t state=UINT64_C(0xfedcba9876543210);for(unsigned i=0;i<256;i++){
 state^=state<<13;state^=state>>7;state^=state<<17;uint32_t a=state,b=state>>32,p=(i%3)?(UINT32_C(0x80000000)|i):0,n=i%64+1;
 if(ifmv(p,a,b)!=(p?a+b:a-b))return 1;
 if(hoist1(n,a,b)!=a+b+n)return 2;
 if(hoist2(n,a,b)!=(n+1)*(a+b))return 3;
}return 0;}
''',
'_fix3.ssa':'''#include <stdint.h>
extern uint32_t lcb_dev_test(void);
int main(void){int32_t expected=-(100+11)*90/2+(2+4+6+8+10);return lcb_dev_test()!=(uint32_t)expected;}
''',
'_fix4.ssa':'''#include <stdint.h>
extern void lcb_dev_test(void);uint64_t a;
int main(void){static unsigned char composite[131073];unsigned count=0,wanted=0;
 for(unsigned p=2;p<=131072;p++){if(composite[p])continue;if(++count==10000){wanted=p;break;}if(p<=362)for(unsigned q=p*p;q<=131072;q+=p)composite[q]=1;}
 if(count!=10000||wanted!=104729)return 2;
 a=UINT64_C(0x8badf00d00000000);lcb_dev_test();return a!=(UINT64_C(0x8badf00d00000000)|wanted);}
'''}
def adapter(target):
 prefix='_' if target.endswith('macos') else '';branch='b' if target.startswith('aarch64') else 'jmp' if target.startswith('x86_64') else 'tail'
 return f'\n.text\n.globl {prefix}lcb_dev_test\n.p2align 2\n{prefix}lcb_dev_test:\n\t{branch} {prefix}test\n'
def exercise(compiler,work,run,cc,target,execute=True,qbe=None,source_root=None):
 root=Path(source_root) if source_root else Path(__file__).resolve().parents[1]/'third_party/qbe/test';d=Path(work)/'upstream-development';d.mkdir(parents=True,exist_ok=True)
 sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 def checked(cmd,inside=False):
  p=run(list(map(str,cmd)),inside);assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr);return p
 qtarget={'aarch64-macos':'arm64_apple','aarch64-linux':'arm64','x86_64-macos':'amd64_apple','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}[target]
 report={'scope':'Supplementary independent callers, distinct from58 original upstream executable fixtures. Original SSA files unchanged; append-only assembly tail adapter for private functions.','target':target,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'execution':execute,'checks_per_lcb_mode':770 if execute else 0,'fixtures':{},'negative_control':'not-run','original_qbe':'not-run'}
 for name in FIXTURES:
  case=d/Path(name).stem;case.mkdir(exist_ok=True);src=case/name;src.write_bytes((root/name).read_bytes());caller=case/'caller.c';caller.write_text(CALLERS[name]);row={'original_ir_sha256':sha(src),'caller_sha256':sha(caller),'checks_per_backend':768 if name=='_gcm1.ssa' else 1,'backends':{}};report['fixtures'][name]=row
  modes=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('qbe',[])] if execute and qbe else [])
  for label,flags in modes:
   asm=case/(label+'.s')
   if label=='qbe':checked([qbe,'-t',qtarget,'-o',asm,src],True)
   else:checked([compiler,src,'--target',target,*flags,'-o',asm])
   original=asm.read_text();combined=case/(label+'-caller.s');text=original+(adapter(target) if name!='_gcm1.ssa' else '');combined.write_text(text);assert combined.read_text().startswith(original)
   result={'assembly_sha256':sha(asm),'caller_assembly_sha256':sha(combined),'execution':'not-run'};row['backends'][label]=result
   if execute:
    exe=case/label;linkflags=['-no-pie'] if target=='riscv64-linux' and label=='qbe' else [];checked([cc,'-O2',*linkflags,caller,combined,'-o',exe],True);checked([exe],True);result['execution']='passed'
    if label=='optimized' and name=='_gcm1.ssa':
     symbol='_ifmv' if target.endswith('macos') else 'ifmv';zero='mov w0, #0' if target.startswith('aarch64') else 'xorl %eax, %eax' if target.startswith('x86_64') else 'li a0, 0';bad=case/'wrong-return.s';assert text.count('\n'+symbol+':\n')==1;bad.write_text(text.replace('\n'+symbol+':\n','\n'+symbol+':\n\t'+zero+'\n\tret\n',1));badexe=case/'wrong-return';checked([cc,'-O2',caller,bad,'-o',badexe],True);p=run([str(badexe)],True);assert p.returncode==1,(p.returncode,p.stderr);report['negative_control']={'status':'detected','exit':1}
  assert sha(src)==sha(root/name)
 if execute and qbe:report['original_qbe']='passed';report['original_qbe_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
 (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report


def main():
    import argparse,os,platform,shutil,subprocess,tempfile
    from fuzz import LCB,ROOT
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--compiler',type=Path,default=LCB);parser.add_argument('--require-native',action='store_true');args=parser.parse_args()
    machine=platform.machine().lower();target={('Darwin','arm64'):'aarch64-macos',('Darwin','x86_64'):'x86_64-macos',('Linux','aarch64'):'aarch64-linux',('Linux','arm64'):'aarch64-linux',('Linux','x86_64'):'x86_64-linux',('Linux','amd64'):'x86_64-linux',('Linux','riscv64'):'riscv64-linux'}.get((platform.system(),machine));execute=target is not None
    if args.require_native:assert execute,'supported native target required'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-upstream-development-') as tmp:
        work=Path(tmp);qbe=None;cc=os.environ.get('LCB_CC','cc')
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);p=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert p.returncode==0,p.stderr;qbe=oracle/'qbe'
        print(json.dumps(exercise(args.compiler.resolve(),work,run,cc,target or 'aarch64-macos',execute,qbe,ROOT/'third_party/qbe/test'),indent=2))

if __name__=='__main__':main()
