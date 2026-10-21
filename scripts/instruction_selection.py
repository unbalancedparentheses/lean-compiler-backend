#!/usr/bin/env python3
"""Independent integer oracle for immediate selection and materialization fallbacks."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
from fuzz import LCB, native_host


def fixture():
    constants = [0, 1, -1, 4095, -4095, 4096, -4096, 4097, -4097,
                 4095*4096, -4095*4096, 4096*4096, -4096*4096,
                 (1<<31)-1, 1<<31, (1<<32)-1, 1<<32, (1<<32)+1,
                 (1<<63)-1, -(1<<63), (1<<64)-1]
    counts = [0, 1, 31, 32, 33, 63, 64, 65, -1, -32, -64,
              (1<<32)+1, (1<<63), (1<<64)-1]
    inputs = [0, 1, 4095, (1<<31), (1<<32)-1, (1<<63), (1<<64)-1, 0xfedcba9876543210]
    sources, declarations, checks = [], [], []
    for width, bits in [('w',32), ('l',64)]:
        mask = (1<<bits)-1
        logical=set()
        for element in [2,4,8,16,32,64]:
            if element>bits:continue
            for ones in [1,element//2,element-1]:
                for rotate in [0,1,element//2,element-1]:
                    value=(1<<ones)-1
                    value=((value>>rotate)|(value<<(element-rotate)))&((1<<element)-1)
                    logical.add(sum(value<<offset for offset in range(0,bits,element)))
        logical |= {value^1 for value in logical}
        for op in ['add','add_left','sub','shl','shr','sar','mul','mul_left','and','and_left','or','or_left','xor','xor_left']:
            algebra_constants = constants + [2, 4, 8, 1<<16, 1<<48, -(1<<31), -(1<<32), (1<<32)+1]
            if op.removesuffix('_left') in ['and','or','xor']:algebra_constants += sorted(logical)
            for value in counts if op in ['shl','shr','sar'] else algebra_constants:
                name = f'isel_{len(sources)}'
                actual_op = op.removesuffix('_left')
                operands = f'{value},%x' if op.endswith('_left') else f'%x,{value}'
                sources.append(f'export function {width} ${name}(l %x) {{\n@s\n %r ={width} {actual_op} {operands}\n ret %r\n}}\n')
                declarations.append(f'extern uint{bits}_t {name}(uint64_t);')
                for x in inputs:
                    a, b = x & mask, value & mask
                    if op.startswith('add'): result = a+b
                    elif op=='sub': result = a-b
                    elif op.startswith('mul'): result = a*b
                    elif op.startswith('and'): result = a&b
                    elif op.startswith('or'): result = a|b
                    elif op.startswith('xor'): result = a^b
                    elif op=='shl': result = a << (value%bits)
                    elif op=='shr': result = a >> (value%bits)
                    else: result = (a if a < 1<<(bits-1) else a-(1<<bits)) >> (value%bits)
                    result &= mask
                    checks.append(f'if({name}(UINT64_C({x}))!=UINT{bits}_C({result})){{fprintf(stderr,"case {len(checks)}\\n");return 1;}}')
    for width, bits in [('w',32), ('l',64)]:
        mask = (1<<bits)-1
        for result_width, result_bits in [('w',32), ('l',64)]:
            for predicate in ['eq','ne','slt','sle','sgt','sge','ult','ule','ugt','uge']:
                for reversed_operands in [False,True]:
                    for value in constants[:4] if reversed_operands else constants:
                        name = f'isel_{len(sources)}'
                        operands = f'{value},%x' if reversed_operands else f'%x,{value}'
                        sources.append(f'export function {result_width} ${name}(l %x) {{\n@s\n %r ={result_width} c{predicate}{width} {operands}\n ret %r\n}}\n')
                        declarations.append(f'extern uint{result_bits}_t {name}(uint64_t);')
                        for x in inputs:
                            a,b = (value&mask,x&mask) if reversed_operands else (x&mask,value&mask)
                            if predicate.startswith('s'):
                                a = a if a < 1<<(bits-1) else a-(1<<bits)
                                b = b if b < 1<<(bits-1) else b-(1<<bits)
                            kind = predicate if predicate in ['eq','ne'] else predicate[1:]
                            result = {'eq':a==b,'ne':a!=b,'lt':a<b,'le':a<=b,'gt':a>b,'ge':a>=b}[kind]
                            checks.append(f'if({name}(UINT64_C({x}))!=UINT{result_bits}_C({int(result)})){{fprintf(stderr,"case {len(checks)}\\n");return 1;}}')
    # XOR forces constant materialization instead of an add/compare immediate.
    materialized = constants + [1<<16,1<<32,1<<48,0xffff<<48,0xffffffffffff0000,
        0xffffffff0000ffff,0xffff0000ffffffff,0x1234000000000000,
        0x0000123400005678,0xffff1234ffff5678,0x8000000080000000]
    for width,bits in [('w',32),('l',64)]:
        for value in materialized:
            name = f'isel_{len(sources)}'
            sources.append(f'export function {width} ${name}(l %x) {{\n@s\n %r ={width} xor %x,{value}\n ret %r\n}}\n')
            declarations.append(f'extern uint{bits}_t {name}(uint64_t);')
            for x in inputs:
                result = (x ^ value) & ((1<<bits)-1)
                checks.append(f'if({name}(UINT64_C({x}))!=UINT{bits}_C({result})){{fprintf(stderr,"case {len(checks)}\\n");return 1;}}')
    caller = '#include <stdint.h>\n#include <stdio.h>\n'+'\n'.join(declarations)+'\nint main(void){\n'+'\n'.join(checks)+'\nreturn 0;\n}\n'
    return ''.join(sources), caller, len(sources), len(checks)


def exercise(compiler, work, run, cc, target, execute=True):
    case = Path(work)/'instruction-selection';case.mkdir(exist_ok=True)
    text, c, functions, count = fixture()
    source, caller = case/'input.ssa', case/'caller.c'
    source.write_text(text);caller.write_text(c)
    caller_object = case/'caller.o'
    if execute:
        result = run([cc,'-c',caller,'-o',caller_object],True);assert result.returncode==0,result.stderr
    for label, flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm, exe = case/(label+'.s'), case/label
        result = run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if target.startswith('aarch64') and flags:
            output = asm.read_text()
            assert re.search(r'\b(?:add|sub) [wx]\d+, [wx]\d+, #4095, lsl #12',output)
            assert re.search(r'\b(?:lsl|lsr|asr) [wx]\d+, [wx]\d+, #31',output)
            assert re.search(r'\bcmn [wx]\d+, #4095',output)
            assert re.search(r'\bmovn [wx]\d+, #',output)
            assert re.search(r'\band x\d+, x\d+, #6148914691236517205\b',output)
            assert re.search(r'\borr w\d+, w\d+, #1431655765\b',output)
            assert re.search(r'\bmovz x\d+, #1, lsl #48',output)
        if execute:
            result = run([cc,caller_object,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result = run([exe],True);assert result.returncode==0,(target,label,result.stderr)
        if execute and target.startswith('aarch64') and label=='allocated':
            damaged, n = re.subn(r'(\b(?:add|sub) [wx]\d+, [wx]\d+, )#4095\b',r'\g<1>#4094',asm.read_text(),count=1)
            assert n==1
            bad, badexe = case/'broken.s',case/'broken';bad.write_text(damaged)
            result = run([cc,caller_object,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
            result = run([badexe],True);assert result.returncode!=0,'wrong immediate escaped the independent oracle'
            damaged,n = re.subn(r'(\bcmp [wx]\d+, )#4095\b',r'\g<1>#4094',asm.read_text(),count=1)
            assert n==1
            bad.write_text(damaged)
            result = run([cc,caller_object,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
            result = run([badexe],True);assert result.returncode!=0,'wrong comparison escaped the independent oracle'
            damaged,n = re.subn(r'(\bmovn [wx]\d+, #)([0-9]+)',lambda m:m[1]+str(int(m[2])^1),asm.read_text(),count=1)
            assert n==1
            bad.write_text(damaged)
            result = run([cc,caller_object,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
            result = run([badexe],True);assert result.returncode!=0,'wrong MOVN escaped the independent oracle'
            damaged,n = re.subn(r'(\band [wx]\d+, [wx]\d+, )#4095\b',r'\g<1>#2047',asm.read_text(),count=1)
            assert n==1
            bad.write_text(damaged)
            result = run([cc,caller_object,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
            result = run([badexe],True);assert result.returncode!=0,'wrong logical immediate escaped the independent oracle'
    print(f'{target}: {functions} integer immediate/comparison/fallback functions, {count} independent cases per baseline/allocated/optimized mode; execution={execute}',flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-isel-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
