#!/usr/bin/env python3
"""Qualify symbol addresses against native C and pinned QBE on Apple ARM64."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host

SOURCE = '''export function l $read_global() {
@start
 %r =l load $external_value
 ret %r
}
export function $write_global(l %value) {
@start
 storel %value, $external_value
 ret
}
export function l $global_address() {
@start
 ret $external_value
}
export function l $function_address() {
@start
 ret $read_global
}
export function l $select_global(w %choice) {
@start
 jnz %choice, @left, @right
@left
 jmp @join
@right
 jmp @join
@join
 %p =l phi @left $external_value, @right $other_value
 %r =l load %p
 ret %r
}
export function w $address_word() {
@start
 ret $external_value
}
'''
CALLER = '''#include <stdint.h>
#include <stdio.h>
uint64_t external_value = UINT64_C(0xfedcba9876543210);
uint64_t other_value = 17;
extern uint64_t read_global(void), global_address(void), function_address(void);
extern uint64_t select_global(uint32_t);
extern uint32_t address_word(void);
extern void write_global(uint64_t);
int main(void) {
 if (read_global() != external_value || global_address() != (uintptr_t)&external_value ||
     function_address() != (uintptr_t)&read_global || address_word() != (uint32_t)(uintptr_t)&external_value ||
     select_global(1) != external_value || select_global(0) != other_value) return 1;
 write_global(42);
 if (external_value != 42 || read_global() != 42) return 2;
 puts("symbol checks passed");
 return 0;
}
'''


def reject(args, diagnostic):
    result = subprocess.run([str(a) for a in args], text=True, capture_output=True, timeout=30)
    assert result.returncode and diagnostic in result.stderr, result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=0)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    with tempfile.TemporaryDirectory(prefix='lcb-symbols-') as directory:
        work = Path(directory)
        source, asm, caller = work/'input.ssa', work/'lean.s', work/'caller.c'
        source.write_text(SOURCE)
        caller.write_text(CALLER)
        run([LCB, '--check', source])
        run([LCB, source, '-o', asm])
        reject([LCB, '--eval', source, 'read_global'], 'no interpreter model')
        restricted = work/'restricted.ssa'
        restricted.write_text('function l $f() { @start ret $external_value }')
        reject([LCB, '--first-path', restricted], 'global symbol addresses')
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
                assert run([exe]).strip() == 'symbol checks passed'
            # Prove the native checks observe the referenced object, not just an address.
            mutant = work/'mutant.s'
            mutant.write_text(asm.read_text().replace('_external_value@', '_other_value@'))
            run([cc, '-std=c11', '-O2', caller, mutant, '-o', work/'mutant'])
            result = subprocess.run([work/'mutant'], capture_output=True, timeout=30)
            assert result.returncode == 1, 'wrong-symbol corruption escaped checks'
    print('symbols: parser/emitter and model refusal checks passed; ' +
          ('native Lean/QBE/C checks and wrong-symbol control passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
