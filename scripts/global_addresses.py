#!/usr/bin/env python3
"""Independent checks for common module-data addresses without caching contents."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host

SOURCE='''export data $address_table = align 8 { l 5, l 7, l 11 }
export data $alternate_table = align 8 { l 13, l 17, l 19 }
export function l $address_roundtrip(l %value,w %choice) {
@s
 %first =l loadl $address_table
 call $mutate_address_table(l %value)
 %next =l loadl $address_table
 jnz %choice,@left,@right
@left
 %left =l add $address_table,8
 jmp @join
@right
 %right =l add $address_table,16
 jmp @join
@join
 %p =l phi @left %left,@right %right
 %last =l loadl %p
 %mixed =l xor %first,%next
 %r =l xor %mixed,%last
 ret %r
}
export function l $address_mix(w %choice) {
@s
 %word =w copy $address_table
 %plus =w add $address_table,17
 %mixed =w xor %word,%plus
 jnz %choice,@left,@right
@left
 jmp @join
@right
 jmp @join
@join
 %p =l phi @left $address_table,@right $alternate_table
 %wide =l extuw %mixed
 %r =l xor %p,%wide
 ret %r
}
export function l $address_loop(w %n) {
@s
 jmp @test
@test
 %i =w phi @s 0,@body %next
 %sum =l phi @s 0,@body %newsum
 %more =w cultw %i,%n
 jnz %more,@body,@done
@body
 %a =l loadl $address_table
 %p =l add $address_table,8
 %b =l loadl %p
 %q =l add $address_table,16
 %c =l loadl %q
 %ab =l add %a,%b
 %abc =l add %ab,%c
 %newsum =l add %sum,%abc
 %next =w add %i,1
 jmp @test
@done
 ret %sum
}
export function l $address_collision(l %lcb.symbol.0) {
@s
 %a =l loadl $address_table
 %b =l loadl $address_table
 %c =l loadl $address_table
 %ab =l add %a,%b
 %abc =l add %ab,%c
 %r =l add %abc,%lcb.symbol.0
 ret %r
}
'''
CALLER='''#include <stdint.h>
extern uint64_t address_table[3],alternate_table[3];
extern uint64_t address_roundtrip(uint64_t,unsigned),address_mix(unsigned),address_loop(unsigned),address_collision(uint64_t);
void mutate_address_table(uint64_t value){address_table[0]=value;address_table[1]=value^UINT64_C(0xf123456789abcdef);}
int main(void){
 uint64_t seed=UINT64_C(0xdeadbeef12345678);
 for(unsigned i=0;i<1024;i++){
  seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;
  for(unsigned choice=0;choice<2;choice++){
   uint64_t old=seed^UINT64_C(0x9876543210fedcba),tail=seed+123;
   address_table[0]=old;address_table[2]=tail;
   uint64_t expected=old^seed^(choice?(seed^UINT64_C(0xf123456789abcdef)):tail);
   if(address_roundtrip(seed,choice)!=expected)return 1;
   uint32_t low=(uint32_t)(uintptr_t)address_table;
   expected=(uintptr_t)(choice?address_table:alternate_table)^(uint64_t)(low^(uint32_t)(low+17));
   if(address_mix(choice)!=expected)return 2;
   if(address_loop(i%33)!=(address_table[0]+address_table[1]+address_table[2])*(i%33))return 3;
   if(address_collision(seed)!=3*address_table[0]+seed)return 4;
  }
 }
 return 0;
}
'''


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'global-addresses';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';source.write_text(SOURCE);caller.write_text(CALLER)
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
            if label=='optimized' and target.startswith('aarch64'):
                text=asm.read_text();lines=text.splitlines(keepends=True)
                damaged=''.join(line.replace('address_table','alternate_table') if line.startswith('\t') and 'address_table' in line and not 'mutate_address_table' in line else line for line in lines)
                assert damaged!=text
                bad=case/'wrong-address.s';bad.write_text(damaged);badexe=case/'wrong-address'
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'wrong shared address escaped the independent oracle'
    print(f'{target}: common global addresses: 8192 independent call/mutation, narrowing/phi, loop and naming-collision checks per mode; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-global-addresses-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
