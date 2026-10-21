#!/usr/bin/env python3
"""Aggregate lifetime/padding, x8+x9, opaque layouts and Darwin variadic edges."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

SOURCE='''type :small = { l }
type :padded = { b, l }
type :big = { l 3 }
type :opaque = align 8 { 24 }
type :aligned = align 8 { s }
type :nested = { :aligned 2 }
function :small $make(l %v) {
@entry
 %p =l alloc8 8
 storel %v, %p
 ret %p
}
export function l $reuse() {
@entry
 jmp @loop
@loop
 %i =l phi @entry 0, @again %next
 %previous =l phi @entry 0, @again %r
 %r =:small call $make(l %i)
 %done =w ceql %i, 1
 jnz %done, @end, @again
@again
 %next =l add %i, 1
 jmp @loop
@end
 %v =l loadl %previous
 ret %v
}
export function l $distinct() {
@entry
 %a =:small call $make(l 11)
 %b =:small call $make(l 22)
 %x =l loadl %a
 %y =l loadl %b
 %sum =l add %x, %y
 ret %sum
}
function :padded $padding_echo(:padded %p) {
@entry
 ret %p
}
export function l $padding() {
@entry
 %p =l alloc8 16
 storeb 42, %p
 %p8 =l add %p, 8
 storel 7, %p8
 %r =:padded call $padding_echo(:padded %p)
 %r8 =l add %r, 8
 %a =l loadub %r
 %b =l loadl %r8
 %sum =l add %a, %b
 ret %sum
}
export function w $padding_bad() {
@entry
 %p =l alloc8 16
 storeb 42, %p
 %r =:padded call $padding_echo(:padded %p)
 %r1 =l add %r, 1
 %v =w loadub %r1
 ret %v
}
function :big $env_make(env %env, l %v) {
@entry
 %p =l alloc8 24
 storel %env, %p
 %p8 =l add %p, 8
 storel %v, %p8
 %p16 =l add %p, 16
 storel 99, %p16
 ret %p
}
export function :big $environment(l %v) {
@entry
 %r =:big call $env_make(env 42, l %v)
 ret %r
}
export function :opaque $opaque_echo(:opaque %p) {
@entry
 ret %p
}
export function d $aligned_tail(:aligned %p, d %v) {
@entry
 ret %v
}
export function d $nested_tail(:nested %p, d %v) {
@entry
 ret %v
}
export function l $varargs_big(:big %p) {
@entry
 %r =l call $c_variadic(w 1, ..., :big %p, l 7)
 ret %r
}
export function l $varargs_small(:small %p) {
@entry
 %r =l call $c_variadic_small(w 1, ..., :small %p, l 7)
 ret %r
}
export function l $receive_varargs(w %unused, ...) {
@entry
 %ap =l alloc8 8
 vastart %ap
 %cursor =l loadl %ap
 %value =l loadl %cursor
 %next =l add %cursor, 8
 %tail =l loadl %next
 %sum =l add %value, %tail
 ret %sum
}
export function l $model_varargs() {
@entry
 %p =l alloc8 8
 storel 123, %p
 %r =l call $receive_varargs(w 1, ..., :small %p, l 7)
 ret %r
}
'''

C='''#include <stdarg.h>
#include <stdint.h>
typedef struct { uint64_t x; } Small;
typedef struct { uint64_t x,y,z; } Big;
typedef struct __attribute__((aligned(8))) { float x; } Aligned;
typedef struct { Aligned a[2]; } Nested;
extern uint64_t reuse(void), distinct(void), padding(void), model_varargs(void);
extern Big environment(uint64_t), opaque_echo(Big);
extern double aligned_tail(Aligned,double), nested_tail(Nested,double);
extern uint64_t varargs_big(Big), varargs_small(Small), receive_varargs(int,...);
uint64_t c_variadic(int ignored,...) {
 (void)ignored; va_list ap; va_start(ap,ignored);
 Big b=va_arg(ap,Big); uint64_t v=va_arg(ap,uint64_t); va_end(ap);
 return b.x+b.y+b.z+v;
}
uint64_t c_variadic_small(int ignored,...) {
 (void)ignored; va_list ap; va_start(ap,ignored);
 Small b=va_arg(ap,Small); uint64_t v=va_arg(ap,uint64_t); va_end(ap);
 return b.x+v;
}
int main(void) {
 if(reuse()!=1 || distinct()!=33 || padding()!=49) return 1;
 Big b=environment(17); if(b.x!=42 || b.y!=17 || b.z!=99) return 2;
 b=opaque_echo(b); if(b.x!=42 || b.y!=17 || b.z!=99) return 3;
#ifndef QBE_COMMON_ONLY
 if(aligned_tail((Aligned){1},3.5)!=3.5 || nested_tail((Nested){{{1},{2}}},7.5)!=7.5) return 4;
 if(varargs_big((Big){10,20,30})!=67 || varargs_small((Small){123})!=130) return 5;
 if(receive_varargs(1,(Small){123},(uint64_t)7)!=130 || model_varargs()!=130) return 6;
#endif
 return 0;
}
'''


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native: assert native_host()
    with tempfile.TemporaryDirectory(prefix='lcb-aggregate-edges-') as directory:
        work=Path(directory);src=work/'input.ssa';src.write_text(SOURCE)
        for name,wanted in [('reuse',1),('distinct',33),('padding',49),('model_varargs',130)]:
            assert int(run([LCB,'--eval',src,name]))==wanted
        reject([LCB,'--eval',src,'padding_bad'],'uninitialized')
        asm=work/'lean.s';run([LCB, '--target', 'aarch64-macos',src,'-o',asm])
        if native_host():
            cc=os.environ.get('LCB_CC','cc');c=work/'driver.c';c.write_text(C)
            exe=work/'lean';run([cc,c,asm,'-o',exe]);run([exe])
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qa=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qa,src])
            qe=work/'qbe';run([cc,'-DQBE_COMMON_ONLY',c,qa,'-o',qe]);run([qe])
            for case in ['qbe-padded-float-aggregate','qbe-aggregate-variadic','qbe-aggregate-tail-overread']:
                source=ROOT/'tests/regressions'/f'{case}.ssa'
                driver=source.with_suffix('.c')
                for label,backend in [('lean',LCB),('qbe',oracle/'qbe')]:
                    assembly=work/f'{case}-{label}.s'
                    command=[backend,source,'-o',assembly] if label=='lean' else [backend,'-t','arm64_apple','-o',assembly,source]
                    run(command)
                    executable=work/f'{case}-{label}'
                    run([cc,'-O0',driver,assembly,'-o',executable])
                    outcome=subprocess.run([executable],capture_output=True,timeout=120)
                    if label=='lean': assert outcome.returncode==0,(case,outcome.returncode,outcome.stderr)
                    else: assert outcome.returncode!=0,f'expected retained QBE discrepancy: {case}'

    print('aggregate edges: result-buffer reuse/lifetime, uninitialized padding, x8+x9 and opaque values passed; '+
          ('native Lean/C over-aligned floats and aggregate variadics passed; QBE common cases pass and three retained upstream discrepancies reproduce separately' if native_host() else 'native execution unmeasured'))


if __name__=='__main__':main()
