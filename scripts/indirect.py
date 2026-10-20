#!/usr/bin/env python3
"""Indirect integer calls: internal tables, C callbacks, stack arguments and void effects."""
import argparse
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

MASK = (1 << 64) - 1
COUNTS = [0, 1, 8, 9, 16, 64]


def widths(count):
    return ['w' if i % 3 == 0 else 'l' for i in range(count)]


def expected(count, a):
    return (17 + sum(((a + i) % (1 << (32 if w == 'w' else 64))) * (2*i + 1)
                     for i, w in enumerate(widths(count)))) & MASK


def fixtures():
    source, c_helpers, declarations = [], [], []
    for count in COUNTS:
        ws = widths(count)
        params = ', '.join(f'{w} %a{i}' for i, w in enumerate(ws))
        source.append(f'function l $target_{count}({params}) {{\n@entry\n')
        acc = '17'
        for i, w in enumerate(ws):
            arg = f'%a{i}'
            if w == 'w':
                source.append(f' %wide{i} =l extuw {arg}\n')
                arg = f'%wide{i}'
            source.append(f' %m{i} =l mul {arg}, {2*i+1}\n %s{i} =l add {acc}, %m{i}\n')
            acc = f'%s{i}'
        source.append(f' ret {acc}\n}}\ndata $table_{count} = {{ l $target_{count} }}\n')
        for kind in ['internal', 'external']:
            params = 'l %a' if kind == 'internal' else 'l %fn, l %a'
            source.append(f'export function l ${kind}_{count}({params}) {{\n@entry\n')
            source.append(f' %target =l load $table_{count}\n' if kind == 'internal' else ' %target =l copy %fn\n')
            for i, w in enumerate(ws):
                source.append(f' %arg{i} ={w} add %a, {i}\n')
            arguments = ', '.join(f'{w} %arg{i}' for i, w in enumerate(ws))
            source.append(f' %result =l call %target({arguments})\n ret %result\n}}\n')
        cparams = ', '.join(f'{"uint32_t" if w=="w" else "uint64_t"} a{i}' for i,w in enumerate(ws)) or 'void'
        c_helpers.append(f'static uint64_t callback_{count}({cparams}) {{ uint64_t s = 17;\n')
        for i in range(count):
            c_helpers.append(f's += (uint64_t)a{i} * UINT64_C({2*i+1});\n')
        c_helpers.append('return s; }\n')
        declarations.append(f'extern uint64_t internal_{count}(uint64_t), external_{count}(uintptr_t,uint64_t);\n')
    source.append('''data $stored = { l 0 }
function $set_stored(l %v) {
@entry
 storel %v, $stored
 ret
}
export function l $void_indirect(l %v) {
@entry
 %fn =l copy $set_stored
 call %fn(l %v)
 %r =l load $stored
 ret %r
}
export function l $void_external(l %fn, l %v) {
@entry
 call %fn(l %v)
 ret %v
}
function l $plus_one(l %v) {
@entry
 %r =l add %v, 1
 ret %r
}
function l $plus_two(l %v) {
@entry
 %r =l add %v, 2
 ret %r
}
export function l $phi_target(w %choice, l %v) {
@entry
 jnz %choice, @left, @right
@left
 jmp @join
@right
 jmp @join
@join
 %fn =l phi @left $plus_one, @right $plus_two
 %r =l call %fn(l %v)
 ret %r
}
export function l $recursive_pointer(l %n) {
@entry
 %small =w culel %n, 1
 jnz %small, @base, @rec
@base
 ret 1
@rec
 %fn =l copy $recursive_pointer
 %next =l sub %n, 1
 %rest =l call %fn(l %next)
 %r =l mul %rest, %n
 ret %r
}
''')
    declarations.append('extern uint64_t void_indirect(uint64_t),void_external(uintptr_t,uint64_t),phi_target(uint32_t,uint64_t),recursive_pointer(uint64_t);\n')
    return ''.join(source), ''.join(c_helpers), ''.join(declarations)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261020)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    rng = random.Random(options.seed)
    values = [0, 1, MASK, 1 << 63, (1 << 32)-1] + [rng.getrandbits(64) for _ in range(5)]
    source_text, helpers, declarations = fixtures()
    with tempfile.TemporaryDirectory(prefix='lcb-indirect-') as directory:
        work = Path(directory)
        source, asm, caller = work/'input.ssa', work/'lean.s', work/'caller.c'
        source.write_text(source_text)
        run([LCB, '--check', source])
        run([LCB, source, '-o', asm])
        checks = []
        for count in COUNTS:
            for value in values:
                wanted = expected(count, value)
                assert int(run([LCB, '--eval', source, f'internal_{count}', value])) == wanted
                checks.append(f'if (internal_{count}(UINT64_C({value})) != UINT64_C({wanted}) || '
                              f'external_{count}((uintptr_t)callback_{count},UINT64_C({value})) != UINT64_C({wanted})) return 1;\n')
        for value in values:
            assert int(run([LCB, '--eval', source, 'void_indirect', value])) == value
            for choice in [0, 1]:
                wanted = (value + (1 if choice else 2)) & MASK
                assert int(run([LCB, '--eval', source, 'phi_target', choice, value])) == wanted
                checks.append(f'if (phi_target({choice},UINT64_C({value})) != UINT64_C({wanted})) return 2;\n')
            checks.append(f'if (void_indirect(UINT64_C({value})) != UINT64_C({value}) || '
                          f'void_external((uintptr_t)save,UINT64_C({value})) != UINT64_C({value}) || saved != UINT64_C({value})) return 3;\n')
        assert int(run([LCB, '--eval', source, 'recursive_pointer', 10])) == 3628800
        checks.append('if (recursive_pointer(10) != 3628800) return 4;\n')
        caller.write_text('#include <stdint.h>\n#include <stdio.h>\n' + helpers + declarations +
                          'static uint64_t saved; static void save(uint64_t v) {saved=v;}\nint main(void) {\n' +
                          ''.join(checks) + 'puts("indirect checks passed"); return 0; }\n')
        reject([LCB, '--eval', source, 'external_0', 0, 0], 'no interpreter model')
        for i, (definition, arguments, result) in enumerate([
            ('function w $target(w %a) { @s ret %a }', 'l 1', 'w'),
            ('function l $target(l %a) { @s ret %a }', 'l 1', 'w'),
            ('function w $target(w %a) { @s ret %a }', '', 'w'),
        ]):
            invalid = work/f'signature{i}.ssa'
            invalid.write_text(definition + f' function {result} $bad() {{ @s %fn =l copy $target %r ={result} call %fn({arguments}) ret %r }}')
            run([LCB, '--check', invalid])
            reject([LCB, '--eval', invalid, 'bad'], 'signature disagrees')
        invalid = work/'data-call.ssa'
        invalid.write_text('data $object = { l 0 } function l $bad() { @s %fn =l copy $object %r =l call %fn() ret %r }')
        reject([LCB, '--eval', invalid, 'bad'], 'not a defined function')
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
                assert run([exe]).strip() == 'indirect checks passed'
            mutant = work/'mutant.s'
            text = asm.read_text().replace('\tblr x16', '\tmov x0, #0')
            assert text != asm.read_text()
            mutant.write_text(text)
            run([cc, '-std=c11', '-O2', caller, mutant, '-o', work/'mutant'])
            result = subprocess.run([work/'mutant'], capture_output=True, timeout=30)
            assert result.returncode == 1, 'removed indirect call escaped checks'
    print(f'indirect: {len(COUNTS)} signatures through 64 arguments, 91 interpreter cases, dynamic signature refusals; ' +
          ('native Lean/QBE/C callbacks, recursion, phi/void calls and corruption control passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
