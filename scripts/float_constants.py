#!/usr/bin/env python3
"""Compare exact IEEE constant parsing with libc and pinned QBE bit-for-bit.

This qualifies constants/data only, not floating instructions or the float ABI.
Single precision uses strtof directly to avoid a double-rounding test oracle.
"""
import argparse
import ctypes
import os
from pathlib import Path
import random
import shutil
import struct
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

LIBC = ctypes.CDLL(None)
LIBC.strtof.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
LIBC.strtof.restype = ctypes.c_float
LIBC.strtod.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
LIBC.strtod.restype = ctypes.c_double


def reference(kind, text):
    value = (LIBC.strtof if kind == 's' else LIBC.strtod)(text.encode(), None)
    return int.from_bytes(struct.pack('<f' if kind=='s' else '<d', value), 'little')


def cases(seed):
    fixed = ['0', '-0', '+0', '1', '-1', '0.1', '-0.1', '.5', '1.', '1e+3',
             'inf', '-inf', 'infinity', 'nan', '-nan', '1e1000', '-1e1000', '1e-1000',
             '0x1p0', '-0x1.8p+2', '0x1p-149', '0x1p-150', '0x1.000002p-150',
             '0x1p-1074', '0x1p-1075', '0x1.0000000000001p-1075',
             '0x1.fffffep127', '0x1.ffffffp127', '0x1.fffffffffffffp1023',
             '0x1.fffffffffffff8p1023', '0x1p-126', '0x1p-1022',
             '1.000000059604644775390625', '1.000000059604644775390626',
             '1.000000178813934326171875',
             '1.00000000000000011102230246251565404236316680908203125',
             '1.00000000000000011102230246251565404236316680908203126']
    result = [(kind, text) for kind in ['s', 'd'] for text in fixed]
    rng = random.Random(seed)
    for kind in ['s', 'd']:
        for _ in range(40):
            text = ('-' if rng.randrange(2) else '') + str(rng.getrandbits(96))
            text += f'e{rng.randrange(-400,401):+}'
            result.append((kind, text))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261020)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    matrix = cases(options.seed)
    with tempfile.TemporaryDirectory(prefix='lcb-float-constants-') as directory:
        work = Path(directory)
        qbe = None
        cc = os.environ.get('LCB_CC', 'clang')
        if native_host():
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qbe = oracle/'qbe'
        for batch in range(0, len(matrix), 24):
            selected = matrix[batch:batch+24]
            source, asm, caller = work/'input.ssa', work/'lean.s', work/'caller.c'
            definitions, declarations, checks = [], [], []
            for index, (kind, text) in enumerate(selected):
                token, wanted = f'{kind}_{text}', reference(kind,text)
                definitions.append(f'export data $object_{index} = {{ {kind} {token} }}\n')
                definitions.append(f'export function l $constant_{index}() {{\n@entry\n ret {token}\n}}\n')
                load = 'loaduw' if kind == 's' else 'load'
                definitions.append(f'export function l $data_{index}() {{\n@entry\n %r =l {load} $object_{index}\n ret %r\n}}\n')
                declarations.append(f'extern uint64_t constant_{index}(void), data_{index}(void);\n')
                declarations.append(f'extern unsigned char object_{index}[];\n')
                checks.append(f'if (constant_{index}() != UINT64_C({wanted}) || data_{index}() != UINT64_C({wanted})) return {index+1};\n')
                size = 4 if kind=='s' else 8
                for offset in range(size):
                    checks.append(f'if (object_{index}[{offset}] != {(wanted>>(offset*8))&255}) return {index+1};\n')
            source.write_text(''.join(definitions))
            caller.write_text('#include <stdint.h>\n' + ''.join(declarations) + 'int main(void) {\n' + ''.join(checks) + 'return 0;}\n')
            run([LCB, source, '-o', asm])
            for index, (kind, text) in enumerate(selected):
                for prefix in ['constant', 'data']:
                    found = int(run([LCB, '--eval', source, f'{prefix}_{index}']))
                    assert found == reference(kind,text), (kind,text,prefix,hex(found),hex(reference(kind,text)))
            if qbe:
                qasm = work/'qbe.s'
                run([qbe, '-t', 'arm64_apple', '-o', qasm, source])
                for label, assembly in [('lean', asm), ('qbe', qasm)]:
                    exe = work/label
                    run([cc, '-std=c11', '-O2', caller, assembly, '-o', exe])
                    run([exe])
        for i, token in enumerate(['s_', 'd_1.2.3', 's_0x.p2', 'd_1e', 's_1e10001', 'd_1p3']):
            source = work/f'bad{i}.ssa'
            source.write_text(f'function l $bad() {{ @s ret {token} }}')
            reject([LCB, '--check', source], 'floating')
    print(f'float constants seed {options.seed}: {len(matrix)} IEEE patterns, {2*len(matrix)} interpreted constant/data results; '
          'libc bit oracle passed; ' + ('native Lean/QBE exact bytes passed' if qbe else 'native not measured'))


if __name__ == '__main__':
    main()
