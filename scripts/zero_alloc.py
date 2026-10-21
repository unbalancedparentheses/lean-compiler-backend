#!/usr/bin/env python3
"""Zero-sized static/dynamic allocation: alignment, live objects and no access."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, native_host

SOURCE='''export function l $zero_static() {
@s
 %a =l alloc8 8
 storel 37, %a
 %z4 =l alloc4 0
 %z8 =l alloc8 0
 %z16 =l alloc16 0
 %b =l alloc8 8
 storel 5, %b
 %m4 =l and %z4, 3
 %m8 =l and %z8, 7
 %m16 =l and %z16, 15
 %m =l or %m4, %m8
 %m =l or %m, %m16
 %x =l load %a
 %y =l load %b
 %r =l add %x, %y
 %r =l add %r, %m
 ret %r
}
export function l $zero_dynamic(l %n) {
@s
 %a =l alloc16 16
 storel 42, %a
 %z =l alloc16 %n
 %m =l and %z, 15
 %x =l load %a
 %r =l add %x, %m
 ret %r
}
export function l $zero_loop(l %n) {
@s
 %a =l alloc8 8
 storel 42, %a
 jmp @loop
@loop
 %i =l phi @s 0, @loop %next
 %z =l alloc16 0
 %next =l add %i, 1
 %more =w cultl %next, %n
 jnz %more, @loop, @done
@done
 %m =l and %z, 15
 %x =l load %a
 %r =l add %x, %m
 ret %r
}
'''
CALLER='''#include <stdint.h>
extern uint64_t zero_static(void),zero_dynamic(uint64_t),zero_loop(uint64_t);
int main(void) {for(unsigned i=0;i<1000;i++) {
 if(zero_static()!=42 || zero_dynamic(i%33)!=42 || zero_loop(i%33)!=42)return 1;
}return 0;}
'''

def exercise(compiler,work,run,cc,qbe,target,qtarget,execute=True):
    case=Path(work)/'zero-allocation';case.mkdir(exist_ok=True)
    source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
    source.write_text(SOURCE);caller.write_text(CALLER)
    result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
    for fn,args in [('zero_static',[]),('zero_dynamic',['0']),('zero_dynamic',['17']),('zero_loop',['32'])]:
        result=run([compiler,'--eval',source,fn,*args]);assert result.returncode==0 and result.stdout.strip()=='42',(fn,result.stderr,result.stdout)
    bad=case/'invalid-read.ssa';bad.write_text('function w $f() { @s %p =l alloc4 0 %x =w loadub %p ret %x }')
    result=run([compiler,'--eval',bad,'f']);assert result.returncode!=0 and 'outside an allocated object' in result.stderr
    if execute:
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,source],True);assert result.returncode==0,result.stderr
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label;result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True)
            if label=='qbe' and target=='x86_64-linux' and result.returncode==1:
                # QBE's empty leaf frame leaves rsp misaligned for alloc16 0.
                probe=case/'qbe-empty-frame.c';probe.write_text('#include <stdio.h>\nextern unsigned long zero_static(void),zero_dynamic(unsigned long),zero_loop(unsigned long);int main(void){printf("%lu %lu %lu\\n",zero_static(),zero_dynamic(0),zero_loop(32));}\n')
                result=run([cc,probe,asm,'-o',case/'probe'],True);assert result.returncode==0,result.stderr
                result=run([case/'probe'],True);assert result.returncode==0 and result.stdout=='50 42 42\n',(result.returncode,result.stdout,result.stderr)
                reference=case/'qbe-reference.ssa';reference.write_text(SOURCE.replace('alloc4 0','alloc16 16').replace('alloc8 0','alloc16 16').replace('alloc16 0','alloc16 16'))
                corrected=case/'qbe-reference.s'
                result=run([qbe,'-t',qtarget,'-o',corrected,reference],True);assert result.returncode==0,result.stderr
                result=run([cc,caller,corrected,'-o',case/'qbe-reference'],True);assert result.returncode==0,result.stderr
                result=run([case/'qbe-reference'],True)
                print('x86_64-linux: isolated pinned QBE alloc16 0 leaf alignment failure; positive-size oracle workaround and original Lean input checked separately',flush=True)
            assert result.returncode==0,(label,result.returncode,result.stderr)
    print(f'{target}: zero-sized static/dynamic/loop allocations preserve alignment and live objects; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-zero-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=work/'oracle/qbe'
        if native_host():
            shutil.copytree(ROOT/'third_party/qbe',qbe.parent)
            r=run(['make','-C',qbe.parent,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr
        exercise(LCB,work,run,cc,qbe,'aarch64-macos','arm64_apple',native_host())

if __name__=='__main__':main()
