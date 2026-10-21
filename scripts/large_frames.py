#!/usr/bin/env python3
"""Qualify frame adjustments, high allocation offsets and incoming stack arguments."""
import argparse
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host

COUNTS = [1, 2, 4, 8, 16, 32]
WIDTHS = ['w' if i % 3 == 0 else 'l' for i in range(12)]
MASK = (1 << 64) - 1


def fixture():
    source = ['function $clobber() {\n@start\n ret\n}\n']
    declarations = []
    for count in COUNTS:
        params = ', '.join(f'{w} %a{i}' for i, w in enumerate(WIDTHS))
        source.append(f'export function l $large_{count}({params}) {{\n@entry\n')
        for i,w in enumerate(WIDTHS):
            source.append(f' %v{i} =l {"extuw" if w=="w" else "copy"} %a{i}\n')
        for i in range(count):
            source.append(f' %p{i} =l alloc16 4096\n %end{i} =l add %p{i}, 4088\n')
            source.append(f' storel %v{i%12}, %p{i}\n storel %v{(i+7)%12}, %end{i}\n')
        source.append(' call $clobber()\n')
        acc = '0'
        for i in range(count):
            source.append(f' %first{i} =l load %p{i}\n %last{i} =l load %end{i}\n')
            source.append(f' %sum{i} =l add %first{i}, %last{i}\n %acc{i} =l add {acc}, %sum{i}\n')
            acc = f'%acc{i}'
        source.append(f' ret {acc}\n}}\n')
        cparams = ', '.join('uint32_t' if w=='w' else 'uint64_t' for w in WIDTHS)
        declarations.append(f'extern uint64_t large_{count}({cparams});\n')
    return ''.join(source), ''.join(declarations)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261020)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    rng = random.Random(options.seed)
    vectors = [[0]*12, [MASK]*12] + [[rng.getrandbits(64) for _ in WIDTHS] for _ in range(8)]
    text, declarations = fixture()
    with tempfile.TemporaryDirectory(prefix='lcb-large-frame-') as directory:
        work = Path(directory)
        source, asm, caller = work/'input.ssa', work/'lean.s', work/'caller.c'
        source.write_text(text)
        run([LCB, '--target', 'aarch64-macos', source, '-o', asm])
        checks = []
        for count in COUNTS:
            for vector in vectors:
                values = [v % (1 << (32 if w=='w' else 64)) for v,w in zip(vector,WIDTHS)]
                wanted = sum(values[i%12]+values[(i+7)%12] for i in range(count)) & MASK
                assert int(run([LCB, '--eval', source, f'large_{count}', *vector])) == wanted
                args = ', '.join(f'({"uint32_t" if w=="w" else "uint64_t"})UINT64_C({v})' for v,w in zip(vector,WIDTHS))
                checks.append(f'if (large_{count}({args}) != UINT64_C({wanted})) return 1;\n')
        caller.write_text('#include <stdint.h>\n#include <stdio.h>\n' + declarations +
                          'int main(void) {\n' + ''.join(checks) + 'puts("large frames passed"); return 0; }\n')
        if native_host():
            cc = os.environ.get('LCB_CC', 'clang')
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qasm = work/'qbe.s'
            run([oracle/'qbe', '-t', 'arm64_apple', '-o', qasm, source])
            for label, assembly in [('lean', asm), ('qbe', qasm)]:
                exe = work/label
                run([cc, '-std=c11', '-O2', caller, assembly, '-o', exe])
                assert run([exe]).strip() == 'large frames passed'
            # Corrupt the large-offset incoming load without risking a bad stack restore.
            mutant = work/'mutant.s'
            changed = asm.read_text().replace('\tldr w9, [x10]', '\tmov w9, #0')
            assert changed != asm.read_text()
            mutant.write_text(changed)
            run([cc, '-std=c11', '-O2', caller, mutant, '-o', work/'mutant'])
            result = subprocess.run([work/'mutant'], capture_output=True, timeout=30)
            assert result.returncode == 1, 'corrupted large-offset incoming argument escaped checks'
    print(f'large frames: {len(COUNTS)} layouts through 128 KiB allocations, {len(COUNTS)*len(vectors)} interpreter cases; ' +
          ('native Lean/QBE/C and incoming-argument corruption passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
