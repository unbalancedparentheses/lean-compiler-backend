#!/usr/bin/env python3
"""Independent native tests for scalar stack promotion and conservative guards."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host


def fixture():
    source='''export function l $memory_loop(l %n,l %x) {
@s
 %sum =l alloc8 8
 %index =l alloc8 8
 storel %x,%sum
 storel 0,%index
 jmp @test
@test
 %i =l loadl %index
 %c =w cultl %i,%n
 jnz %c,@body,@done
@body
 %old =l loadl %sum
 %scaled =l mul %i,1234567
 %mixed =l xor %old,%scaled
 %odd =w and %i,1
 jnz %odd,@left,@right
@left
 %a =l add %mixed,97
 storel %a,%sum
 jmp @next
@right
 %b =l sub %mixed,13
 storel %b,%sum
 jmp @next
@next
 %j =l add %i,1
 storel %j,%index
 jmp @test
@done
 %r =l loadl %sum
 ret %r
}
export function l $escape(l %x) {
@s
 %p =l alloc8 8
 storel %x,%p
 call $update(l %p)
 %r =l loadl %p
 ret %r
}
export function l $partial(l %x) {
@s
 %p =l alloc8 8
 storel %x,%p
 storew 123,%p
 %r =l loadl %p
 ret %r
}
export function d $floating_memory(d %x,w %condition) {
@s
 %p =l alloc8 8
 jnz %condition,@left,@right
@left
 stored %x,%p
 jmp @join
@right
 stored d_2.5,%p
 jmp @join
@join
 %r =d loadd %p
 ret %r
}
export function l $mixed_bits(l %x) {
@s
 %p =l alloc8 8
 storel %x,%p
 %v =d loadd %p
 %r =l cast %v
 ret %r
}
'''
    caller='''#include <stdint.h>
extern uint64_t memory_loop(uint64_t,uint64_t),escape(uint64_t),partial(uint64_t),mixed_bits(uint64_t);
extern double floating_memory(double,unsigned);
void update(uint64_t *p) {*p = (*p ^ UINT64_C(0xf123456789abcdef))+123;}
int main(void) {
 for(unsigned n=0;n<64;n++)for(unsigned x=0;x<16;x++) {
  uint64_t expected=UINT64_C(0xf123456789abcdef)*x;
  uint64_t input=expected;
  for(uint64_t i=0;i<n;i++){expected^=i*1234567;expected+=(i&1)?97:-13ULL;}
  if(memory_loop(n,input)!=expected)return 1;
  uint64_t modified=input;update(&modified);if(escape(input)!=modified)return 2;
  if(partial(input)!=((input&UINT64_C(0xffffffff00000000))|123))return 3;
  if(mixed_bits(input)!=input)return 4;
 }
 if(floating_memory(-7.25,1)!=-7.25||floating_memory(-7.25,0)!=2.5)return 5;
 return 0;
}'''
    return source,caller


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'memory-promotion';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c'
    ir,c=fixture();source.write_text(ir);caller.write_text(c)
    for label,flags in [('baseline',[]),('optimized',['--optimize'])]:
        asm=case/(label+'.s');exe=case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
    print(f'{target}: scalar promotion: 1024 loop/branch cases, escaping/partial/mixed objects and FP branches; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-memory-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
