#!/usr/bin/env python3
"""Mutable QBE temporaries: loops/joins compared with independent Python and QBE."""
import argparse
import os
from pathlib import Path
import random
import shutil
import struct
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

MASK=(1<<64)-1


def generate(seed):
    rng=random.Random(seed);sources=[];models=[]
    for index in range(16):
        initial_a,initial_b,multiplier=[rng.randrange(1,1000) for _ in range(3)]
        sources.append(f'''export function l $mutable_{index}(l %seed,w %limit) {{
@entry
 %lcb.ssa.0 =l copy %seed
 %x =l copy %lcb.ssa.0
 %a =l copy {initial_a}
 %b =l copy {initial_b}
 %i =w copy 0
 jnz %limit, @loop, @done
@loop
 %x =l mul %x, {multiplier}
 %flag =w and %i, 1
 jnz %flag, @odd, @even
@even
 %a =l add %a, %x
 %b =l xor %b, %a
 jmp @join
@odd
 %b =l add %b, %x
 %a =l xor %a, %b
@join
 %tmp =l copy %a
 %a =l copy %b
 %b =l copy %tmp
 %i =w add %i, 1
 %continue =w cultw %i, %limit
 jnz %continue, @loop, @done
@done
 %r =l xor %a, %b
 %r =l add %r, %x
 ret %r
}}
''')
        models.append((initial_a,initial_b,multiplier))
    sources.append('''export function w $explicit_phi(w %n) {
@entry
 %x =w copy 0
 jnz %n, @loop, @done
@loop
 %i =w phi @entry 0, @loop %next
 %x =w add %x, %i
 %next =w add %i, 1
 %c =w cultw %next, %n
 jnz %c, @loop, @done
@done
 ret %x
}
export function l $parameter(l %x) {
@entry
 %x =l add %x, 5
 %x =l mul %x, 3
 ret %x
}
''')
    for kind,width in [('s','w'),('d','l')]:
        sources.append(f'''export function l $floating_{kind}(w %n) {{
@entry
 %x ={kind} copy {kind}_0.25
 %i =w copy 0
 jnz %n, @loop, @done
@loop
 %x ={kind} add %x, {kind}_1.25
 %x ={kind} mul %x, {kind}_1.5
 %i =w add %i, 1
 %c =w cultw %i, %n
 jnz %c, @loop, @done
@done
 %bits ={width} cast %x
'''+(' %wide =l extuw %bits\n ret %wide\n}\n' if width=='w' else ' ret %bits\n}\n'))
    sources.append('''export function l $irreducible(l %x,w %limit) {
@entry
 %n =w and %limit, 31
 %n =w add %n, 1
 %flag =w and %x, 1
 jnz %flag, @a, @b
@a
 %x =l add %x, 3
 %n =w sub %n, 1
 jnz %n, @b, @done
@b
 %x =l mul %x, 5
 %n =w sub %n, 1
 jnz %n, @a, @done
@done
 ret %x
}
''')
    sources.append('''export function l $loop_livein(l %x,l %y) {
@start
 jmp @entry
@entry
 %condition =w copy 1
 jnz %condition, @live, @dead1
@live
 %v =l add %x, %y
 ret %v
@dead1
 %v =l add %x, %y
 jmp @dead2
@dead2
 jnz %condition, @live, @dead1
}
''')
    return ''.join(sources),models


def reference(model,seed,limit):
    a,b,multiplier=model;x=seed
    for i in range(limit):
        x=(x*multiplier)&MASK
        if i&1:b=(b+x)&MASK;a^=b
        else:a=(a+x)&MASK;b^=a
        a,b=b,a
    return ((a^b)+x)&MASK


def float_reference(kind,n):
    fmt='<f' if kind=='s' else '<d'
    rounded=lambda x:struct.unpack(fmt,struct.pack(fmt,x))[0]
    x=0.25
    for _ in range(n):x=rounded(rounded(x+1.25)*1.5)
    return int.from_bytes(struct.pack(fmt,x),'little')


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--require-native',action='store_true');parser.add_argument('--seed',type=int,default=20261020);options=parser.parse_args()
    if options.require_native:assert native_host()
    rng=random.Random(options.seed);seeds=[0,1,MASK,1<<63]+[rng.getrandbits(64) for _ in range(4)]
    source,models=generate(options.seed);cases=[]
    for index,model in enumerate(models):
        for seed in seeds:
            limit=rng.choice([0,1,2,3,8,17,31]);cases.append((f'mutable_{index}',[seed,limit],reference(model,seed,limit)))
    for n in [0,1,2,3,8,17,31]:
        cases.append(('explicit_phi',[n],n*(n-1)//2))
        for kind in ['s','d']:cases.append((f'floating_{kind}',[n],float_reference(kind,n)))
    for seed in seeds:cases.append(('parameter',[seed],((seed+5)*3)&MASK))
    for seed in seeds:
        for limit in [0,1,7,31]:
            x=seed;at_a=bool(seed&1)
            for _ in range((limit&31)+1):
                x=((x+3) if at_a else x*5)&MASK;at_a=not at_a
            cases.append(('irreducible',[seed,limit],x))
    for seed in seeds:cases.append(('loop_livein',[seed,17],(seed+17)&MASK))
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-ssa-') as directory:
        work=Path(directory);src=work/'input.ssa';asm=work/'lean.s';c=work/'caller.c';src.write_text(source)
        run([LCB, '--target', 'aarch64-macos',src,'-o',asm]);first=asm.read_text();run([LCB, '--target', 'aarch64-macos',src,'-o',asm]);assert first==asm.read_text(),'unstable SSA names'
        for name,args,wanted in cases:assert int(run([LCB,'--eval',src,name,*args]))==wanted,(name,args,wanted)
        decl=''.join(f'extern uint64_t mutable_{i}(uint64_t,uint32_t);\n' for i in range(len(models)))
        decl+='extern uint64_t irreducible(uint64_t,uint32_t),loop_livein(uint64_t,uint64_t);\n'
        decl+='extern uint32_t explicit_phi(uint32_t);\nextern uint64_t parameter(uint64_t),floating_s(uint32_t),floating_d(uint32_t);\n'
        checks=''
        for name,args,wanted in cases:checks+=f'if({name}('+','.join(f'UINT64_C({x})' for x in args)+f')!=UINT64_C({wanted})) return 1;\n'
        c.write_text('#include <stdint.h>\n'+decl+'int main(void) {\n'+checks+'return 0;}\n')
        reject([LCB,'--first-path',src],'duplicate SSA')
        for i,text in enumerate([
            'function w $f() { @s %x =w add %x, 1 %x =w copy 2 ret %x }',
            'function w $f(w %c) { @s jnz %c, @a, @b @a %x =w copy 1 %x =w add %x, 1 jmp @j @b jmp @j @j ret %x }',
            'function w $f(w %a,w %a) { @s %a =w copy 1 ret %a }',
            'function w $f() { @s %x =w copy 1 %x =s copy s_1 ret 0 }',
            'function w $f() { @s ret 0 @a %v =w add %x, 1 jmp @b @b jmp @a }',
        ]):
            bad=work/f'bad{i}.ssa';bad.write_text(text);reject([LCB,'--check',bad],'')
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,src])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label;run([cc,'-O2',c,assembly,'-o',exe]);run([exe])
            damaged=work/'damaged.s';damaged.write_text(asm.read_text().replace('mul x9, x9, x10','add x9, x9, x10'));run([cc,'-O2',c,damaged,'-o',work/'damaged']);reject([work/'damaged'],'')
        print(f'SSA construction: 22 functions, {len(cases)} Python/interpreter cases, deterministic renaming and admission controls; '+('native Lean/QBE and corruption passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__':main()
