#!/usr/bin/env python3
"""Typed ARM64 extuw omission with independent C and dirty-upper-bit controls."""
import hashlib,json,re
from pathlib import Path


def fixture():
    ir=[];decl=[];checks=[]
    def add(name,params,body,ctype,args,expected):
        ir.append(f'export function l ${name}({params}) {{\n@s\n{body}\n}}')
        decl.append(f'extern uint64_t {name}({ctype});')
        checks.append(f'if({name}({args}) != (uint64_t)({expected})) return {len(checks)+1};')
    for name,op,expected in [
        ('parameter','%a =w copy %x','x'),('binary','%a =w add %x, 2147483647','(uint32_t)(x+UINT32_C(2147483647))'),
        ('negative','%a =w neg %x','(uint32_t)(0-x)'),('divide','%a =w udiv %x, 3','x/3'),
        ('compare','%a =w csltw %x, 0','(int32_t)x<0'),
        ('call','%a =w call $dirty_word(l %dirty)','x'),
        ('float_bits','%f =s call $float_identity(s %fp)\n %a =w cast %f','bits'),
        ('float_convert','%a =w stosi %fp','(uint32_t)(int32_t)fp'),
        ('float_binary','%f =s add %fp, s_1.0\n %a =w cast %f','addedbits'),
        ('float_negate','%f =s neg %fp\n %a =w cast %f','bits^UINT32_C(0x80000000)')]:
        add(name,'w %x,l %dirty,s %fp',op+'\n %r =l extuw %a\n ret %r','uint32_t,uint64_t,float','x,dirty,fp',expected)
    add('dirty_long','l %x',' %r =l extuw %x\n ret %r','uint64_t','dirty','x')
    add('debug_word','w %x',' dbgloc 101, 1\n %r =l extuw %x\n dbgloc 102, 1\n ret %r','uint32_t','x','x')
    add('different_home','w %x',' %r =l extuw %x\n %v =w add %x, 1\n %wide =l extuw %v\n %sum =l add %r, %wide\n ret %sum','uint32_t','x','(uint64_t)x+(uint32_t)(x+1)')
    for kind,expr in [('ub','(uint8_t)x'),('sb','(uint32_t)(int32_t)(int8_t)x'),('uh','(uint16_t)x'),('sh','(uint32_t)(int32_t)(int16_t)x'),('uw','x'),('sw','x')]:
        add('load_'+kind,'l %p',f' %a =w load{kind} %p\n %r =l extuw %a\n ret %r','void*','&x',expr)
    add('variadic','w %n, ...',' %ap =l alloc16 32\n vastart %ap\n %a =w vaarg %ap\n %r =l extuw %a\n ret %r','uint32_t,...','0,x','x')
    add('phi_cycle','w %x,w %y,w %n',' jmp @loop\n@loop\n %a =w phi @s %x, @next %b\n %b =w phi @s %y, @next %a\n %i =w phi @s %n, @next %j\n jnz %i,@next,@end\n@next\n %j =w sub %i,1\n jmp @loop\n@end\n %r =l extuw %a\n ret %r','uint32_t,uint32_t,uint32_t','x,~x,i%7','i%7%2?~x:x')
    params=','.join(f'w %x{n}' for n in range(24));body=[]
    for n in range(24):body.append(f' %w{n} =l extuw %x{n}')
    acc='%w0'
    for n in range(1,24):body.append(f' %a{n} =l add {acc},%w{n}');acc=f'%a{n}'
    body.append(' ret '+acc)
    add('pressure',params,'\n'.join(body),','.join(['uint32_t']*24),','.join(['x']*24),'(uint64_t)x*24')
    c='''#include <stdint.h>
#include <string.h>
uint32_t dirty_word(uint64_t);
float float_identity(float f){return f;}
'''+ '\n'.join(decl)+'''
int main(void){uint64_t state=UINT64_C(0x23456789abcdef01);
uint32_t edges[]={0,1,127,128,255,32767,32768,65535,0x7fffffff,0x80000000,0xfffffffe,0xffffffff};
for(unsigned i=0;i<256;i++){state^=state<<13;state^=state>>7;state^=state<<17;
uint32_t x=i<12?edges[i]:(uint32_t)state;uint64_t dirty=UINT64_C(0xa5a5f00d00000000)|x;
float fp=(float)((int)(i%4096)-2048)+0.5f;uint32_t bits;memcpy(&bits,&fp,4);float added=fp+1.0f;uint32_t addedbits;memcpy(&addedbits,&added,4);
'''+ '\n'.join(checks)+'\n}return 0;}\n'
    return 'dbgfile "arm-extuw.c"\n'+'\n'.join(ir)+'\n',c,len(checks)*256


def exercise(compiler,work,run,cc,target,execute=True,qbe=None):
    assert target in ['aarch64-linux','aarch64-macos']
    d=Path(work)/'arm-extuw';d.mkdir(parents=True,exist_ok=True)
    ir,c,count=fixture();src=d/'input.ssa';caller=d/'caller.c';src.write_text(ir);caller.write_text(c)
    helper=d/'dirty-word.s';label=('_' if target.endswith('macos') else '')+'dirty_word'
    helper.write_text(f'.text\n.globl {label}\n.p2align 2\n{label}:\n ret\n')
    def checked(cmd,inside=False):
        r=run(cmd,inside);assert r.returncode==0,(cmd,r.stdout,r.stderr);return r
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'target':target,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(caller),'checks_per_mode':count if execute else 0,'modes':{},'negative_control':'not-run','original_qbe':'not-run'}
    obj=d/'caller.o'
    if execute:checked([cc,'-O2','-c',caller,'-o',obj],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/(mode+'.s');exe=d/mode;checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text()
        def body(name):
            label=('_' if target.endswith('macos') else '')+name
            return text.split('\n'+label+':\n',1)[1].split('\n.globl ',1)[0].split('\n.size ',1)[0]
        if mode!='baseline':
            assert not re.search(r'\tmov w(\d+), w\1\b',body('debug_word')),body('debug_word')
            assert re.search(r'\tmov w(\d+), w\1\b',body('dirty_long')),body('dirty_long')
        assert re.search(r'\.loc \d+ 101 1',text) and re.search(r'\.loc \d+ 102 1',text)
        report['modes'][mode]={'structural':'passed','execution':'not-run','assembly_sha256':sha(asm)}
        if execute:
            checked([cc,obj,helper,asm,'-o',exe],True);checked([exe],True);report['modes'][mode]['execution']='passed'
            if mode=='allocated':
                b=body('dirty_long');damaged=re.sub(r'\tmov w(\d+), w\1\b','\tnop',b,count=1);assert damaged!=b
                bad=d/'wrong-long-omission.s';bad.write_text(text.replace(b,damaged,1));badexe=d/'wrong-long-omission';checked([cc,obj,helper,bad,'-o',badexe],True)
                r=run([badexe],True);assert r.returncode==11,('mutation escaped or unrelated failure',r.returncode,r.stderr);report['negative_control']={'status':'detected','exit':r.returncode}
    if execute and qbe:
        asm=d/'qbe.s';exe=d/'qbe';checked([qbe,'-t','arm64_apple' if target.endswith('macos') else 'arm64','-o',asm,src],True)
        checked([cc,obj,helper,asm,'-o',exe],True);checked([exe],True);report['original_qbe']='passed'
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report


def main():
    import argparse,os,platform,shutil,subprocess,tempfile
    from fuzz import LCB,ROOT
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');ap.add_argument('--compiler',type=Path,default=LCB);a=ap.parse_args()
    execute=platform.machine() in ['arm64','aarch64'] and platform.system() in ['Darwin','Linux']
    if a.require_native:assert execute,'ARM64 native host required'
    target='aarch64-macos' if platform.system()=='Darwin' else 'aarch64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-arm-extuw-') as tmp:
        work=Path(tmp);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            p=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert p.returncode==0,p.stderr;qbe=oracle/'qbe'
        print(json.dumps(exercise(a.compiler.resolve(),work,run,cc,target,execute,qbe),indent=2))
if __name__=='__main__':main()
