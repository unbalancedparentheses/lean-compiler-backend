#!/usr/bin/env python3
"""Independent native/semantic checks; QBE 1.3 is a retained third-party oracle.

See docs/UPSTREAM.md for QBE/Zig provenance. All subprocess arguments are arrays;
generated code is assembled and linked without Lean's runtime libraries.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import random
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LCB = ROOT / '.lake/build/bin/lcb'


def run(args, *, cwd=ROOT, success=True):
    result = subprocess.run([str(a) for a in args], cwd=cwd, text=True, capture_output=True, timeout=120)
    if success and result.returncode:
        raise AssertionError(f'{args}:\n{result.stdout}\n{result.stderr}')
    if not success and result.returncode == 0:
        raise AssertionError(f'expected rejection: {args}\n{result.stdout}')
    return result


def provenance():
    lock = json.loads((ROOT / 'upstream-lock.json').read_text())
    actual = {str(p.relative_to(ROOT)) for p in (ROOT / 'third_party').rglob('*') if p.is_file()}
    assert actual == set(lock['vendored_files']), 'vendored-file inventory mismatch'
    for name, expected in lock['vendored_files'].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name
    print(f'provenance: {len(actual)} exact upstream files')


def program():
    bodies = []
    for width in ['w', 'l']:
        for op in ['add', 'sub', 'mul', 'and', 'or', 'xor']:
            bodies.append(f'export function {width} ${op}_{width}({width} %a, {width} %b) {{\n'
                          f'@start\n %r ={width} {op} %a, %b\n ret %r\n}}')
    bodies += [
        'export function l $constant64() {\n@s\n %v =l copy -81985529216486896\n ret %v\n}',
        'export function w $truncate(l %a) {\n@s\n ret %a\n}',
        'export function l $sum8(l %a, l %b, l %c, l %d, l %e, l %f, l %g, l %h) {\n'
        '@s\n %s1 =l add %a, %b\n %s2 =l add %c, %d\n %s3 =l add %e, %f\n'
        ' %s4 =l add %g, %h\n %s5 =l add %s1, %s2\n %s6 =l add %s3, %s4\n'
        ' %r =l add %s5, %s6\n ret %r\n}',
    ]
    return '\n'.join(bodies) + '\n'


def negatives(work):
    cases = {
        'undefined': ('function w $f() { @s %x =w add %missing, 1 ret %x }', 'undefined temporary'),
        'duplicate': ('function w $f(w %a) { @s %a =w copy 1 ret %a }', 'duplicate SSA'),
        'duplicate_parameter': ('function w $f(w %a, w %a) { @s ret %a }', 'duplicate parameter'),
        'duplicate_function': ('function w $f() { @s ret 0 } function w $f() { @s ret 1 }', 'duplicate function'),
        'widen': ('function l $f(w %a) { @s ret %a }', 'w-to-l'),
        'float': ('function d $f() { @s ret 0 }', 'unsupported type'),
        'indirect_call': ('function w $f(l %g) { @s %r =w call %g() ret %r }', '$-prefixed name'),
        'branch': ('function w $f() { @s jmp @missing }', 'unknown block'),
        'surplus': ('function w $f() { @s ret 0 } junk', "expected 'function'"),
        'malformed': ('function w $f() { @s %r =w add 1 2 ret %r }', "expected ','"),
        'symbol': ('function w $f.evil() { @s ret 0 }', 'unsupported name'),
        'too_large': ('function l $f() { @s ret 18446744073709551616 }', '64-bit'),
        'trailing_comma': ('function w $f(w %a,) { @s ret %a }', 'trailing comma'),
        'missing_return': ('function w $f() { @s }', 'prefixed name'),
        'empty': ('# no code', 'no functions'),
    }
    for name, (source, diagnostic) in cases.items():
        src, out = work / f'{name}.ssa', work / f'{name}.s'
        src.write_text(source)
        result = run([LCB, src, '-o', out], success=False)
        assert diagnostic in result.stderr, (name, result.stderr)
        assert not out.exists(), f'{name}: rejected input wrote output'
    source = work / 'valid.ssa'
    source.write_text('function w $f() { @s ret 0 }')
    result = run([LCB, source, '--target', 'x86_64-linux'], success=False)
    assert 'unsupported target' in result.stderr
    print(f'rejection controls: {len(cases) + 1}')


def interpreter(work, src):
    rng = random.Random(20261018)
    operations = {
        'add': lambda a, b: a + b,
        'sub': lambda a, b: a - b,
        'mul': lambda a, b: a * b,
        'and': lambda a, b: a & b,
        'or': lambda a, b: a | b,
        'xor': lambda a, b: a ^ b,
    }
    count = 0
    for width, bits in [('w', 32), ('l', 64)]:
        mask = (1 << bits) - 1
        for op, reference in operations.items():
            values = [(0, 0), (mask, 1), (1 << (bits - 1), mask)]
            values += [(rng.getrandbits(bits), rng.getrandbits(bits)) for _ in range(5)]
            for a, b in values:
                actual = int(run([LCB, '--eval', src, f'{op}_{width}', a, b]).stdout)
                assert actual == reference(a, b) & mask, (width, op, a, b, actual)
                count += 1
    assert int(run([LCB, '--eval', src, 'constant64']).stdout) == (-81985529216486896) & ((1 << 64) - 1)
    assert int(run([LCB, '--eval', src, 'truncate', 0x12345678ABCDEF01]).stdout) == 0xABCDEF01
    run([LCB, '--eval', src, 'add_w', '1'], success=False)
    print(f'interpreter vs independent Python arithmetic: {count + 2} values')


def limits(work):
    # The maximum body/parameter limits must not depend on function-list position.
    parameters = ', '.join(f'l %p{i}' for i in range(8))
    body = '\n'.join(f' %v{i} =l add %p0, {i}' for i in range(480))
    maximal = f'function l $maximal({parameters}) {{\n@s\n{body}\n ret %v479\n}}\n'
    prefix = ''.join(f'function w $f{i}() {{\n@s\n ret 0\n}}\n' for i in range(63))
    source = work / 'limits.ssa'
    source.write_text(prefix + maximal)
    run([LCB, '--check', source])
    run([LCB, source, '-o', work / 'limits.s'])
    source.write_text(prefix + maximal + 'function w $extra() { @s ret 0 }')
    run([LCB, '--check', source], success=False)
    source.write_text(maximal.replace(' ret %v479', ' %extra =l copy 0\n ret %v479'))
    run([LCB, '--check', source], success=False)
    source.write_text('function l $f(' + parameters + ', l %ninth) { @s ret 0 }')
    run([LCB, '--check', source], success=False)
    print('resource boundaries: 64 functions, 480 instructions, 8 parameters; over-limit rejection')


def harness():
    declarations, checks = [], []
    operators = {'add': '+', 'sub': '-', 'mul': '*', 'and': '&', 'or': '|', 'xor': '^'}
    for suffix, ctype in [('w', 'uint32_t'), ('l', 'uint64_t')]:
        for op, symbol in operators.items():
            name = f'{op}_{suffix}'
            declarations.append(f'extern {ctype} {name}({ctype}, {ctype});')
            checks.append(f'if ({name}(({ctype})a, ({ctype})b) != '
                          f'({ctype})((({ctype})a) {symbol} (({ctype})b))) '
                          f'{{ fprintf(stderr, "{name} mismatch at %d\\n", i); return 1; }}')
    return '''#include <stdint.h>
#include <stdio.h>
''' + '\n'.join(declarations) + '''
extern uint64_t constant64(void);
extern uint32_t truncate(uint64_t);
extern uint64_t sum8(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
int main(void) {
  uint64_t state = 20261018;
  for (int i = 0; i < 10000; ++i) {
    state = state * UINT64_C(6364136223846793005) + 1442695040888963407ULL;
    uint64_t a = i == 0 ? UINT64_MAX : state;
    state = state * UINT64_C(6364136223846793005) + 1442695040888963407ULL;
    uint64_t b = i == 0 ? 1 : state;
''' + '\n'.join(checks) + '''
    if (truncate(a) != (uint32_t)a) return 2;
    if (sum8(a,b,1,2,3,4,5,6) != a + b + 21) return 3;
  }
  if (constant64() != (uint64_t)-INT64_C(81985529216486896)) return 4;
  puts("native vectors passed");
  return 0;
}
'''


def native(work, src, required):
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        assert not required, 'native execution is required: use an AArch64 macOS host'
        print('native AArch64 macOS execution: unsupported host (not measured)')
        return
    asm, driver = work / 'program.s', work / 'driver.c'
    driver.write_text(harness())
    run([LCB, src, '-o', asm, '--target', 'aarch64-macos'])
    compiler = os.environ.get('LCB_CC', os.environ.get('CC', 'clang'))
    exe = work / 'native'
    run([compiler, '-std=c11', '-O2', driver, asm, '-o', exe])
    assert run([exe]).stdout.strip() == 'native vectors passed'
    undefined = run([os.environ.get('LCB_NM', 'llvm-nm'), '-u', exe]).stdout
    assert not any(marker in undefined for marker in ['lean_', 'l_Lean', 'initialize_Lean']), undefined
    print('native assembly: 120,000 arithmetic vectors, 20,000 ABI/width checks; no Lean imports')
    # QBE is an external oracle, not the implementation used by lcb.
    oracle_root = work / 'qbe'
    shutil.copytree(ROOT / 'third_party/qbe', oracle_root)
    run(['make', '-j2', f'CC={compiler}'], cwd=oracle_root)
    qbe_asm, qbe_exe = work / 'qbe.s', work / 'qbe-native'
    run([oracle_root / 'qbe', '-t', 'arm64_apple', '-o', qbe_asm, src])
    run([compiler, '-std=c11', '-O2', driver, qbe_asm, '-o', qbe_exe])
    assert run([qbe_exe]).stdout.strip() == 'native vectors passed'
    print('upstream QBE 1.3: identical independent harness passed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    options = parser.parse_args()
    provenance()
    with tempfile.TemporaryDirectory(prefix='lcb-test-') as directory:
        work = Path(directory)
        src = work / 'program.ssa'
        src.write_text(program())
        run([LCB, '--check', src])
        negatives(work)
        limits(work)
        interpreter(work, src)
        native(work, src, options.require_native)
    print('all backend checks passed')


if __name__ == '__main__':
    main()
