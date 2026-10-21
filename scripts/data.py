#!/usr/bin/env python3
"""Packed integer data, relocations, alignment and global lifetime qualification."""
import argparse
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

SOURCE = '''data $packed = { b -1 258, h -2, w 4294967295, l -1, z 3 }
export data $numbers = align 32 { l 11 22 33 }
data $alias = { l $numbers+8 }
data $self = { l $self }
data $forward = { l $later }
data $later = { w 99 }
export data $zeroes = { z 24 }
export data $code = { l $read_second }
export function l $read_second() {
@start
 %p =l load $alias
 %v =l load %p
 ret %v
}
export function w $read_forward() {
@start
 %p =l load $forward
 %v =w load %p
 ret %v
}
export function w $self_equal() {
@start
 %p =l load $self
 %v =w ceql %p, $self
 ret %v
}
export function l $packed_value() {
@start
 %p =l add $packed, 8
 %v =l load %p
 ret %v
}
export function l $zero_value() {
@start
 %v =l load $zeroes
 ret %v
}
function $set_global() {
@start
 %temporary =l alloc8 8
 storel 71, %temporary
 %value =l load %temporary
 storel %value, $numbers
 ret
}
export function l $after_call() {
@start
 call $set_global()
 %value =l load $numbers
 ret %value
}
export function w $aligned() {
@start
 %bits =l and $numbers, 31
 %r =w ceql %bits, 0
 ret %r
}
export function w $code_equal() {
@start
 %p =l load $code
 %r =w ceql %p, $read_second
 ret %r
}
'''
EXPECTED = {'read_second': 22, 'read_forward': 99, 'self_equal': 1,
            'packed_value': 2**64-1, 'zero_value': 0, 'after_call': 71,
            'aligned': 1, 'code_equal': 1}
CALLER = '''#include <stdint.h>
#include <stdio.h>
extern uint64_t numbers[3], zeroes[3];
extern uint64_t (*code)(void);
extern uint64_t read_second(void), packed_value(void), zero_value(void), after_call(void);
extern uint32_t read_forward(void), self_equal(void), aligned(void), code_equal(void);
int main(void) {
 if (numbers[0] != 11 || numbers[1] != 22 || numbers[2] != 33 ||
     ((uintptr_t)numbers & 31) || zeroes[0] || zeroes[1] || zeroes[2] || code != read_second) return 1;
 if (read_second() != 22 || read_forward() != 99 || self_equal() != 1 ||
     packed_value() != UINT64_MAX || zero_value() || aligned() != 1 || code_equal() != 1) return 2;
 if (after_call() != 71 || numbers[0] != 71) return 3;
 puts("data checks passed");
 return 0;
}
'''
NEGATIVES = {
    'duplicate': ('data $x = { l 0 } data $x = { l 1 }', 'duplicate module symbol'),
    'function_collision': ('data $x = { l 0 } function l $x() { @s ret 0 }', 'duplicate module symbol'),
    'alignment': ('data $x = align 3 { l 0 }', 'power of two'),
    'negative_zero': ('data $x = { z -1 }', 'zero fill size'),
    'large_zero': ('data $x = { z 268435457 }', 'zero fill size'),
    'total_size': ('data $x = { z 268435456 } data $y = { b 0 }', 'module data exceeds'),
    'empty_field': ('data $x = { w }', 'requires at least one'),
    'short_pointer': ('data $x = { w $x }', 'requires l'),
    'call_data': ('data $x = { l 0 } function $f() { @s call $x() ret }', 'defined as data'),
    'missing_comma': ('data $x = { z 1 l 2 }', "expected ','"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261020)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    with tempfile.TemporaryDirectory(prefix='lcb-data-') as directory:
        work = Path(directory)
        source, asm, caller = work/'input.ssa', work/'lean.s', work/'caller.c'
        source.write_text(SOURCE)
        caller.write_text(CALLER)
        run([LCB, '--check', source])
        run([LCB, source, '-o', asm])
        for name, value in EXPECTED.items():
            assert int(run([LCB, '--eval', source, name])) == value, name
        reject([LCB, '--first-path', source], 'outside the first-path profile')
        for name, (text, diagnostic) in NEGATIVES.items():
            invalid = work/f'{name}.ssa'
            invalid.write_text(text)
            reject([LCB, '--check', invalid], diagnostic)
        data_only = work/'data-only.ssa'
        data_only.write_text('export data $only = { l 7, z 8 }')
        run([LCB, '--check', data_only])
        run([LCB, data_only, '-o', work/'data-only.s'])
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
                assert run([exe]).strip() == 'data checks passed'
            run([cc, '-c', work/'data-only.s', '-o', work/'data-only.o'])
            mutant = work/'mutant.s'
            text = asm.read_text().replace('\t.quad 22\n', '\t.quad 23\n')
            assert text != asm.read_text()
            mutant.write_text(text)
            run([cc, '-std=c11', '-O2', caller, mutant, '-o', work/'mutant'])
            result = subprocess.run([work/'mutant'], capture_output=True, timeout=30)
            assert result.returncode == 1, 'wrong initializer escaped checks'
    print(f'data: {len(EXPECTED)} interpreter cases, {len(NEGATIVES)} rejections, data-only emission; ' +
          ('native Lean/QBE/C and initializer corruption checks passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
