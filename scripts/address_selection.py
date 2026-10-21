#!/usr/bin/env python3
"""Independent byte-level checks for ARM64 constant-offset memory selection."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
from fuzz import LCB, native_host

OFFSETS=[-257,-256,-255,-1,0,1,2,3,7,8,15,255,256,257,4095,4096,32760,32768]


def inputs():
    source,declarations,checks=[],[],[]
    for load,bits,signed in [('sb',8,True),('ub',8,False),('sh',16,True),('uh',16,False),
                             ('sw',32,True),('uw',32,False),('l',64,False)]:
        for width in (['w','l'] if bits<64 else ['l']):
            ctype='uint32_t' if width=='w' else 'uint64_t'
            narrow=f'int{bits}_t' if signed else f'uint{bits}_t'
            for index,offset in enumerate(OFFSETS):
                name=f'offset_load_{load}_{width}_{index}'
                source.append(f'''export function {width} ${name}(l %p) {{
@s
 %address =l add %p,{offset}
 %v ={width} load{load} %address
 ret %v
}}
''')
                declarations.append(f'extern {ctype} {name}(void *);')
                checks.append(f'''{{uint64_t bits=0;memcpy(&bits,p+({offset}),{bits//8});
 if({name}(p)!=({ctype})({narrow})bits)return 1;}}''')
    for store,bits in [('b',8),('h',16),('w',32),('l',64)]:
        for index,offset in enumerate(OFFSETS):
            name=f'offset_store_{store}_{index}'
            source.append(f'''export function ${name}(l %p,l %value) {{
@s
 %address =l add %p,{offset}
 store{store} %value,%address
 ret
}}
''')
            declarations.append(f'extern void {name}(void *,uint64_t);')
            checks.append(f'''memcpy(expected,bytes,sizeof(bytes));memcpy(expected+512+({offset}),&seed,{bits//8});
 {name}(p,seed);if(memcmp(bytes,expected,sizeof(bytes)))return 2;''')
    for width,integer,ctype in [('s','w','uint32_t'),('d','l','uint64_t')]:
        for index,offset in enumerate(OFFSETS):
            name=f'offset_float_{width}_{index}'
            source.append(f'''export function {integer} ${name}(l %p,{integer} %bits) {{
@s
 %v ={width} cast %bits
 %address =l add %p,{offset}
 store{width} %v,%address
 %q =l sub %address,{offset}
 %again =l add %q,{offset}
 %loaded ={width} load{width} %again
 %result ={integer} cast %loaded
 ret %result
}}
''')
            declarations.append(f'extern {ctype} {name}(void *,{ctype});')
            checks.append(f'''memcpy(expected,bytes,sizeof(bytes));memcpy(expected+512+({offset}),&seed,sizeof({ctype}));
 if({name}(p,({ctype})seed)!=({ctype})seed)return 3;if(memcmp(bytes,expected,sizeof(bytes)))return 4;''')
    source.append('''export function l $offset_shared(l %p,l %value) {
@s
 %address =l add %p,16
 storel %value,%address
 ret %address
}
export function l $offset_value(l %p) {
@s
 %address =l add %p,16
 storel %address,%address
 ret %address
}
export function l $offset_commuted(l %p) {
@s
 %address =l add 8,%p
 %v =l loadl %address
 ret %v
}
export function l $offset_sub(l %p) {
@s
 %address =l sub %p,8
 %v =l loadl %address
 ret %v
}
''')
    declarations.extend(['extern uintptr_t offset_shared(void *,uint64_t),offset_value(void *);',
                         'extern uint64_t offset_commuted(void *),offset_sub(void *);'])
    checks.extend(['if(offset_shared(p,seed)!=(uintptr_t)(p+16))return 5;',
        'if(offset_value(p)!=(uintptr_t)(p+16))return 6;{uintptr_t v;memcpy(&v,p+16,8);if(v!=(uintptr_t)(p+16))return 7;}',
        '{uint64_t v;memcpy(&v,p+8,8);if(offset_commuted(p)!=v)return 8;memcpy(&v,p-8,8);if(offset_sub(p)!=v)return 9;}'])
    caller='''#include <stdint.h>
#include <string.h>
'''+ '\n'.join(declarations)+'''
int main(void){
 unsigned char bytes[34000],expected[34000];unsigned char *p=bytes+512;
 uint64_t seed=UINT64_C(0x89abcdef01234567);
 for(unsigned i=0;i<32;i++){
  for(unsigned j=0;j<sizeof(bytes);j++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;bytes[j]=(unsigned char)seed;}
'''+ '\n'.join(checks)+'''
 }return 0;
}
'''
    return '\n'.join(source),caller,len(checks)*32


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'address-selection';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c'
    ir,c,count=inputs();source.write_text(ir);caller.write_text(c)
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if target.startswith('aarch64') and flags:
            output=asm.read_text()
            assert re.search(r'\bldur(?:sb|b|sh|h|sw)? [wx]\d+, \[x\d+, #-256\]',output)
            assert re.search(r'\bldr x\d+, \[x\d+, #32760\]',output)
            assert re.search(r'\bstrb w\d+, \[x\d+, #4095\]',output)
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
            if target.startswith('aarch64') and label=='allocated':
                damaged,n=re.subn(r'(\bldur(?:sb|b|sh|h|sw)? [wx]\d+, \[x\d+, #)-256\]',r'\g<1>-255]',asm.read_text(),count=1)
                assert n==1
                bad,badexe=case/'wrong-offset.s',case/'wrong-offset';bad.write_text(damaged)
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'wrong memory offset escaped independent byte oracle'
    print(f'{target}: constant-offset memory: {count} independent byte-level load/store/FP/shared-address checks per mode; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-address-selection-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
