#!/usr/bin/env python3
"""Mixed scalar Apple ARM64 ABI: independent GP/FP banks, packed stack and returns."""
import argparse
import os
from pathlib import Path
import random
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

MASK=(1<<64)-1
SIGNATURES=[['s'],['d'],['s','w']*7,['l','d']*8,['s','d','w','l']*5,
            ['s']*9+['l']*9,['w']*9+['d']*9,['s','d','w','l']*16]
CT={'s':'float','d':'double','w':'uint32_t','l':'uint64_t'}
WIDTH={'s':'w','d':'l','w':'w','l':'l'}


def value(kind,seed,i):
    v=(seed+(i+1)*0x9e3779b97f4a7c15)&MASK
    if kind in ['s','w']: v&=0xffffffff
    if kind=='s': v=(v&0x7fffff)|0x3f800000
    if kind=='d': v=(v&0xfffffffffffff)|0x3ff0000000000000
    return v


def expected(kinds,seed,result):
    h=0
    for i,k in enumerate(kinds): h=((h^value(k,seed,i))*131)&MASK
    return (h&(0x7fffff if result=='s' else 0xfffffffffffff))|(0x3f800000 if result=='s' else 0x3ff0000000000000)


def source():
    out=[]
    for n,kinds in enumerate(SIGNATURES):
        result='s' if n%2==0 else 'd'; rw=WIDTH[result]
        params=','.join(f'{k} %a{i}' for i,k in enumerate(kinds))
        body=f'export function {result} $target_{n}({params}) {{\n@entry\n %h0 =l copy 0\n'
        for i,k in enumerate(kinds):
            v=f'%a{i}'
            if k in ['s','d']:
                body+=f' %b{i} ={WIDTH[k]} cast {v}\n';v=f'%b{i}'
            if WIDTH[k]=='w': body+=f' %wide{i} =l extuw {v}\n';v=f'%wide{i}'
            body+=f' %x{i} =l xor %h{i}, {v}\n %h{i+1} =l mul %x{i}, 131\n'
        mask,one=(0x7fffff,0x3f800000) if result=='s' else (0xfffffffffffff,0x3ff0000000000000)
        body+=f' %masked ={rw} and %h{len(kinds)}, {mask}\n %bits ={rw} or %masked, {one}\n %r ={result} cast %bits\n ret %r\n}}\n'
        out.append(body)
        for mode in ['direct','indirect','external','callback']:
            body=f'export function l ${mode}_{n}('+('l %fn,' if mode=='callback' else '')+'l %seed) {\n@entry\n'
            body+=' %small =l and %seed, 31\n %size =l add %small, 16\n %allocation =l alloc16 %size\n'
            args=[]
            for i,k in enumerate(kinds):
                w=WIDTH[k];body+=f' %raw{i} ={w} add %seed, {((i+1)*0x9e3779b97f4a7c15)&MASK}\n'
                v=f'%raw{i}'
                if k in ['s','d']:
                    m,o=(0x7fffff,0x3f800000) if k=='s' else (0xfffffffffffff,0x3ff0000000000000)
                    body+=f' %m{i} ={w} and {v}, {m}\n %o{i} ={w} or %m{i}, {o}\n %f{i} ={k} cast %o{i}\n';v=f'%f{i}'
                args.append(f'{k} {v}')
            target=f'$target_{n}'
            if mode=='indirect': body+=f' %fn =l copy {target}\n';target='%fn'
            if mode=='external': target=f'$c_target_{n}'
            if mode=='callback': target='%fn'
            body+=f' %r ={result} call {target}('+','.join(args)+f')\n %bits ={rw} cast %r\n'
            if rw=='w': body+=' %wide =l extuw %bits\n ret %wide\n}\n'
            else: body+=' ret %bits\n}\n'
            out.append(body)
    return ''.join(out)


def caller(seeds):
    text='#include <stdint.h>\n#include <string.h>\n#include <stdio.h>\n'
    for k in ['s','d']:
        integer=CT[WIDTH[k]]
        text+=f'static {CT[k]} make_{k}(uint64_t v) {{ {integer} b=v; {CT[k]} r; memcpy(&r,&b,sizeof r); return r; }}\n'
        text+=f'static uint64_t bits_{k}({CT[k]} v) {{ {integer} b; memcpy(&b,&v,sizeof b); return b; }}\n'
    for n,kinds in enumerate(SIGNATURES):
        result='s' if n%2==0 else 'd'
        params=','.join(f'{CT[k]} a{i}' for i,k in enumerate(kinds))
        text+=f'extern {CT[result]} target_{n}({params});\n'
        text+=f'extern uint64_t direct_{n}(uint64_t),indirect_{n}(uint64_t),external_{n}(uint64_t),callback_{n}(uintptr_t,uint64_t);\n'
        text+=f'{CT[result]} c_target_{n}({params}) {{ uint64_t h=0;\n'
        for i,k in enumerate(kinds):
            v=f'bits_{k}(a{i})' if k in ['s','d'] else f'a{i}'
            text+=f'h=(h^{v})*131;\n'
        m,o=(0x7fffff,0x3f800000) if result=='s' else (0xfffffffffffff,0x3ff0000000000000)
        text+=f'return make_{result}((h&UINT64_C({m}))|UINT64_C({o})); }}\n'
    text+='int main(void) {\n'
    for n,kinds in enumerate(SIGNATURES):
        result='s' if n%2==0 else 'd'
        for seed in seeds:
            wanted=expected(kinds,seed,result)
            args=[]
            for i,k in enumerate(kinds):
                v=f'UINT64_C({value(k,seed,i)})'
                if k in ['s','d']: v=f'make_{k}({v})'
                args.append(v)
            text+=f'if(bits_{result}(target_{n}('+','.join(args)+f')) != UINT64_C({wanted})) return 1;\n'
            for mode in ['direct','indirect','external']:
                text+=f'if({mode}_{n}(UINT64_C({seed})) != UINT64_C({wanted})) return 2;\n'
            text+=f'if(callback_{n}((uintptr_t)c_target_{n},UINT64_C({seed})) != UINT64_C({wanted})) return 3;\n'
    return text+'puts("float ABI passed"); return 0; }\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true');parser.add_argument('--seed',type=int,default=20261020)
    options=parser.parse_args()
    if options.require_native: assert native_host()
    rng=random.Random(options.seed);seeds=[0,1,MASK,1<<63]+[rng.getrandbits(64) for _ in range(4)]
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-float-abi-') as directory:
        work=Path(directory);src=work/'input.ssa';asm=work/'lean.s';c=work/'caller.c'
        src.write_text(source());c.write_text(caller(seeds));run([LCB, '--target', 'aarch64-macos',src,'-o',asm])
        count=0
        for n,kinds in enumerate(SIGNATURES):
            result='s' if n%2==0 else 'd'
            for seed in seeds:
                wanted=expected(kinds,seed,result)
                args=[value(k,seed,i) for i,k in enumerate(kinds)]
                assert int(run([LCB,'--eval',src,f'target_{n}',*args]))==wanted;count+=1
                for mode in ['direct','indirect']:
                    assert int(run([LCB,'--eval',src,f'{mode}_{n}',seed]))==wanted;count+=1
        for i,text in enumerate([
            'function d $f(d %x) { @s ret %x } function l $g() { @s %r =l call $f(d d_1) ret %r }',
            'function d $f(d %x) { @s ret %x } function d $g() { @s %r =d call $f(l 1) ret %r }',
            'function d $f(d %x) { @s ret %x } function d $g() { @s %p =l copy $f %r =d call %p(l 1) ret %r }',
        ]):
            bad=work/f'bad{i}.ssa';bad.write_text(text)
            if i==2: reject([LCB,'--eval',bad,'g'],'signature')
            else: reject([LCB,'--check',bad],'type')
        restricted=work/'restricted.ssa';restricted.write_text('function d $f(d %a) { @s ret %a }')
        reject([LCB,'--first-path',restricted],'floating function signatures')
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,src])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label;run([cc,'-std=c11','-O2',c,assembly,'-o',exe]);run([exe])
            damaged=work/'damaged.s';damaged.write_text(asm.read_text().replace('fmov s0, w9','fmov s1, w9'))
            run([cc,'-O2',c,damaged,'-o',work/'damaged'])
            reject([work/'damaged'],'')
        print(f'float ABI: {len(SIGNATURES)} mixed signatures through 64 arguments, {count} interpreter calls; '+
              ('native Lean/QBE/C both directions, callbacks, dynamic frames and corruption passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__':main()
