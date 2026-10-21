#!/usr/bin/env python3
"""Defined-domain comparisons for QBE integer operations, extensions and comparisons.

The Python specification is independent of the Lean definitions. Native callers
exercise actual assembly from both backends. Division by zero and signed MIN/-1
are excluded from equivalence inputs and separately rejected by the interpreter.
"""
import argparse
from dataclasses import dataclass
import os
import random
import shutil
import tempfile
from pathlib import Path
from fuzz import ROOT, LCB, run, native_host, compile_and_run, binary


def signed(value, bits):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value >= (1 << (bits - 1)) else value


@dataclass
class Spec:
    op: str
    result_bits: int
    input_bits: int
    unary: bool = False

    @property
    def name(self): return f'{self.op}_{self.result_bits}'

    def source(self):
        result = 'w' if self.result_bits == 32 else 'l'
        operand = 'w' if self.input_bits == 32 else 'l'
        parameters = f'{operand} %a' + ('' if self.unary else f', {operand} %b')
        arguments = '%a' + ('' if self.unary else ', %b')
        return f'export function {result} ${self.name}({parameters}) {{\n@entry\n %v ={result} {self.op} {arguments}\n ret %v\n}}\n'

    def defined(self, a, b):
        if self.op in ('div', 'rem', 'udiv', 'urem'):
            if b == 0: return False
            if self.op in ('div', 'rem') and a == (1 << (self.input_bits - 1)) and b == (1 << self.input_bits) - 1:
                return False
        return True

    def evaluate(self, a, b):
        mask = (1 << self.result_bits) - 1
        if self.op in ('shl', 'shr', 'sar'): return binary(self.op, a, b, mask)
        if self.op == 'neg': return -a & mask
        if self.op in ('extsb', 'extsh', 'extsw'):
            bits = {'extsb': 8, 'extsh': 16, 'extsw': 32}[self.op]
            return signed(a, bits) & mask
        if self.op in ('extub', 'extuh', 'extuw'):
            bits = {'extub': 8, 'extuh': 16, 'extuw': 32}[self.op]
            return a & ((1 << bits) - 1)
        if self.op == 'udiv': return a // b
        if self.op == 'urem': return a % b
        if self.op in ('div', 'rem'):
            sa, sb = signed(a, self.input_bits), signed(b, self.input_bits)
            quotient = (abs(sa) // abs(sb)) * (-1 if (sa < 0) != (sb < 0) else 1)
            return (quotient if self.op == 'div' else sa - quotient * sb) & mask
        stem = self.op[1:-1]
        if stem.startswith('s'): a, b, stem = signed(a, self.input_bits), signed(b, self.input_bits), stem[1:]
        elif stem.startswith('u'): stem = stem[1:]
        comparisons = {'eq': a == b, 'ne': a != b, 'le': a <= b, 'lt': a < b, 'ge': a >= b, 'gt': a > b}
        return int(comparisons[stem])


def specifications():
    specs = []
    for bits in (32, 64):
        specs += [Spec(op, bits, bits) for op in ('shl', 'shr', 'sar', 'div', 'udiv', 'rem', 'urem')]
        specs.append(Spec('neg', bits, bits, True))
        specs += [Spec(op, bits, 32, True) for op in ('extsb', 'extub', 'extsh', 'extuh')]
        for operand_bits, suffix in ((32, 'w'), (64, 'l')):
            specs += [Spec(stem + suffix, bits, operand_bits) for stem in
                      ('ceq', 'cne', 'csle', 'cslt', 'csge', 'csgt', 'cule', 'cult', 'cuge', 'cugt')]
    return specs + [Spec('extsw', 64, 32, True), Spec('extuw', 64, 32, True)]


def vectors(bits):
    mask = (1 << bits) - 1
    edge = [0, 1, mask, mask - 1, 1 << (bits - 1), (1 << (bits - 1)) - 1,
            7, 8, 31, 32, 63, 64, 127, 128, 255, 256, 32767, 32768, 65535, 65536]
    rng = random.Random(20261018 + bits)
    return [(a, b) for a in edge for b in edge] + [(rng.getrandbits(bits), rng.getrandbits(bits)) for _ in range(64)]


def caller(specs, data):
    lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
    for bits, values in data.items():
        lines.append(f'static const uint64_t data{bits}[][2] = {{')
        lines += [f'{{UINT64_C({a}), UINT64_C({b})}},' for a, b in values]
        lines.append('};')
    for spec in specs:
        result = f'uint{spec.result_bits}_t'
        operand = f'uint{spec.input_bits}_t'
        lines.append(f'extern {result} {spec.name}({operand}' + ('' if spec.unary else f', {operand}') + ');')
    lines.append('int main(void) {')
    for spec in specs:
        lines += [f'for (unsigned i=0; i < {len(data[spec.input_bits])}; ++i) {{',
                  f'uint64_t a=data{spec.input_bits}[i][0], b=data{spec.input_bits}[i][1];']
        if spec.op in ('div', 'rem', 'udiv', 'urem'): lines.append('if (b == 0) continue;')
        if spec.op in ('div', 'rem'):
            lines.append(f'if (a == UINT64_C({1 << (spec.input_bits - 1)}) && b == UINT64_C({(1 << spec.input_bits) - 1})) continue;')
        arguments = f'(uint{spec.input_bits}_t)a' + ('' if spec.unary else f', (uint{spec.input_bits}_t)b')
        lines += [f'printf("%" PRIu64 "\\n", (uint64_t){spec.name}({arguments}));', '}']
    return '\n'.join(lines + ['return 0;', '}']) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    options = parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    data, specs = {bits: vectors(bits) for bits in (32, 64)}, specifications()
    count, interpreted = 0, 0
    with tempfile.TemporaryDirectory(prefix='lcb-integer-') as directory:
        work, qbe = Path(directory), None
        if native_host():
            oracle = work / 'oracle'
            shutil.copytree(ROOT / 'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={os.environ["LCB_CC"]}'], cwd=oracle)
            qbe = oracle / 'qbe'
        for batch in range(0, len(specs), 32):
            selected = specs[batch:batch + 32]
            source, asm, cfile = work / 'input.ssa', work / 'lean.s', work / 'caller.c'
            source.write_text(''.join(spec.source() for spec in selected))
            run([LCB, '--check', source])
            assemblies=[]
            for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
                assembly=work/(label+'.s');run([LCB, '--target', 'aarch64-macos',source,*flags,'-o',assembly]);assemblies.append((label,assembly))
            expected = []
            for spec in selected:
                valid = [(a, b) for a, b in data[spec.input_bits] if spec.defined(a, b)]
                expected += [spec.evaluate(a, b) for a, b in valid]
                # Spread interpreter checks across the edge cross-product and
                # random tail, rather than checking only the initial zero row.
                indexes = sorted({0, 1, 2, len(valid) - 1, *range(0, len(valid), max(1, len(valid) // 12))})
                for index in indexes:
                    a, b = valid[index]
                    args = [a] if spec.unary else [a, b]
                    actual = int(run([LCB, '--eval', source, spec.name, *args]))
                    assert actual == spec.evaluate(a, b), (spec, a, b, actual, spec.evaluate(a, b))
                    interpreted += 1
            if qbe:
                cfile.write_text(caller(selected, data))
                qbe_asm = work / 'qbe.s'
                run([qbe, '-t', 'arm64_apple', '-o', qbe_asm, source])
                for label, assembly in [*assemblies, ('qbe', qbe_asm)]:
                    actual = compile_and_run(os.environ['LCB_CC'], assembly, cfile, work / label)
                    assert actual == expected, (label, batch, next((i for i, pair in enumerate(zip(actual, expected)) if pair[0] != pair[1]), None))
            count += len(expected)
        undefined = work / 'undefined.ssa'
        undefined.write_text('function w $div(w %a,w %b) { @s %r =w div %a,%b ret %r }')
        import subprocess
        for a, b in ((1, 0), (1 << 31, (1 << 32) - 1)):
            result = subprocess.run([str(LCB), '--eval', str(undefined), 'div', str(a), str(b)], capture_output=True, text=True, timeout=20)
            assert result.returncode != 0 and 'undefined QBE' in result.stderr
        undefined.write_text('function w $bad(w %a) { @s %r =w extsw %a ret %r }')
        result = subprocess.run([str(LCB), '--check', str(undefined)], capture_output=True, text=True, timeout=20)
        assert result.returncode != 0 and 'require a long result' in result.stderr
    print(f'integer operation matrix: {len(specs)} typed forms, {interpreted} interpreter cases; '
          + (f'{count} native cases per baseline/allocated/optimized/QBE backend' if qbe else 'native not measured'))


if __name__ == '__main__': main()
