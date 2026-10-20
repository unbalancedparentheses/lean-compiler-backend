#!/usr/bin/env python3
"""Subword Apple ARM64 ABI, packed byte/halfword stacks and signed/unsigned results."""
import argparse
import os
from pathlib import Path
import random
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

MASK=(1<<64)-1
NARROW=['sb','ub','sh','uh']
CT={'sb':'int8_t','ub':'uint8_t','sh':'int16_t','uh':'uint16_t','w':'uint32_t','l':'uint64_t','s':'float','d':'double'}
WIDTH={k:('l' if k in ['l','d'] else 'w') for k in CT}
SIGNATURES=[NARROW*2+[k] for k in NARROW]+[(NARROW+['s','d','w','l'])*8 for _ in NARROW]


def raw(k,seed,i):
    x=(seed+(i+1)*0x9e3779b97f4a7c15)&MASK
    if WIDTH[k]=='w':x&=0xffffffff
    if k=='s':x=(x&0x7fffff)|0x3f800000
    if k=='d':x=(x&0xfffffffffffff)|0x3ff0000000000000
    return x


def narrow(k,x):
    bits=8 if k in ['sb','ub'] else 16;x&=(1<<bits)-1
    if k[0]=='s' and x>=(1<<(bits-1)):x-=1<<bits
    return x&MASK


def expected(kinds,result,seed):
    h=0
    for i,k in enumerate(kinds):
        x=raw(k,seed,i)
        if k in NARROW:x=narrow(k,x)
        h=((h^x)*131)&MASK
    return narrow(result,h)


def fixture():
    out=[]
    for n,kinds in enumerate(SIGNATURES):
        result=NARROW[n%4];params=','.join(f'{k} %a{i}' for i,k in enumerate(kinds))
        body=f'export function {result} $small_target_{n}({params}) {{\n@entry\n %h0 =l copy 0\n'
        for i,k in enumerate(kinds):
            x=f'%a{i}'
            if k in ['s','d']:body+=f' %bits{i} ={WIDTH[k]} cast {x}\n';x=f'%bits{i}'
            if k in NARROW:body+=f' %wide{i} =l ext{k} {x}\n';x=f'%wide{i}'
            elif WIDTH[k]=='w':body+=f' %wide{i} =l extuw {x}\n';x=f'%wide{i}'
            body+=f' %x{i} =l xor %h{i}, {x}\n %h{i+1} =l mul %x{i}, 131\n'
        body+=f' ret %h{len(kinds)}\n}}\n';out.append(body)
        for mode in ['direct','indirect','external','callback']:
            body=f'export function l $small_{mode}_{n}('+('l %fn,' if mode=='callback' else '')+'l %seed) {\n@entry\n'
            body+=' %small =l and %seed, 31\n %size =l add %small, 16\n %p =l alloc16 %size\n'
            args=[]
            for i,k in enumerate(kinds):
                w=WIDTH[k];body+=f' %raw{i} ={w} add %seed, {((i+1)*0x9e3779b97f4a7c15)&MASK}\n';x=f'%raw{i}'
                if k in ['s','d']:
                    m,o=(0x7fffff,0x3f800000) if k=='s' else (0xfffffffffffff,0x3ff0000000000000)
                    body+=f' %m{i} ={w} and {x}, {m}\n %o{i} ={w} or %m{i}, {o}\n %f{i} ={k} cast %o{i}\n';x=f'%f{i}'
                args.append(f'{k} {x}')
            target=f'$small_target_{n}'
            if mode=='indirect':body+=f' %fn =l copy {target}\n';target='%fn'
            if mode=='external':target=f'$c_small_{n}'
            if mode=='callback':target='%fn'
            body+=f' %r ={result} call {target}('+','.join(args)+f')\n %wide =l ext{result} %r\n ret %wide\n}}\n';out.append(body)
    params=','.join(f'w %a{i}' for i in range(8))
    out.append(f'export function l $small_va({params},sb %last,...) {{\n@entry\n'+''' %ap =l alloc8 8
 vastart %ap
 %x =w vaarg %ap
 %y =l vaarg %ap
 %z =d vaarg %ap
 %zb =l cast %z
 %wide =l extsb %last
 %xwide =l extuw %x
 %sum =l add %wide, %xwide
 %sum =l add %sum, %y
 %sum =l xor %sum, %zb
 ret %sum
}
export function l $small_va_wrapper() {
@entry
 %r =l call $small_va(w 0,w 0,w 0,w 0,w 0,w 0,w 0,w 0,sb 128,...,ub 255,l 12345,d d_1.5)
 ret %r
}
''')
    return ''.join(out)


def caller(seeds):
    text='#include <stdint.h>\n#include <string.h>\n'
    for k in ['s','d']:
        integer=CT[WIDTH[k]]
        text+=f'static {CT[k]} make_{k}(uint64_t v) {{ {integer} b=v; {CT[k]} r; memcpy(&r,&b,sizeof r); return r; }}\n'
        text+=f'static uint64_t bits_{k}({CT[k]} v) {{ {integer} b; memcpy(&b,&v,sizeof b); return b; }}\n'
    for n,kinds in enumerate(SIGNATURES):
        result=NARROW[n%4];params=','.join(f'{CT[k]} a{i}' for i,k in enumerate(kinds))
        text+=f'extern {CT[result]} small_target_{n}({params});\nextern uint64_t small_direct_{n}(uint64_t),small_indirect_{n}(uint64_t),small_external_{n}(uint64_t),small_callback_{n}(uintptr_t,uint64_t);\n'
        text+=f'{CT[result]} c_small_{n}({params}) {{ uint64_t h=0;\n'
        for i,k in enumerate(kinds):
            x=f'bits_{k}(a{i})' if k in ['s','d'] else f'(uint64_t)a{i}'
            text+=f'h=(h^{x})*131;\n'
        text+=f'return ({CT[result]})h; }}\n'
    text+='extern uint64_t small_va(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,int8_t,...),small_va_wrapper(void);\n'
    text+='int main(void) {\n'
    wanted=(127+12345)^0x3ff8000000000000
    text+=f'if(small_va(0,0,0,0,0,0,0,0,-128,255,UINT64_C(12345),1.5)!=UINT64_C({wanted}) || small_va_wrapper()!=UINT64_C({wanted})) return 4;\n'
    for n,kinds in enumerate(SIGNATURES):
        for seed in seeds:
            wanted=expected(kinds,NARROW[n%4],seed);args=[]
            for i,k in enumerate(kinds):
                x=f'UINT64_C({raw(k,seed,i)})';args.append(f'make_{k}({x})' if k in ['s','d'] else f'({CT[k]}){x}')
            text+=f'if((uint64_t)small_target_{n}('+','.join(args)+f')!=UINT64_C({wanted})) return 1;\n'
            for mode in ['direct','indirect','external']:text+=f'if(small_{mode}_{n}(UINT64_C({seed}))!=UINT64_C({wanted})) return 2;\n'
            text+=f'if(small_callback_{n}((uintptr_t)c_small_{n},UINT64_C({seed}))!=UINT64_C({wanted})) return 3;\n'
    return text+'return 0;}\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--require-native',action='store_true');parser.add_argument('--seed',type=int,default=20261020);options=parser.parse_args()
    if options.require_native:assert native_host()
    rng=random.Random(options.seed);seeds=[0,1,MASK,1<<63]+[rng.getrandbits(64) for _ in range(4)];cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-subword-') as directory:
        work=Path(directory);src=work/'input.ssa';asm=work/'lean.s';c=work/'caller.c';src.write_text(fixture());c.write_text(caller(seeds));run([LCB,src,'-o',asm])
        assert int(run([LCB,'--eval',src,'small_va_wrapper']))==((127+12345)^0x3ff8000000000000)
        count=1
        for n,kinds in enumerate(SIGNATURES):
            for seed in seeds:
                wanted=expected(kinds,NARROW[n%4],seed)
                # ABI result has base type w; explicit extension exposes its signed value.
                actual=int(run([LCB,'--eval',src,f'small_target_{n}',*[raw(k,seed,i) for i,k in enumerate(kinds)]]))
                assert actual==(wanted&0xffffffff);count+=1
                for mode in ['direct','indirect']:
                    assert int(run([LCB,'--eval',src,f'small_{mode}_{n}',seed]))==wanted;count+=1
        for i,text in enumerate([
            'function w $f() { @s %x =sb add 1, 2 ret %x }',
            'function sb $f(sb %a) { @s ret %a } function w $g() { @s %r =w call $f(sb 1) ret %r }',
            'function sb $f(sb %a) { @s ret %a } function sb $g() { @s %r =sb call $f(ub 1) ret %r }',
        ]):
            bad=work/f'bad{i}.ssa';bad.write_text(text);reject([LCB,'--check',bad],'')
        restricted=work/'restricted.ssa';restricted.write_text('function sb $f(sb %a) { @s ret %a }');reject([LCB,'--first-path',restricted],'subword')
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,src])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label;run([cc,'-O2',c,assembly,'-o',exe]);run([exe])
            damaged=work/'damaged.s';damaged.write_text(asm.read_text().replace('strb w9, [sp','strb wzr, [sp'));run([cc,'-O2',c,damaged,'-o',work/'damaged']);reject([work/'damaged'],'')
        print(f'subword ABI: 8 signatures through 64 mixed arguments, {count} interpreter calls; '+('native Lean/QBE/C both directions, callbacks, packed stacks and corruption passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__':main()
