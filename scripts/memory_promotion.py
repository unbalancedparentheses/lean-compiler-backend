#!/usr/bin/env python3
"""Independent native tests for scalar stack promotion and conservative guards."""
import argparse
import os
import re
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
    declarations, checks = [], []
    for suffix, bits in [('b',8),('h',16)]:
        name='narrow_'+suffix
        source += f'''export function l ${name}(l %input,w %n) {{
@s
 %p =l alloc4 {bits//8}
 store{suffix} %input,%p
 jmp @test
@test
 %i =w phi @s 0,@body %next
 %more =w cultw %i,%n
 jnz %more,@body,@done
@body
 %u =w loadu{suffix} %p
 %s =w loads{suffix} %p
 %a =w mul %s,33
 %b =w add %a,%u
 %c =w add %b,%i
 store{suffix} %c,%p
 %next =w add %i,1
 jmp @test
@done
 %unsigned =l loadu{suffix} %p
 %signed =w loads{suffix} %p
 %wide =l extuw %signed
 %high =l shl %wide,32
 %r =l or %high,%unsigned
 ret %r
}}
'''
        declarations.append(f'extern uint64_t {name}(uint64_t,unsigned);')
        checks.append(f'''for(unsigned n=0;n<33;n++)for(unsigned k=0;k<256;k++){{
 uint64_t input=UINT64_C(0xf123456789abcdef)*k;
 uint32_t value=input&{(1<<bits)-1};
 for(unsigned i=0;i<n;i++){{
  int32_t signed_value=value<{1<<(bits-1)}?(int32_t)value:(int32_t)value-{1<<bits};
  value=((uint32_t)signed_value*33+value+i)&{(1<<bits)-1};
 }}
 int32_t signed_value=value<{1<<(bits-1)}?(int32_t)value:(int32_t)value-{1<<bits};
 uint64_t expected=((uint64_t)(uint32_t)signed_value<<32)|value;
 if({name}(input,n)!=expected)return {6+bits};
}}
''')
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
    caller=caller.replace("int main(void)","\n".join(declarations)+"\nint main(void)")
    caller=caller.replace(" return 0;","\n".join(checks)+" return 0;")
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
            if label=='optimized' and target.startswith('aarch64'):
                text=asm.read_text();prefix='_' if target.endswith('macos') else ''
                start=text.index('\n'+prefix+'narrow_b:\n')
                end=text.index('\n'+prefix+'narrow_h:\n',start)
                matches=list(re.finditer(r'\bsxtb (w\d+), (w\d+)',text[start:end]))
                assert matches,'narrow result lacks signed-byte extension'
                match=matches[-1]
                offset=start+match.start()
                damaged=text[:offset]+'uxtb'+text[offset+4:]
                bad=case/'broken-signedness.s';bad.write_text(damaged)
                badexe=case/'broken-signedness'
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'wrong narrow signedness escaped the independent oracle'
    print(f'{target}: scalar promotion: 1024 scalar and 16896 narrow loop cases, signed/unsigned loads, escaping/partial/mixed objects and FP branches; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-memory-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
