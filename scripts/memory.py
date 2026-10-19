#!/usr/bin/env python3
"""Defined-memory tests: independent byte arrays, Lean evaluation and two native backends.

The current allocation domain is positive constant sizes in the entry block.
External-pointer cases run natively against independent byte expectations; the
interpreter refuses external, out-of-bounds and uninitialized memory accesses.
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import time
import traceback
from fuzz import ROOT, LCB, run, native_host, compile_and_run, inputs

MASK = (1 << 64) - 1
LOADS = [('loadsb', 1, True), ('loadub', 1, False), ('loadsh', 2, True),
         ('loaduh', 2, False), ('loadsw', 4, True), ('loaduw', 4, False), ('load', 0, False),
         ('loadw', 4, True), ('loadl', 0, False)]
STORES = [('storeb', 1), ('storeh', 2), ('storew', 4), ('storel', 8)]


def read(memory, offset, size, signed, bits):
    return int.from_bytes(memory[offset:offset + size], 'little', signed=signed) & ((1 << bits) - 1)


def write(memory, offset, size, value):
    memory[offset:offset + size] = (value & ((1 << (size * 8)) - 1)).to_bytes(size, 'little')


@dataclass
class Case:
    name: str
    bits: int
    body: str
    expected: object
    reference: str = ''

    def source(self):
        width = 'w' if self.bits == 32 else 'l'
        return f'export function {width} ${self.name}(l %a, l %b) {{\n{self.body}\n}}\n'

    def evaluate(self, a, b): return self.expected(a, b)


def fixed_cases():
    cases = []
    for bits in (32, 64):
        width = 'w' if bits == 32 else 'l'
        for op, size, signed in LOADS:
            size = size or bits // 8
            def expected(a, b, size=size, signed=signed, bits=bits):
                memory = a.to_bytes(8, 'little') + b.to_bytes(8, 'little')
                return read(memory, 1, size, signed, bits)
            cases.append(Case(f'{op}_{bits}_unaligned', bits, f'''@entry
 %p =l alloc16 16
 %p8 =l add %p, 8
 storel %a, %p
 storel %b, %p8
 %q =l add %p, 1
 %r ={width} {op} %q
 ret %r''', expected))
    for op, size in STORES:
        def expected(a, b, size=size):
            memory = bytearray(a.to_bytes(8, 'little') + bytes(8))
            write(memory, 3, size, b)
            return read(memory, 0, 8, False, 64) ^ read(memory, 8, 8, False, 64)
        cases.append(Case(f'{op}_overlap', 64, f'''@entry
 %p =l alloc8 16
 %p8 =l add %p, 8
 storel %a, %p
 storel 0, %p8
 %q =l add %p, 3
 {op} %b, %q
 %lo =l load %p
 %hi =l load %p8
 %r =l xor %lo, %hi
 ret %r''', expected))
    for alignment in (1, 2, 4, 8, 16):
        cases.append(Case(f'align{alignment}', 64, f'''@entry
 %p =l alloc{alignment} 17
 %q =l alloc{alignment} 31
 %pb =l and %p, {alignment - 1}
 %qb =l and %q, {alignment - 1}
 %same =l ceql %p, %q
 %low =l or %pb, %qb
 %r =l or %low, %same
 ret %r''', lambda a, b: 0))
    def alias_expected(a, b):
        if a & 1: a = (a & ~255) | 255
        else: b = (b & ~255) | 255
        return a ^ b
    cases.append(Case('phi_alias', 64, '''@entry
 %p =l alloc16 16
 %q =l add %p, 8
 storel %a, %p
 storel %b, %q
 %c =w and %a, 1
 jnz %c, @yes, @no
@yes
 jmp @join
@no
 jmp @join
@join
 %chosen =l phi @yes %p, @no %q
 storeb 255, %chosen
 %left =l load %p
 %right =l load %q
 %r =l xor %left, %right
 ret %r''', alias_expected))
    cases.append(Case('array_loop', 64, '''@entry
 %p =l alloc16 32
 jmp @fill
@fill
 %i =l phi @entry 0, @put %next
 %more =w cultl %i, 4
 jnz %more, @put, @readstart
@put
 %offset =l mul %i, 8
 %address =l add %p, %offset
 %value =l add %a, %i
 storel %value, %address
 %next =l add %i, 1
 jmp @fill
@readstart
 jmp @read
@read
 %j =l phi @readstart 0, @get %jnext
 %sum =l phi @readstart 0, @get %updated
 %again =w cultl %j, 4
 jnz %again, @get, @end
@get
 %roffset =l mul %j, 8
 %raddress =l add %p, %roffset
 %loaded =l load %raddress
 %updated =l add %sum, %loaded
 %jnext =l add %j, 1
 jmp @read
@end
 ret %sum''', lambda a, b: (4 * a + 6) & MASK))
    return cases


def generated_case(seed, index):
    rng = random.Random(seed * 65537 + index)
    bits = 32 if index % 2 else 64
    width, mask = ('w' if bits == 32 else 'l'), (1 << bits) - 1
    lines, actions = ['@entry', ' %p =l alloc16 32'], []
    for offset in (0, 8, 16, 24):
        lines += [f' %init{offset} =l add %p, {offset}', f' storel 0, %init{offset}']
    previous = '0'
    for step in range(12):
        op, size = rng.choice(STORES)
        offset, bias = rng.randrange(33 - size), rng.getrandbits(64)
        lines += [f' %data{step} =l xor %a, {bias}', f' %dest{step} =l add %p, {offset}',
                  f' {op} %data{step}, %dest{step}']
        load, count, signed = rng.choice(LOADS)
        count = count or bits // 8
        source = rng.randrange(33 - count)
        lines += [f' %src{step} =l add %p, {source}', f' %v{step} ={width} {load} %src{step}',
                  f' %acc{step} ={width} xor {previous}, %v{step}']
        previous = f'%acc{step}'
        actions.append((offset, size, bias, source, count, signed))
    lines.append(f' ret {previous}')
    def expected(a, b):
        memory, accumulator = bytearray(32), 0
        for offset, size, bias, source, count, signed in actions:
            write(memory, offset, size, a ^ bias)
            accumulator ^= read(memory, source, count, signed, bits)
        return accumulator & mask
    name = f'mem_{seed}_{index}'
    reference = [f'uint{bits}_t {name}(uint64_t a, uint64_t b) {{',
                 ' (void)b; unsigned char memory[32] = {0};', f' uint{bits}_t accumulator = 0;']
    for offset, size, bias, source, count, signed in actions:
        reference += [f' write_memory(memory + {offset}, {size}, a ^ UINT64_C({bias}));',
                      f' accumulator ^= (uint{bits}_t)read_memory(memory + {source}, {count}, {int(signed)});']
    reference += [' return accumulator;', '}']
    return Case(name, bits, '\n'.join(lines), expected, '\n'.join(reference))


C_REFERENCE = '''#include <stdint.h>
static void write_memory(unsigned char *p, unsigned size, uint64_t value) {
  for (unsigned i=0; i<size; ++i) p[i] = (unsigned char)(value >> (8*i));
}
static uint64_t read_memory(const unsigned char *p, unsigned size, int sign) {
  uint64_t value = 0;
  for (unsigned i=0; i<size; ++i) value |= (uint64_t)p[i] << (8*i);
  if (sign && size<8 && (value & (UINT64_C(1) << (size*8-1))))
    value |= UINT64_MAX << (size*8);
  return value;
}
'''


def corrected_oracle(original, target):
    """One declared load-forwarding correction in a disposable comparison copy."""
    source = ROOT/'third_party/qbe/load.c'
    lock = json.loads((ROOT/'upstream-lock.json').read_text())
    assert hashlib.sha256(source.read_bytes()).hexdigest() == lock['vendored_files']['third_party/qbe/load.c']
    patch = json.loads((ROOT/'tests/upstream/qbe-1.3-loadopt-mask.json').read_text())
    assert patch['source'] == 'load.c' and patch['upstream'] == 'QBE 1.3'
    shutil.copytree(original, target)
    text = (target/'load.c').read_text()
    assert text.count(patch['before']) == 1
    (target/'load.c').write_text(text.replace(patch['before'], patch['after']))
    run(['make', '-j2', f'CC={os.environ["LCB_CC"]}'], cwd=target)
    return target/'qbe'


def upstream_regression(work, original, corrected):
    source = ROOT/'tests/regressions/qbe-storew-overlapping-load.ssa'
    argument = 0x123456789abcdef0
    expected = (argument & 0xffffffff) >> 8
    actual = int(run([LCB, '--eval', source, 'storew_overlap', argument, 0]))
    assert actual == expected
    cfile = ROOT/'tests/regressions/qbe-storew-overlapping-load.c'
    found = {}
    for name, compiler in [('lean', None), ('original', original), ('corrected', corrected)]:
        assembly = work/f'regression-{name}.s'
        run([LCB, source, '-o', assembly] if compiler is None else
            [compiler, '-t', 'arm64_apple', '-o', assembly, source])
        values = compile_and_run(os.environ['LCB_CC'], assembly, cfile, work/f'regression-{name}')
        assert len(values) == 2
        found[name] = {'actual': values[0], 'c_reference': values[1]}
    assert all(value['c_reference'] == expected for value in found.values()), found
    assert found['lean']['actual'] == found['corrected']['actual'] == expected, found
    assert found['original']['actual'] != expected, 'upstream discrepancy control unexpectedly disappeared; re-audit patch'
    return found


def caller(cases, arguments):
    lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
    lines += [f'extern uint{case.bits}_t {case.name}(uint64_t, uint64_t);' for case in cases]
    lines += ['int main(void) {']
    for case in cases:
        for a, b in arguments:
            lines.append(f'printf("%" PRIu64 "\\n", (uint64_t){case.name}(UINT64_C({a}), UINT64_C({b})));')
    return '\n'.join(lines + ['return 0;', '}']) + '\n'


def controls(work):
    invalid = [
        ('function w $f() { @s %p =w alloc4 8 ret 0 }', 'long result'),
        ('function l $f(l %n) { @s %p =l alloc4 %n ret 0 }', 'dynamic stack'),
        *[(f'function l $f() {{ @s %p =l alloc4 {size} ret 0 }}', 'constant size')
          for size in (0, -1, 4097)],
        ('function l $f() { @s jmp @b @b %p =l alloc4 8 ret 0 }', 'outside the entry'),
        ('function w $f(w %p) { @s %v =w load %p ret %v }', 'w-to-l'),
        ('function w $f() { @s storew 0, %missing ret 0 }', 'undefined temporary'),
    ]
    source, output = work/'control.ssa', work/'control.s'
    for text, message in invalid:
        source.write_text(text)
        result = subprocess.run([str(LCB), source, '-o', output], text=True, capture_output=True, timeout=30)
        assert result.returncode != 0 and message in result.stderr and not output.exists(), result.stderr
    undefined = [
        ('%p =l alloc4 4 %r =w load %p', 'uninitialized'),
        ('%p =l alloc4 4 storel 0, %p %r =w copy 0', 'outside an allocated object'),
        ('%p =l copy 0 %r =w load %p', 'outside an allocated object'),
    ]
    for body, message in undefined:
        source.write_text(f'function w $f() {{ @s {body} ret %r }}')
        result = subprocess.run([str(LCB), '--eval', source, 'f'], text=True, capture_output=True, timeout=30)
        assert result.returncode != 0 and message in result.stderr, result.stderr
    source.write_text('function l $f() { @s %p =l alloc16 4096 ret 0 }')
    result = subprocess.run([str(LCB), source, '-o', output], text=True, capture_output=True, timeout=30)
    assert result.returncode != 0 and 'stack frame' in result.stderr and not output.exists()
    return len(invalid) + len(undefined) + 1


def external_memory(work, original, corrected):
    """Actual C-owned memory; every write checks all surrounding guard bytes."""
    functions, declarations, calls, expected = [], [], [], []
    for bits in (32, 64):
        width = 'w' if bits == 32 else 'l'
        for op, size, signed in LOADS:
            size = size or bits // 8
            name = f'external_{op}_{bits}'
            functions.append(f'export function {width} ${name}(l %p, l %v) {{\n@entry\n %r ={width} {op} %p\n ret %r\n}}\n')
            declarations.append(f'extern uint{bits}_t {name}(uint64_t, uint64_t);')
            for variant in range(4):
                memory = bytes((i * 37 + variant * 101) & 255 for i in range(48))
                calls.append(f'for(unsigned i=0;i<48;++i) buffer[i]=(unsigned char)(i*37+{variant}*101);')
                for offset in range(16):
                    calls.append(f'printf("%" PRIu64 "\\n", (uint64_t){name}((uint64_t)(uintptr_t)(buffer+{offset}),0));')
                    expected.append(read(memory, offset, size, signed, bits))
    values = [0, 1, MASK, 1 << 63, 0x123456789abcdef0, 255, 65535, 0xffffffff]
    for op, size in STORES:
        name = f'external_{op}'
        functions.append(f'export function w ${name}(l %p, l %v) {{\n@entry\n {op} %v, %p\n ret 0\n}}\n')
        declarations.append(f'extern uint32_t {name}(uint64_t,uint64_t);')
        for value in values:
            for offset in range(16):
                calls += ['memset(buffer,165,sizeof buffer);',
                          f'if({name}((uint64_t)(uintptr_t)(buffer+{offset}),UINT64_C({value}))) return 3;',
                          'for(unsigned i=0;i<48;++i) {',
                          f' unsigned char wanted=(i>={offset} && i<{offset + size}) ? (unsigned char)(UINT64_C({value}) >> (8*(i-{offset}))) : 165;',
                          ' if(buffer[i]!=wanted) return 2;', '}', 'puts("1");']
                expected.append(1)
    source, cfile = work/'external.ssa', work/'external.c'
    source.write_text(''.join(functions))
    cfile.write_text('#include <stdint.h>\n#include <stdio.h>\n#include <inttypes.h>\n#include <string.h>\n'
                     + '\n'.join(declarations) + '\nint main(void) { unsigned char buffer[48];\n'
                     + '\n'.join(calls) + '\nreturn 0; }\n')
    lean_assembly = None
    for label, oracle in [('lean', None), ('original', original), ('corrected', corrected)]:
        assembly = work/f'external-{label}.s'
        run([LCB, source, '-o', assembly] if oracle is None else
            [oracle, '-t', 'arm64_apple', '-o', assembly, source])
        actual = compile_and_run(os.environ['LCB_CC'], assembly, cfile, work/f'external-{label}')
        assert actual == expected, ('external memory', label)
        if oracle is None: lean_assembly = assembly
    # Qualify the guard-byte checks by widening byte stores deliberately.
    corrupt = work/'external-corrupt.s'
    text = lean_assembly.read_text()
    changed = text.replace('\tstrb w10, [x9]', '\tstrh w10, [x9]')
    assert changed != text
    corrupt.write_text(changed)
    executable = work/'external-corrupt'
    run([os.environ['LCB_CC'], '-std=c11', '-O2', cfile, corrupt, '-o', executable])
    result = subprocess.run([executable], text=True, capture_output=True, timeout=30)
    assert result.returncode == 2, 'guard-byte control did not catch a widened store'
    return len(expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, action='append')
    options = parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    seeds = options.seed or [20261018, 20261019]
    cases = fixed_cases() + [generated_case(seed, index) for seed in seeds for index in range(8)]
    arguments = inputs(20261018, 64)
    interpreted = native = c_reference_cases = 0
    original_mismatches = []
    with tempfile.TemporaryDirectory(prefix='lcb-memory-') as directory:
        work, qbe = Path(directory), None
        report_directory = ROOT/'.build/memory-qbe-discrepancies'/f'run-{time.time_ns()}'
        if native_host():
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={os.environ["LCB_CC"]}'], cwd=oracle)
            qbe = oracle/'qbe'
            corrected = corrected_oracle(oracle, work/'corrected-oracle')
        try:
            rejected = controls(work)
            regression = upstream_regression(work, qbe, corrected) if qbe else None
            external_cases = external_memory(work, qbe, corrected) if qbe else 0
            for start in range(0, len(cases), 32):
                selected = cases[start:start + 32]
                source, asm, qasm, cfile = [work/name for name in ('input.ssa','lean.s','qbe.s','caller.c')]
                source.write_text(''.join(case.source() for case in selected))
                expected = [case.evaluate(a, b) for case in selected for a, b in arguments]
                (work/'case.json').write_text(json.dumps({'seeds': seeds, 'arguments': arguments,
                    'expected': expected, 'compiler_sha256': hashlib.sha256(LCB.read_bytes()).hexdigest(),
                    'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    'upstream_lock_sha256': hashlib.sha256((ROOT/'upstream-lock.json').read_bytes()).hexdigest(),
                    'flake_lock_sha256': hashlib.sha256((ROOT/'flake.lock').read_bytes()).hexdigest()}, indent=2))
                if qbe:
                    report_directory.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, report_directory/f'batch-{start}.ssa')
                    shutil.copy2(work/'case.json', report_directory/f'batch-{start}.json')
                run([LCB, '--check', source])
                run([LCB, source, '-o', asm])
                for case in selected:
                    for a, b in arguments[:8]:
                        found = int(run([LCB, '--eval', source, case.name, a, b]))
                        assert found == case.evaluate(a, b), (case.name, a, b, found, case.evaluate(a, b))
                        interpreted += 1
                if qbe:
                    cfile.write_text(caller(selected, arguments))
                    run([qbe, '-t', 'arm64_apple', '-o', qasm, source])
                    corrected_asm = work/'qbe-corrected.s'
                    run([corrected, '-t', 'arm64_apple', '-o', corrected_asm, source])
                    for label, assembly in [('lean', asm), ('qbe-corrected', corrected_asm), ('qbe-original', qasm)]:
                        actual = compile_and_run(os.environ['LCB_CC'], assembly, cfile, work/label)
                        (work/f'{label}-output.json').write_text(json.dumps(actual))
                        assert len(actual) == len(expected), (label, 'output count', len(actual), len(expected))
                        shutil.copy2(work/f'{label}-output.json', report_directory/f'batch-{start}-{label}.json')
                        if label == 'qbe-original':
                            for i, (found, wanted) in enumerate(zip(actual, expected)):
                                if found == wanted: continue
                                case = selected[i // len(arguments)]
                                assert case.reference, ('unexpected upstream mismatch outside generated overlap cases', case.name)
                                original_mismatches.append({'function': case.name,
                                    'arguments': arguments[i % len(arguments)], 'original_qbe': found, 'expected': wanted})
                        else:
                            assert actual == expected, (label, start, next((i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]), None))
                    generated = [case for case in selected if case.reference]
                    if generated:
                        reference_file, reference_exe = work/'reference.c', work/'reference'
                        reference_file.write_text(C_REFERENCE + '\n'.join(case.reference for case in generated)
                                                  + '\n' + caller(generated, arguments))
                        run([os.environ['LCB_CC'], '-std=c11', '-O2', reference_file, '-o', reference_exe])
                        actual = [int(line) for line in run([reference_exe]).splitlines()]
                        assert actual == [case.evaluate(a, b) for case in generated for a, b in arguments]
                        c_reference_cases += len(actual)
                    native += len(expected)
                    if start == 0:
                        corrupt = work/'corrupt.s'
                        original = asm.read_text()
                        changed = original.replace('\tldrsb x9, [x9]', '\tldrb w9, [x9]')
                        assert changed != original, 'signed-load negative control did not apply'
                        corrupt.write_text(changed)
                        assert compile_and_run(os.environ['LCB_CC'], corrupt, cfile, work/'corrupt') != expected
        except Exception:
            target = ROOT/'.build/memory-failures'/f'run-{time.time_ns()}'
            target.mkdir(parents=True, exist_ok=True)
            for path in work.iterdir():
                if path.suffix in ('.ssa','.s','.c','.json'): shutil.copy2(path, target/path.name)
            (target/'failure.txt').write_text(traceback.format_exc())
            print(f'MEMORY FAILURE: retained {target}', flush=True)
            raise
        if qbe:
            report = report_directory/'summary.json'
            report.write_text(json.dumps({'seeds': seeds, 'regression': regression,
                'original_qbe_mismatches': original_mismatches,
                'oracle_patch_sha256': hashlib.sha256((ROOT/'tests/upstream/qbe-1.3-loadopt-mask.json').read_bytes()).hexdigest()}, indent=2))
    print(f'memory: {len(cases)} functions ({len(seeds) * 8} generated), {interpreted} interpreter cases, '
          f'{rejected} rejection/undefined-domain controls; '
          + (f'{native} native cases per Lean/corrected-QBE backend; {external_cases} C-owned-memory cases per backend; '
             f'{c_reference_cases} C reference cases; '
             'signed-load corruption detected' if qbe else 'native not measured'))
    if qbe:
        print(f'Original QBE 1.3: {len(original_mismatches)} known-class overlap mismatches; '
              f'NOT counted as matching. Exact cases retained in {report_directory}')


if __name__ == '__main__': main()
