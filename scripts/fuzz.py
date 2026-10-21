#!/usr/bin/env python3
"""Generate defined-behavior SSA programs and compare three execution paths.

Python evaluates bit-vector operations independently. The Lean interpreter,
Lean-emitted native assembly and upstream QBE output must agree. This checks
the generated cases; it is not a proof. QBE is only a test implementation.
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import shutil
import subprocess
import tempfile
import traceback

ROOT = Path(__file__).resolve().parents[1]
LCB = ROOT / '.lake/build/bin/lcb'
OPS = ('add', 'sub', 'mul', 'and', 'or', 'xor', 'shl', 'shr', 'sar')


def run(args, *, cwd=ROOT):
    result = subprocess.run([str(a) for a in args], cwd=cwd, text=True,
                            capture_output=True, timeout=120)
    if result.returncode:
        raise AssertionError(f'command failed ({result.returncode}): {args}\n{result.stdout}\n{result.stderr}')
    return result.stdout


def binary(op, a, b, mask):
    if op == 'add': value = a + b
    elif op == 'sub': value = a - b
    elif op == 'mul': value = a * b
    elif op == 'and': value = a & b
    elif op == 'or': value = a | b
    elif op == 'xor': value = a ^ b
    elif op == 'shl': value = a << (b % mask.bit_length())
    elif op == 'shr': value = a >> (b % mask.bit_length())
    elif op == 'sar':
        bits = mask.bit_length()
        signed = a if a < (1 << (bits - 1)) else a - (1 << bits)
        value = signed >> (b % bits)
    else: raise AssertionError(op)
    return value & mask


@dataclass
class Function:
    name: str
    bits: int
    instructions: list

    def evaluate(self, a, b):
        mask = (1 << self.bits) - 1
        values = {'a': a & mask, 'b': b & mask}
        for name, op, lhs, rhs in self.instructions:
            left = values[lhs] if isinstance(lhs, str) else lhs & mask
            right = values[rhs] if isinstance(rhs, str) else rhs & mask
            values[name] = binary(op, left, right, mask)
        return values[self.instructions[-1][0]]

    def source(self):
        width = 'w' if self.bits == 32 else 'l'
        operand = lambda v: '%' + v if isinstance(v, str) else str(v)
        lines = [f'export function {width} ${self.name}({width} %a, {width} %b) {{', '@entry']
        lines += [f' %{name} ={width} {op} {operand(lhs)}, {operand(rhs)}'
                  for name, op, lhs, rhs in self.instructions]
        return '\n'.join(lines + [f' ret %{self.instructions[-1][0]}', '}'])


@dataclass
class ControlFunction:
    name: str
    bits: int
    bias: int
    first_op: str
    loop_op: str
    trip_mask: int

    def evaluate(self, a, b):
        mask = (1 << self.bits) - 1
        a, b = a & mask, b & mask
        signed = lambda x: x if x < (1 << (self.bits - 1)) else x - (1 << self.bits)
        initial = binary(self.first_op, a if signed(a) < signed(b) else b, self.bias, mask)
        accumulator, other = initial, a
        for _ in range(b & self.trip_mask):
            accumulator, other = binary(self.loop_op, accumulator, other, mask), accumulator
        return (accumulator ^ other) & mask

    def source(self):
        w = 'w' if self.bits == 32 else 'l'
        return f'''export function {w} ${self.name}({w} %a, {w} %b) {{
@entry
 %limit ={w} and %b, {self.trip_mask}
 %test =w cslt{w} %a, %b
 jnz %test, @yes, @no
@yes
 %left ={w} {self.first_op} %a, {self.bias}
 jmp @join
@no
 %right ={w} {self.first_op} %b, {self.bias}
 jmp @join
@join
 %initial ={w} phi @yes %left, @no %right
 jmp @loop
@loop
 %i ={w} phi @join 0, @body %next
 %acc ={w} phi @join %initial, @body %updated
 %other ={w} phi @join %a, @body %acc
 %condition =w cult{w} %i, %limit
 jnz %condition, @body, @end
@body
 %updated ={w} {self.loop_op} %acc, %other
 %next ={w} add %i, 1
 jmp @loop
@end
 %result ={w} xor %acc, %other
 ret %result
}}'''


def generate(seed, count, steps, control_flow=True):
    rng, functions = random.Random(seed), []
    for index in range(count):
        bits = 32 if index % 2 == 0 else 64
        if control_flow and index % 8 in (2, 7):
            functions.append(ControlFunction(f'f{index}', bits, rng.getrandbits(bits),
                                             rng.choice(OPS), rng.choice(OPS), rng.choice([3,7,15,31])))
            continue
        names, instructions = ['a', 'b'], []
        for step in range(steps):
            lhs = names[-1] if step % 3 else rng.choice(names)
            if rng.randrange(3):
                rhs = rng.choice(names)
            else:
                rhs = rng.choice([0, -1, 1, (1 << (bits - 1)), rng.getrandbits(bits)])
                if bits == 64 and rhs == (1 << 63): rhs = -(1 << 63)
            name, op = f'v{step}', rng.choice(OPS)
            instructions.append((name, op, lhs, rhs))
            names.append(name)
        functions.append(Function(f'f{index}', bits, instructions))
    return functions


def inputs(seed, count):
    rng = random.Random(seed ^ 0xC0FFEE)
    values = [(0, 0), ((1 << 64) - 1, 1), (1 << 63, (1 << 64) - 1),
              (0x80000000, 0xFFFFFFFF), (1, 0)]
    return values + [(rng.getrandbits(64), rng.getrandbits(64)) for _ in range(count)]


def driver(functions, arguments):
    lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
    for f in functions:
        ctype = 'uint32_t' if f.bits == 32 else 'uint64_t'
        lines.append(f'extern {ctype} {f.name}({ctype}, {ctype});')
    lines.append('int main(void) {')
    for f in functions:
        ctype = 'uint32_t' if f.bits == 32 else 'uint64_t'
        for a, b in arguments:
            lines.append(f'printf("%" PRIu64 "\\n", (uint64_t){f.name}('
                         f'({ctype})UINT64_C({a}), ({ctype})UINT64_C({b})));')
    return '\n'.join(lines + ['return 0;', '}']) + '\n'


def native_host():
    return platform.system() == 'Darwin' and platform.machine() == 'arm64'


def compile_and_run(compiler, asm, cfile, executable):
    run([compiler, '-std=c11', '-O2', cfile, asm, '-o', executable])
    return [int(line) for line in run([executable]).splitlines()]


def case(work, seed, functions_count, steps, samples, qbe, self_test, control_flow, optimize=False):
    functions = generate(seed, functions_count, steps, control_flow)
    arguments = inputs(seed, samples)
    source = work / 'input.ssa'
    source.write_text('\n'.join(f.source() for f in functions) + '\n')
    expected = [f.evaluate(a, b) for f in functions for a, b in arguments]
    (work / 'case.json').write_text(json.dumps({
        'seed': seed, 'functions': functions_count, 'steps': steps, 'samples': samples,
        'arguments': arguments, 'expected': expected,
        'toolchain': run([LCB, '--version']).strip(), 'host': platform.platform(),
        'upstream_lock_sha256': hashlib.sha256((ROOT / 'upstream-lock.json').read_bytes()).hexdigest(),
        'compiler_sha256': hashlib.sha256(LCB.read_bytes()).hexdigest(),
        'flake_lock_sha256': hashlib.sha256((ROOT / 'flake.lock').read_bytes()).hexdigest(),
        'target': 'aarch64-macos',
        'control_flow': control_flow,
        'optimized': optimize,
        'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'cc_version': run([os.environ['LCB_CC'], '--version']) if os.environ.get('LCB_CC') else None,
    }, indent=2) + '\n')
    run([LCB, '--check', source])
    actual = [int(run([LCB, '--eval', source, f.name, a, b]))
              for f in functions for a, b in arguments]
    (work / 'interpreter-output.json').write_text(json.dumps(actual))
    for index, (found, wanted) in enumerate(zip(actual, expected)):
        if found != wanted:
            print(f'interpreter case {index}: {functions[index // len(arguments)].name} '
                  f'inputs={arguments[index % len(arguments)]}; got={found}; expected={wanted}', flush=True)
    assert actual == expected, f'Lean interpreter mismatch; seed={seed}'
    if qbe:
        asm, qbe_asm, cfile = work / 'lean.s', work / 'qbe.s', work / 'caller.c'
        cfile.write_text(driver(functions, arguments))
        compiler = os.environ['LCB_CC']
        run([LCB, source, '-o', asm])
        run([qbe, '-t', 'arm64_apple', '-o', qbe_asm, source])
        backends = [('lean', asm), ('qbe', qbe_asm)]
        if optimize:
            optimized_asm = work / 'optimized.s'
            run([LCB, source, '--optimize', '-o', optimized_asm])
            backends.append(('optimized', optimized_asm))
        for label, assembly in backends:
            actual = compile_and_run(compiler, assembly, cfile, work / label)
            (work / f'{label}-output.json').write_text(json.dumps(actual))
            assert actual == expected, f'{label} native mismatch; seed={seed}'
        if self_test:
            # Every return is changed by one. The comparison must notice this
            # deliberate emitted-code corruption; do not count it as a valid case.
            corrupt = work / 'corrupt.s'
            tested_asm = optimized_asm if optimize else asm
            corrupt.write_text(tested_asm.read_text().replace('\tret', '\tadd x0, x0, #1\n\tret'))
            actual = compile_and_run(compiler, corrupt, cfile, work / 'corrupt')
            assert actual != expected, 'fuzzer failed to detect deliberately corrupted emitted code'
    return len(expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed', type=int, action='append')
    parser.add_argument('--seed-start', type=int, default=20261018)
    parser.add_argument('--seeds', type=int, default=4)
    parser.add_argument('--functions', type=int, default=8)
    parser.add_argument('--steps', type=int, default=32)
    parser.add_argument('--samples', type=int, default=3)
    parser.add_argument('--optimize', action='store_true', help='also compare the optional optimized pipeline against the independent oracle')
    parser.add_argument('--straight-line', action='store_true', help='exclude generated branches/loops')
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--artifacts', type=Path, default=ROOT / '.build/fuzz-failures')
    options = parser.parse_args()
    assert 1 <= options.functions <= 64 and 1 <= options.steps <= 480
    assert 0 <= options.samples <= 10000
    if options.require_native: assert native_host(), 'required native AArch64 macOS host unavailable'
    assert 1 <= options.seeds <= 100000
    seeds = options.seed or list(range(options.seed_start, options.seed_start + options.seeds))
    total = 0
    with tempfile.TemporaryDirectory(prefix='lcb-fuzz-') as directory:
        root, qbe = Path(directory), None
        if native_host():
            assert os.environ.get('LCB_CC'), 'run fuzzing inside nix develop'
            oracle = root / 'oracle'
            shutil.copytree(ROOT / 'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={os.environ["LCB_CC"]}'], cwd=oracle)
            qbe = oracle / 'qbe'
        for index, seed in enumerate(seeds):
            work = root / str(seed)
            work.mkdir()
            try:
                total += case(work, seed, options.functions, options.steps, options.samples, qbe,
                              index == 0, not options.straight_line, options.optimize)
                print(f'fuzz seed {seed}: passed', flush=True)
            except Exception:
                target = options.artifacts / f'{"optimized-" if options.optimize else ""}seed-{seed}'
                target.mkdir(parents=True, exist_ok=True)
                for path in work.iterdir():
                    if path.suffix in ('.ssa', '.c', '.s', '.json', '.txt'):
                        shutil.copy2(path, target / path.name)
                (target / 'failure.txt').write_text(traceback.format_exc())
                print(f'FUZZ FAILURE seed={seed}; retained {target}', flush=True)
                print((work / 'input.ssa').read_text(), flush=True)
                raise
    paths = 'Python / Lean interpreter / Lean native / QBE native' if qbe else 'Python / Lean interpreter; native not measured'
    if qbe and options.optimize: paths += ' / Lean optimized native'
    print(f'fuzz: {len(seeds)} seeds, {len(seeds) * options.functions} generated functions, {total} input cases; {paths}')
    if qbe: print('fuzz negative control: corrupted emitted return detected')


if __name__ == '__main__':
    main()
