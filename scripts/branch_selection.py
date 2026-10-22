#!/usr/bin/env python3
"""Independent integer branch oracles for ARM64 flag-based compare selection."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
from fuzz import LCB, native_host

OPS=[('eq','==',False),('ne','!=',False),('slt','<',True),('sle','<=',True),('sgt','>',True),('sge','>=',True),('ult','<',False),('ule','<=',False),('ugt','>',False),('uge','>=',False)]
CONSTANTS=[None,0,1,-1,4095,4096,-4096,0x7fffffff,0x80000000,0x7fffffffffffffff,0x8000000000000000]


def inputs():
    ir=[];declarations=[];checks=[];names=[]
    for width,bits in [('w',32),('l',64)]:
        for op,relation,signed in OPS:
            for index,constant in enumerate(CONSTANTS):
                for variant in ['direct','shared','nonlast','earlier']:
                    name=f'branch_{width}_{op}_{index}_{variant}'
                    names.append(name)
                    rhs='%b' if constant is None else str(constant)
                    tail=' %extra =l xor %keep,17\n' if variant=='nonlast' else (' %extra =l ceql %keep,0\n' if variant=='earlier' else '')
                    yes='37';no='91'
                    if variant=='shared':
                        # The comparison remains live on an edge and must be materialized.
                        yes='%cmp';no='%cmp'
                    suffix=''' %result =l add %selected,%extra
 ret %result''' if variant in ['nonlast','earlier'] else ' ret %selected'
                    ir.append(f'''export function l ${name}({width} %a,{width} %b,l %keep) {{
@s
 %cmp =l c{op}{width} %a,{rhs}
{tail} jnz %cmp,@yes,@no
@yes
 jmp @join
@no
 jmp @join
@join
 %selected =l phi @yes {yes},@no {no}
{suffix}
}}
''')
                    declarations.append(f'extern uint64_t {name}(uint{bits}_t,uint{bits}_t,uint64_t);')
                    cast=f'int{bits}_t' if signed else f'uint{bits}_t'
                    right='b' if constant is None else f'UINT64_C({constant % (1<<64)})'
                    expr=f'(({cast})a {relation} ({cast}){right})'
                    expected=expr if variant=='shared' else f'({expr}?37:91)'
                    if variant=='nonlast':expected=f'({expected}+(keep^17))'
                    if variant=='earlier':expected=f'({expected}+(keep==0))'
                    checks.append(f'if({name}(a,b,keep)!=(uint64_t){expected})return 1;')
    # Keep every operand live after the branch to force base/operand stack homes.
    for width,bits in [('w',32),('l',64)]:
        for op,relation,signed in OPS:
            name=f'pressure_{width}_{op}'
            params=','.join(f'{width} %p{i}' for i in range(24))
            adds=[];last='%selected'
            for i in range(24):
                value=f'%v{i}';adds.append(f' {value} ={width} add {last},%p{i}');last=value
            ir.append(f'''export function {width} ${name}({params}) {{
@s
 %cmp =w c{op}{width} %p22,%p23
 jnz %cmp,@yes,@no
@yes
 jmp @join
@no
 jmp @join
@join
 %selected ={width} phi @yes 37,@no 91
'''+ '\n'.join(adds)+f'\n ret {last}\n}}\n')
            declarations.append(f'extern uint{bits}_t {name}('+','.join([f'uint{bits}_t']*24)+');')
            cast=f'int{bits}_t' if signed else f'uint{bits}_t'
            expr=f'(({cast})a {relation} ({cast})b)'
            args=','.join(['a']*23+['b'])
            checks.append(f'if({name}({args})!=(uint{bits}_t)(({expr}?37:91)+(uint{bits}_t)a*23+(uint{bits}_t)b))return 2;')
    caller='''#include <stdint.h>
'''+ '\n'.join(declarations)+'''
static const uint64_t values[]={0,1,2,4095,4096,4097,UINT64_C(0xffffffff),UINT64_C(0x80000000),UINT64_C(0x7fffffff),UINT64_C(0x7fffffffffffffff),UINT64_C(0x8000000000000000),UINT64_C(0xffffffffffffffff),UINT64_C(0xfffffffffffff000),UINT64_C(0x123456789abcdef0)};
int main(void){for(unsigned i=0;i<sizeof(values)/sizeof(*values);i++)for(unsigned j=0;j<sizeof(values)/sizeof(*values);j++){
uint64_t a=values[i],b=values[j],keep=a^b;
'''+ '\n'.join(checks)+'''\n}return 0;}\n'''
    return '\n'.join(ir),caller,len(checks)*14*14


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'branch-selection';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c'
    ir,c,count=inputs();source.write_text(ir);caller.write_text(c)
    obj=case/'caller.o'
    if execute:
        r=run([cc,'-O2','-c',caller,'-o',obj],True);assert r.returncode==0,r.stderr
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label
        r=run([compiler,source,'--target',target,*flags,'-o',asm]);assert r.returncode==0,r.stderr
        assembly=asm.read_text()
        if target.startswith('aarch64') and label=='allocated':
            for op in ['eq','ne','lt','le','gt','ge','lo','ls','hi','hs']:
                assert re.search(r'\tb\.'+op+r' ',assembly),op
            # Shared/non-last comparisons retain explicit boolean materialization.
            assert '\tcset ' in assembly and '\tcbz ' in assembly
        if execute:
            r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==0,(label,r.returncode,r.stderr)
            if target.startswith('aarch64') and label=='allocated':
                damaged=assembly.replace('\tb.ne ','\tb.eq ',1);assert damaged!=assembly
                bad,badexe=case/'inverted.s',case/'inverted';bad.write_text(damaged)
                r=run([cc,obj,bad,'-o',badexe],True);assert r.returncode==0,r.stderr
                r=run([badexe],True);assert r.returncode!=0,'inverted conditional branch escaped C oracle'
    print(f'{target}: integer branch selection: {count} independent cases per mode; ten predicates, both widths, constants, phi/shared/nonadjacent uses and pressure; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-branch-selection-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
