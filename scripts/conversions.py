#!/usr/bin/env python3
"""All QBE scalar numeric conversions, with defined-range C/Lean/QBE comparisons."""
import argparse
import math
import os
from pathlib import Path
import random
import shutil
import struct
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

CT={'w':'uint32_t','l':'uint64_t','s':'float','d':'double'}
BW={'w':'w','l':'l','s':'w','d':'l'}
SPECS=[(op,out,inp,signed) for op,inp,signed in [('swtof','w',True),('uwtof','w',False),('sltof','l',True),('ultof','l',False)] for out in ['s','d']]
SPECS += [(op,out,inp,signed) for op,inp,signed in [('stosi','s',True),('stoui','s',False),('dtosi','d',True),('dtoui','d',False)] for out in ['w','l']]
SPECS += [('exts','d','s',False),('truncd','s','d',False)]


def bits(kind,x):
    try: return int.from_bytes(struct.pack('<f' if kind=='s' else '<d',float(x)),'little')
    except OverflowError: return int.from_bytes(struct.pack('<f',math.copysign(math.inf,x)),'little')


def value(kind,x):
    return struct.unpack('<f' if kind=='s' else '<d',x.to_bytes(4 if kind=='s' else 8,'little'))[0]


def cases(seed):
    rng=random.Random(seed);result=[]
    for index,(op,out,inp,signed) in enumerate(SPECS):
        if inp in ['w','l']:
            size=32 if inp=='w' else 64
            inputs=[0,1,2,3,(1<<size)-1,1<<(size-1),(1<<(size-1))-1]
            inputs += [((1<<n)+delta)% (1<<size) for n in [23,24,25,31,32,52,53,54,62,63] for delta in [-3,-1,0,1,3]]
            inputs += [rng.getrandbits(size) for _ in range(40)]
        elif out in ['w','l']:
            size=32 if out=='w' else 64
            lower=-(1<<(size-1)) if signed else 0;upper=(1<<(size-(1 if signed else 0)))-1
            numbers=[0.,-0.,0.75,-0.75,1.75,-1.75,100.,-100.,float(lower),float(upper)]
            for edge in [float(lower),float(upper),float(upper+1)]:
                numbers += [math.nextafter(edge,-math.inf),math.nextafter(edge,math.inf)]
            numbers += [rng.uniform(max(lower,-1e6),min(upper,1e6)) for _ in range(40)]
            inputs=[bits(inp,x) for x in numbers]
            inputs=[x for x in inputs if math.isfinite(value(inp,x)) and lower<=int(value(inp,x))<=upper]
        else:
            size=32 if inp=='s' else 64
            numbers=[0.,-0.,1.,-1.,math.inf,-math.inf,math.nan,0.1,1+2**-24,1+3*2**-24,
                     2**-149,2**-150,math.nextafter(2**-150,math.inf),2**-126,2**128,2**-1074]
            inputs=[bits(inp,x) for x in numbers]+[rng.getrandbits(size) for _ in range(80)]
        for x in dict.fromkeys(inputs):result.append((index,x))
    return result


def fixture():
    out=[]
    for index,(op,result,inp,_) in enumerate(SPECS):
        text=f'export function l $convert_{index}(l %a) {{\n@entry\n %raw ={BW[inp]} copy %a\n'
        source='%raw'
        if inp in ['s','d']:text+=f' %x ={inp} cast %raw\n';source='%x'
        text+=f' %r ={result} {op} {source}\n';source='%r'
        if result in ['s','d']:text+=f' %bits ={BW[result]} cast %r\n';source='%bits'
        if BW[result]=='w':text+=f' %wide =l extuw {source}\n';source='%wide'
        text+=f' ret {source}\n}}\n';out.append(text)
    return ''.join(out)


def c_source(matrix,external):
    text='#include <stdint.h>\n#include <string.h>\n#include <stdio.h>\n'
    for index,(op,out,inp,signed) in enumerate(SPECS):
        if external:text+=f'extern uint64_t convert_{index}(uint64_t);\n';continue
        text+=f'uint64_t convert_{index}(uint64_t a) {{ {CT[BW[inp]]} raw=a; {CT[inp]} x; memcpy(&x,&raw,sizeof x);\n'
        if inp in ['w','l'] and signed:
            st='int32_t' if inp=='w' else 'int64_t'
            text+=f'{st} sx; memcpy(&sx,&raw,sizeof sx); {CT[out]} r=({CT[out]})sx;\n'
        elif out in ['w','l'] and signed:
            st='int32_t' if out=='w' else 'int64_t';text+=f'{st} r=({st})x;\n'
        else:text+=f'{CT[out]} r=({CT[out]})x;\n'
        text+=f'{CT[BW[out]]} result; memcpy(&result,&r,sizeof r); return result; }}\n'
    text+='int main(void) {\n'
    for index,x in matrix:text+=f'printf("%llu\\n",(unsigned long long)convert_{index}(UINT64_C({x})));\n'
    return text+'return 0;}\n'


def equivalent(index,a,b):
    out=SPECS[index][1]
    if out in ['s','d']:
        exponent,fraction=(0x7f800000,0x7fffff) if out=='s' else (0x7ff0000000000000,0xfffffffffffff)
        nan=lambda x:x&exponent==exponent and x&fraction!=0
        if nan(a) and nan(b):return True
    return a==b


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--require-native',action='store_true');parser.add_argument('--seed',type=int,default=20261020);options=parser.parse_args()
    if options.require_native:assert native_host()
    matrix=cases(options.seed);cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-conversion-') as directory:
        work=Path(directory);src=work/'input.ssa';asm=work/'lean.s';c=work/'caller.c';ref=work/'reference.c'
        src.write_text(fixture());run([LCB,src,'-o',asm]);c.write_text(c_source(matrix,True));ref.write_text(c_source(matrix,False))
        run([cc,'-std=c11','-O0',ref,'-o',work/'reference']);expected=[int(x) for x in run([work/'reference']).splitlines()]
        for (index,x),wanted in zip(matrix,expected):
            found=int(run([LCB,'--eval',src,f'convert_{index}',x]))
            assert equivalent(index,found,wanted),(SPECS[index],hex(x),hex(found),hex(wanted),'interpreter')
        for op,out,inp,signed in SPECS:
            if out not in ['w','l']:continue
            index=SPECS.index((op,out,inp,signed));size=32 if out=='w' else 64
            for number in [math.inf,-math.inf,math.nan,float(1<<(size-(1 if signed else 0))),float(-(1<<size))]:
                reject([LCB,'--eval',src,f'convert_{index}',bits(inp,number)],'conversion; result not evaluated')
        for i,text in enumerate(['function s $f(s %a) { @s %r =s exts %a ret %r }',
                                 'function d $f(d %a) { @s %r =d truncd %a ret %r }',
                                 'function d $f(l %a) { @s %r =d dtosi %a ret %r }']):
            bad=work/f'bad{i}.ssa';bad.write_text(text);reject([LCB,'--check',bad],'')
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,src])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label;run([cc,'-O0',c,assembly,'-o',exe]);found=[int(x) for x in run([exe]).splitlines()]
                assert len(found)==len(expected)
                for (index,x),a,b in zip(matrix,found,expected):assert equivalent(index,a,b),(label,SPECS[index],hex(x),hex(a),hex(b))
            damaged=work/'damaged.s';damaged.write_text(asm.read_text().replace('scvtf','ucvtf'));run([cc,'-O0',c,damaged,'-o',work/'damaged'])
            found=[int(x) for x in run([work/'damaged']).splitlines()]
            assert any(not equivalent(i,a,b) for (i,_),a,b in zip(matrix,found,expected))
        print(f'conversions: {len(SPECS)} typed forms, {len(matrix)} C/interpreter cases, invalid-domain refusals; '+('native Lean/QBE and signedness corruption passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__':main()
