#!/usr/bin/env python3
"""Independent byte-level checks for ARM64/RV64 constant-offset memory selection."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
from fuzz import LCB, native_host

OFFSETS=[-2049,-2048,-2047,2047,2048,-257,-256,-255,-1,0,1,2,3,7,8,15,255,256,257,4095,4096,32760,32768]


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
            checks.append(f'''memcpy(expected,bytes,sizeof(bytes));memcpy(expected+4096+({offset}),&seed,{bits//8});
 {name}(p,seed);if(memcmp(bytes,expected,sizeof(bytes)))return 2;''')
    for width,integer,ctype in [('s','w','uint32_t'),('d','l','uint64_t')]:
        for index,offset in enumerate(OFFSETS):
            name=f'offset_float_{width}_{index}'
            source.append(f'''export function {integer} ${name}(l %p,{integer} %bits) {{
@s
 %v ={width} cast %bits
 %address =l add %p,{offset}
 store{width} %v,%address
 %q =l add %p,0
 %again =l add %q,{offset}
 %loaded ={width} load{width} %again
 %result ={integer} cast %loaded
 ret %result
}}
''')
            declarations.append(f'extern {ctype} {name}(void *,{ctype});')
            checks.append(f'''memcpy(expected,bytes,sizeof(bytes));memcpy(expected+4096+({offset}),&seed,sizeof({ctype}));
 if({name}(p,({ctype})seed)!=({ctype})seed)return 3;if(memcmp(bytes,expected,sizeof(bytes)))return 4;''')

    for count in [12,24]:
        for mode in ['load','store']:
            for offset in [-2048,-256,2047,32760]:
                name=f'offset_pressure_{count}_{mode}_{abs(offset)}'
                params=','.join(['l %p','l %value']+[f'l %x{i}' for i in range(count)])
                instructions=[f'%address =l add %p,{offset}']
                instructions.append('%loaded =l loadl %address' if mode=='load' else 'storel %value,%address')
                instructions.extend(['jmp @loop','@loop','%iteration =w phi @s 0,@loop %next','%total =l phi @s 0,@loop %newtotal'])
                previous='0'
                for i in range(count):
                    instructions.extend([f'%a{i} =l add %x{i},{i}',f'%b{i} =l xor %x{i},81985529216486895',
                        f'%c{i} =l xor %a{i},%b{i}',f'%sum{i} =l add {previous},%c{i}'])
                    previous=f'%sum{i}'
                instructions.extend([f'%newtotal =l add %total,{previous}','%next =w add %iteration,1','%more =w cultw %next,3','jnz %more,@loop,@done','@done'])
                instructions.append('%result =l add %newtotal,'+('%loaded' if mode=='load' else '%value'))
                instructions.append('%withPointer =l xor %result,%p')
                source.append('export function l $'+name+f'({params}) {{\n@s\n'+'\n'.join(instructions)+'\n ret %withPointer\n}\n')
                declarations.append(f'extern uint64_t {name}(void *,uint64_t,'+','.join(['uint64_t']*count)+');')
                values=','.join(f'seed+UINT64_C({i*17})' for i in range(count))
                expected='{uint64_t sum=0;for(unsigned j=0;j<COUNT;j++){uint64_t x=seed+j*UINT64_C(17);sum+=(x+j)^(x^UINT64_C(81985529216486895));}sum*=3;uint64_t memory;memcpy(&memory,p+(OFFSET),8);'
                expected=expected.replace('COUNT',str(count)).replace('OFFSET',str(offset))
                if mode=='store':
                    expected+=f'memcpy(expected,bytes,sizeof(bytes));memcpy(expected+4096+({offset}),&seed,8);'
                expected+=f'if({name}(p,seed,{values})!=((sum+'+('memory' if mode=='load' else 'seed')+')^(uintptr_t)p))return 10;'
                if mode=='store':expected+='if(memcmp(bytes,expected,sizeof(bytes)))return 11;'
                checks.append(expected+'}')
    source.append('''export function l $offset_phi(l %p,w %choice) {
@s
 %address =l add %p,16
 %v =l loadl %address
 jnz %choice,@left,@right
@left
 jmp @join
@right
 jmp @join
@join
 %out =l phi @left %address,@right %p
 ret %out
}
export function l $offset_separated(l %p,l %x) {
@s
 %address =l add %p,16
 %other =l add %x,1
 %loaded =l loadl %address
 %result =l add %other,%loaded
 ret %result
}
export function w $offset_wrapped(l %p) {
@s
 %address =l add %p,18446744073709551615
 %loaded =w loadub %address
 ret %loaded
}
''')
    declarations.extend(['extern uintptr_t offset_phi(void *,unsigned);','extern uint64_t offset_separated(void *,uint64_t);','extern uint32_t offset_wrapped(void *);'])
    checks.extend(['if(offset_phi(p,0)!=(uintptr_t)p||offset_phi(p,1)!=(uintptr_t)(p+16))return 12;',
        '{uint64_t v;memcpy(&v,p+16,8);if(offset_separated(p,seed)!=seed+1+v)return 13;}',
        'if(offset_wrapped(p)!=(unsigned char)p[-1])return 14;'])
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
 unsigned char bytes[40000],expected[40000];unsigned char *p=bytes+4096;
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
            assert re.search(r'\bldur x9, \[x9, #-256\]',output),'pressure fixture must exercise a spilled base and result'
            assert re.search(r'\bstur x10, \[x9, #-256\]',output),'pressure fixture must exercise spilled base and stored value'
        if target.startswith('riscv64') and label=='allocated':
            output=asm.read_text()
            def body(name):
                return output.split('\n'+name+':\n',1)[1].split('\n.size '+name+',',1)[0]
            for offset in [-2048,2047]:
                index=OFFSETS.index(offset)
                assert f'\tld t0, {offset}(t0)' in body(f'offset_load_l_l_{index}')
                assert f'\tsd t0, {offset}(t1)' in body(f'offset_store_l_{index}')
                for precision,load,store in [('s','lwu','sw'),('d','ld','sd')]:
                    selected=body(f'offset_float_{precision}_{index}')
                    assert f'\t{load} t0, {offset}(t0)' in selected
                    assert f'\t{store} t0, {offset}(t1)' in selected
            for offset in [-2049,2048]:
                assert '\tld t0, 0(t0)' in body(f'offset_load_l_l_{OFFSETS.index(offset)}')
            for name in ['offset_phi','offset_separated']:
                assert '\tld t0, 0(t0)' in body(name)
                assert '\tld t0, 16(t0)' not in body(name)
            for name in ['offset_shared','offset_value']:
                assert '\tsd t0, 0(t1)' in body(name)
                assert '\tsd t0, 16(t1)' not in body(name)
            assert '\tlbu t0, -1(t0)' in body('offset_wrapped')
            assert '\tld t0, -2048(t0)' in body('offset_pressure_24_load_2048')
            assert '\tsd t0, -2048(t1)' in body('offset_pressure_24_store_2048')
            normalized=body(f'offset_load_sw_w_{OFFSETS.index(-2048)}')
            assert '\tlw t0, -2048(t0)\n\tslli t0, t0, 32\n\tsrli t0, t0, 32' in normalized
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
            if target.startswith('aarch64') and label=='allocated':
                damaged,n=re.subn(r'(\bldur(?:sb|b|sh|h|sw)? [wx]\d+, \[x\d+, #)-256\]',r'\g<1>-255]',asm.read_text(),count=1)
                assert n==1
                bad,badexe=case/'wrong-offset.s',case/'wrong-offset';bad.write_text(damaged)
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'wrong memory offset escaped independent byte oracle'
            if target.startswith('riscv64') and label=='allocated':
                original=asm.read_text()
                damaged=original.replace('\tlb t0, -2048(t0)','\tlb t0, -2047(t0)',1)
                assert damaged!=original
                bad,badexe=case/'wrong-offset.s',case/'wrong-offset';bad.write_text(damaged)
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'wrong RV64 memory offset escaped byte oracle'
    print(f'{target}: constant-offset memory: {count} independent byte-level load/store/FP/shared-address checks per mode; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-address-selection-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
