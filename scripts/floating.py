#!/usr/bin/env python3
"""Floating SSA arithmetic/memory/phi: interpreter, C and native QBE comparisons.

Arithmetic NaNs are compared by classification; copy/cast/negation preserve bits.
The tested execution profile uses default IEEE rounding and nontrapping exceptions.
"""
import argparse
import os
from pathlib import Path
import random
import shutil
import struct
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

OPS = ['add', 'sub', 'mul', 'div', 'neg', 'copy', 'memory', 'phi',
       'eq', 'ne', 'le', 'lt', 'ge', 'gt', 'o', 'uo']


def fixture():
    definitions = []
    for kind, width in [('s','w'),('d','l')]:
        for op in OPS:
            name = f'{kind}_{op}'
            body = f'export function l ${name}(l %a,l %b,w %choose) {{\n@entry\n'
            body += f' %ab ={width} copy %a\n %bb ={width} copy %b\n %x ={kind} cast %ab\n %y ={kind} cast %bb\n'
            if op in ['add','sub','mul','div']:
                body += f' %r ={kind} {op} %x, %y\n'
            elif op in ['neg','copy']:
                body += f' %r ={kind} {op} %x\n'
            elif op == 'memory':
                body += f' %p =l alloc8 8\n store{kind} %x, %p\n %r ={kind} load{kind} %p\n'
            elif op == 'phi':
                body += f' jnz %choose, @yes, @no\n@yes\n jmp @join\n@no\n jmp @join\n@join\n %r ={kind} phi @yes %x, @no %y\n'
            else:
                body += f' %r =l c{op}{kind} %x, %y\n ret %r\n}}\n'
                definitions.append(body)
                continue
            body += f' %bits ={width} cast %r\n'
            if width == 'w': body += ' %wide =l extuw %bits\n ret %wide\n}\n'
            else: body += ' ret %bits\n}\n'
            definitions.append(body)
    return ''.join(definitions)


def matrix(seed):
    rng = random.Random(seed)
    result = []
    for kind, bits in [('s',32),('d',64)]:
        pack = '<f' if kind == 's' else '<d'
        patterns = [int.from_bytes(struct.pack(pack, x),'little') for x in
                    [0.,-0.,1.,-1.,0.1,2.,float('inf'),-float('inf'),float('nan')]]
        patterns += [1, (1 << (23 if bits == 32 else 52))-1,
                     0x7f7fffff if bits == 32 else 0x7fefffffffffffff,
                     0x7f800001 if bits == 32 else 0x7ff0000000000001]
        pairs = [(a,b) for a,b in zip(patterns, reversed(patterns))]
        pairs += [(patterns[8], patterns[2]), (patterns[2], patterns[8]), (patterns[0], patterns[1]),
                  (patterns[6], patterns[6]), (patterns[2], patterns[0])]
        pairs += [(rng.getrandbits(bits),rng.getrandbits(bits)) for _ in range(10)]
        for op in OPS:
            for i,(a,b) in enumerate(pairs): result.append((kind,op,a,b,i%2))
    return result


def c_source(cases, external):
    text = '#include <stdint.h>\n#include <stdio.h>\n#include <string.h>\n#include <math.h>\n'
    for kind in ['s','d']:
        for op in OPS:
            name = f'{kind}_{op}'
            if external:
                text += f'extern uint64_t {name}(uint64_t,uint64_t,uint32_t);\n'
                continue
            typ, integer = ('float','uint32_t') if kind == 's' else ('double','uint64_t')
            text += f'uint64_t {name}(uint64_t a,uint64_t b,uint32_t choose) {{ {integer} aa=a,bb=b,out; {typ} x,y,r; memcpy(&x,&aa,sizeof x); memcpy(&y,&bb,sizeof y);\n'
            if op in ['eq','ne','le','lt','ge','gt']:
                symbol = dict(eq='==',ne='!=',le='<=',lt='<',ge='>=',gt='>')[op]
                text += f'return x {symbol} y; }}\n'
            elif op in ['o','uo']:
                text += 'return '+('!' if op == 'o' else '')+'(isnan(x)||isnan(y)); }\n'
            elif op == 'neg':
                text += f'return aa ^ (UINT64_C(1) << {31 if kind == "s" else 63}); }}\n'
            else:
                expr = dict(add='x+y',sub='x-y',mul='x*y',div='x/y',copy='x',memory='x',phi='choose?x:y')[op]
                text += f'r={expr}; memcpy(&out,&r,sizeof r); return out; }}\n'
    text += 'int main(void) {\n'
    for kind,op,a,b,choose in cases:
        text += f'printf("%llu\\n",(unsigned long long){kind}_{op}(UINT64_C({a}),UINT64_C({b}),{choose}));\n'
    return text + 'return 0; }\n'


def equivalent(case, a, b):
    kind,op,*_ = case
    if op not in ['add','sub','mul','div']: return a == b
    exponent, fraction = (0x7f800000,0x7fffff) if kind == 's' else (0x7ff0000000000000,0xfffffffffffff)
    nan = lambda x: x & exponent == exponent and x & fraction != 0
    return a == b or (nan(a) and nan(b))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    parser.add_argument('--seed',type=int,default=20261020)
    options=parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    cases=matrix(options.seed)
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-floating-') as directory:
        work=Path(directory)
        source,asm,caller,reference=work/'input.ssa',work/'lean.s',work/'caller.c',work/'reference.c'
        source.write_text(fixture())
        run([LCB,source,'-o',asm])
        reference.write_text(c_source(cases,False));caller.write_text(c_source(cases,True))
        run([cc,'-std=c11','-O0','-ffp-contract=off',reference,'-o',work/'reference'])
        expected=[int(x) for x in run([work/'reference']).splitlines()]
        assert len(expected)==len(cases)
        for case,wanted in zip(cases,expected):
            kind,op,a,b,choose=case
            found=int(run([LCB,'--eval',source,f'{kind}_{op}',a,b,choose]))
            assert equivalent(case,found,wanted), (case,hex(found),hex(wanted),'interpreter')
        for i,text in enumerate([
            'function l $f() { @s %x =s copy s_1 %y =l add %x, 1 ret %y }',
            'function l $f() { @s %x =s copy s_1 %y =d add %x, d_1 ret 0 }',
            'function l $f() { @s %x =s and s_1, s_2 ret 0 }',
            'function l $f() { @s %x =s copy s_1 jnz %x, @a, @b @a ret 1 @b ret 0 }',
            'function l $f() { @s %x =s copy $bad ret 0 }',
        ]):
            bad=work/f'bad{i}.ssa';bad.write_text(text);reject([LCB,'--check',bad],'')
        restricted=work/'restricted.ssa'
        restricted.write_text('function l $f() { @s %x =d copy d_1 %r =l cast %x ret %r }')
        reject([LCB,'--first-path',restricted],'floating')
        if native_host():
            oracle=work/'qbe';shutil.copytree(ROOT/'third_party/qbe',oracle)
            run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,source])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/(label+'-exe');run([cc,'-O0',caller,assembly,'-o',exe])
                found=[int(x) for x in run([exe]).splitlines()]
                assert len(found)==len(expected)
                for case,a,b in zip(cases,found,expected): assert equivalent(case,a,b),(label,case,hex(a),hex(b))
            damaged=work/'damaged.s';damaged.write_text(asm.read_text().replace('fadd','fsub'))
            run([cc,'-O0',caller,damaged,'-o',work/'damaged'])
            found=[int(x) for x in run([work/'damaged']).splitlines()]
            assert any(not equivalent(c,a,b) for c,a,b in zip(cases,found,expected)), 'corruption escaped'
        print(f'floating: {len(cases)} C/interpreter cases; arithmetic, comparisons, casts, memory and phi; '+
              ('native Lean/QBE and arithmetic corruption passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__': main()
