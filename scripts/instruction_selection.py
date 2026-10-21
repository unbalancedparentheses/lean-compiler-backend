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
        for op in ['add','add_left','sub','shl','shr','sar']:
            for value in counts if op in ['shl','shr','sar'] else constants:
                name = f'isel_{len(sources)}'
                actual_op = 'add' if op=='add_left' else op
                operands = f'{value},%x' if op=='add_left' else f'%x,{value}'
                sources.append(f'export function {width} ${name}(l %x) {{\n@s\n %r ={width} {actual_op} {operands}\n ret %r\n}}\n')
                declarations.append(f'extern uint{bits}_t {name}(uint64_t);')
                for x in inputs:
                    a, b = x & mask, value & mask
                    if op.startswith('add'): result = a+b
                    elif op=='sub': result = a-b
                    elif op=='shl': result = a << (value%bits)
                    elif op=='shr': result = a >> (value%bits)
                    else: result = (a if a < 1<<(bits-1) else a-(1<<bits)) >> (value%bits)
                    result &= mask
                    checks.append(f'if({name}(UINT64_C({x}))!=UINT{bits}_C({result})){{fprintf(stderr,"case {len(checks)}\\n");return 1;}}')
    caller = '#include <stdint.h>\n#include <stdio.h>\n'+'\n'.join(declarations)+'\nint main(void){\n'+'\n'.join(checks)+'\nreturn 0;\n}\n'
    return ''.join(sources), caller, len(sources), len(checks)


def exercise(compiler, work, run, cc, target, execute=True):
    case = Path(work)/'instruction-selection';case.mkdir(exist_ok=True)
    text, c, functions, count = fixture()
    source, caller = case/'input.ssa', case/'caller.c'
    source.write_text(text);caller.write_text(c)
    for label, flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm, exe = case/(label+'.s'), case/label
        result = run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if target.startswith('aarch64') and flags:
            output = asm.read_text()
            assert re.search(r'\b(?:add|sub) [wx]\d+, [wx]\d+, #4095, lsl #12',output)
            assert re.search(r'\b(?:lsl|lsr|asr) [wx]\d+, [wx]\d+, #31',output)
        if execute:
            result = run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result = run([exe],True);assert result.returncode==0,(target,label,result.stderr)
        if execute and target.startswith('aarch64') and label=='allocated':
            damaged, n = re.subn(r'(\b(?:add|sub) [wx]\d+, [wx]\d+, )#4095\b',r'\g<1>#4094',asm.read_text(),count=1)
            assert n==1
            bad, badexe = case/'broken.s',case/'broken';bad.write_text(damaged)
            result = run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
            result = run([badexe],True);assert result.returncode!=0,'wrong immediate escaped the independent oracle'
    print(f'{target}: {functions} integer immediate/fallback functions, {count} independent cases per baseline/allocated/optimized mode; execution={execute}',flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-isel-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
