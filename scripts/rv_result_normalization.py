#!/usr/bin/env python3
"""Independent C oracle for RV64 result normalization and preserved narrowing."""
import argparse, hashlib, json, os, platform, shlex, subprocess, tempfile
from pathlib import Path
from fuzz import LCB


def fixture():
    ir=[];decl=[];checks=[]
    def add(name,body,expr):
        ir.append(f'export function l ${name}(l %x,l %y) {{\n@s\n'+body+'\n ret %r\n}')
        decl.append(f'extern uint64_t {name}(uint64_t,uint64_t);')
        checks.append(f'if({name}(x,y)!=(uint64_t)({expr}))return 1;')
    for w in ['w','l']:
        typ='uint32_t' if w=='w' else 'uint64_t'
        for op,expr in [('extub','(uint8_t)x'),('extuh','(uint16_t)x'),('extsb','(int8_t)x'),('extsh','(int16_t)x'),('neg','0-x')]+([('extuw','(uint32_t)x'),('extsw','(int32_t)x')] if w=='l' else []):
            add(f'{op}_{w}',f' %a ={w} {op} %x\n %r =l '+('extuw' if w=='w' else 'copy')+' %a',f'({typ})({expr})')
        for cmp,c in [('eq','=='),('ne','!='),('ult','<'),('ule','<='),('ugt','>'),('uge','>=')]:
            add(f'{cmp}_{w}',f' %a =w c{cmp}{w} %x,%y\n %r =l extuw %a',f'(({typ})x {c} ({typ})y)')
        for cmp,c in [('slt','<'),('sle','<='),('sgt','>'),('sge','>=')]:
            st='int32_t' if w=='w' else 'int64_t'
            add(f'{cmp}_{w}',f' %a =w c{cmp}{w} %x,%y\n %r =l extuw %a',f'(({st})x {c} ({st})y)')
    add('copy_narrow',' %a =w copy %x\n %r =l extuw %a','(uint32_t)x')
    add('cast_bits',' %a =w copy %x\n %f =s cast %a\n %b =w cast %f\n %r =l extuw %b','(uint32_t)x')
    # Negative immediates set upper bits for ori/xori; their final normalization stays.
    for op,c in [('and','&'),('or','|'),('xor','^')]:
        add(op+'_negative',f' %a =w {op} %x,-1\n %r =l extuw %a',f'(uint32_t)(x {c} UINT32_MAX)')
    ir.append('''export function l $va_word(w %n,...) {
@s
 %p =l alloc8 8
 vastart %p
 %a =w vaarg %p
 %r =l extuw %a
 ret %r
}''')
    decl.append('extern uint64_t va_word(int,...);')
    checks.append('if(va_word(0,(uint32_t)x)!=(uint32_t)x)return 2;')
    c='#include <stdint.h>\n'+ '\n'.join(decl)+'''
int main(void){uint64_t state=UINT64_C(0x346781234abcd);
uint64_t edges[]={0,1,127,128,255,32767,32768,65535,0x7fffffff,0x80000000,0xffffffff,UINT64_C(0x8000000000000000),UINT64_MAX};
for(unsigned i=0;i<256;i++){state^=state<<13;state^=state>>7;state^=state<<17;
uint64_t x=i<13?edges[i]:state,y=edges[i%13];
'''+ '\n'.join(checks)+'\n}return 0;}\n'
    return '\n'.join(ir)+'\n',c,len(checks)*256


def exercise(compiler,work,run,cc,target='riscv64-linux',execute=True):
    assert target=='riscv64-linux'
    case=Path(work)/'rv-result-normalization';case.mkdir(parents=True,exist_ok=True)
    ir,c,count=fixture();src=case/'input.ssa';caller=case/'caller.c';src.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        p=run(cmd,inside);assert p.returncode==0,(cmd,p.stdout,p.stderr);return p
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'target':target,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(caller),'emitted_checks_per_mode':count,'executed_checks_per_mode':count if execute else 0,'modes':{},'negative_control':'not-run'}
    obj=case/'caller.o'
    if execute:checked([cc,'-O2','-c',caller,'-o',obj],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=case/(mode+'.s');exe=case/mode
        checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text()
        def body(name):
            return text.split('\n'+name+':\n',1)[1].split('\n.size '+name+',',1)[0]
        if mode=='baseline':
            norm='\tslli t0, t0, 32\n\tsrli t0, t0, 32'
            for name,last in [('eq_w','seqz t0, t0'),('ne_w','snez t0, t0'),
                              ('ult_w','sltu t0, t0, t1'),('slt_w','slt t0, t0, t1'),
                              ('extub_w','andi t0, t0, 255'),('extuh_w','srli t0, t0, 48'),
                              ('va_word','lwu t0, 0(t1)')]:
                b=body(name);assert '\t'+last+'\n'+norm not in b
                assert '\t'+last+'\n' in b
            assert '\tori t0, t0, -1\n'+norm in body('or_negative')
            assert '\txori t0, t0, -1\n'+norm in body('xor_negative')
            assert '\tsrai t0, t0, 56\n'+norm in body('extsb_w')
        report['modes'][mode]={'structural':'passed','execution':'not-run'}
        if execute:
            checked([cc,obj,asm,'-o',exe],True);checked([exe],True);report['modes'][mode]['execution']='passed'
            if mode=='baseline':
                old='\tandi t0, t0, 255';assert old in body('extub_w')
                damaged=text.replace(old,'\tandi t0, t0, 127',1);bad=case/'bad.s';bad.write_text(damaged);badexe=case/'bad'
                checked([cc,obj,bad,'-o',badexe],True);p=run([badexe],True);assert p.returncode==1,(p.returncode,p.stderr);report['negative_control']='detected'
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--work',type=Path);ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='');ap.add_argument('--require-native',action='store_true');a=ap.parse_args()
    execute=(platform.system()=='Linux' and platform.machine()=='riscv64') or bool(a.runner)
    if a.require_native:assert execute,'RV64 execution unavailable'
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(a.cc)+cmd[1:] if cmd[0]==a.cc else shlex.split(a.runner)+cmd
        return subprocess.run(cmd,text=True,capture_output=True,timeout=180)
    if a.work:exercise(a.compiler.resolve(),a.work.resolve(),run,a.cc,execute=execute)
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-rv-result-') as d:exercise(a.compiler.resolve(),Path(d),run,a.cc,execute=execute)
if __name__=='__main__':main()
