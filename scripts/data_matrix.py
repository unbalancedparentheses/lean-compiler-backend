#!/usr/bin/env python3
"""Seeded packed-data byte comparison across Python, Lean interpretation and native QBE/C."""
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


def cases(seed):
    strings = [
        ('hello # { world }, + = ( )', b'hello # { world }, + = ( )'),
        (r'quote:\" slash:\\ tab:\t nl:\n cr:\r', b'quote:" slash:\\ tab:\t nl:\n cr:\r'),
        (r'\000\001\177\200\377', bytes([0, 1, 127, 128, 255])),
        ('caf\u00e9', 'caf\u00e9'.encode()),
        (r'\7\07\007X', bytes([7, 7, 7, 88])),
        ('', b''),
        ('first\n# literal, { punctuation }\nlast', b'first\n# literal, { punctuation }\nlast'),
        ('\n\n', b'\n\n'),
        ('crlf\r\nnext', b'crlf\r\nnext'),
        ('caf\u00e9\n\U0001f680', 'caf\u00e9\n\U0001f680'.encode()),
        ('before\n' + r'\"quoted\"' + '\nafter', b'before\n"quoted"\nafter'),
    ]
    result = [(f'b "{text}", b 0', data + b'\0', 8) for text, data in strings]
    rng = random.Random(seed)
    for _ in range(28):
        fields, expected = [], bytearray()
        for _ in range(rng.randrange(1, 9)):
            width = rng.choice([1, 2, 4, 8])
            count = rng.randrange(1, 3)
            values = [rng.choice([-1, -(1 << 63), (1 << 64)-1, rng.getrandbits(64)]) for _ in range(count)]
            fields.append(f'{ {1:"b",2:"h",4:"w",8:"l"}[width]} ' + ' '.join(map(str, values)))
            for value in values:
                expected.extend((value % (1 << (8*width))).to_bytes(width, 'little'))
        padding = rng.randrange(4)
        fields.append(f'z {padding}')
        expected.extend(bytes(padding))
        result.append((', '.join(fields), bytes(expected), rng.choice([1, 2, 4, 8, 16, 32, 64])))
    return result


def checksum(values):
    result = 0
    for value in values:
        result = (result * 131 + value) & MASK
    return result


def fixture(matrix):
    source, declarations, checks = [], [], []
    for case, (fields, expected, alignment) in enumerate(matrix):
        name = f'data_{case}'
        source.append(f'export data ${name} = align {alignment} {{ {fields} }} # outside comment\n')
        body = [f'export function l $hash_{case}() {{\n@start\n']
        previous = '0'
        for i in range(len(expected)):
            body += [f' %p{i} =l add ${name}, {i}\n %v{i} =l loadub %p{i}\n',
                     f' %m{i} =l mul {previous}, 131\n %r{i} =l add %m{i}, %v{i}\n']
            previous = f'%r{i}'
        body.append(f' ret {previous}\n}}\n')
        source.extend(body)
        declarations += [f'extern unsigned char {name}[];\nextern uint64_t hash_{case}(void);\n',
                         f'static const unsigned char expected_{case}[] = {{'+','.join(map(str, expected))+'};\n']
        checks.append(f'if (memcmp({name}, expected_{case}, {len(expected)}) || '
                      f'((uintptr_t){name} % {alignment}) || hash_{case}() != UINT64_C({checksum(expected)})) return {case+1};\n')
    caller = '#include <stdint.h>\n#include <string.h>\n#include <stdio.h>\n' + ''.join(declarations)
    caller += 'int main(void) {\n' + ''.join(checks) + 'puts("data matrix passed"); return 0; }\n'
    return ''.join(source), caller


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261020)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    matrix = cases(options.seed)
    with tempfile.TemporaryDirectory(prefix='lcb-data-matrix-') as directory:
        work = Path(directory)
        source, caller, asm = work/'input.ssa', work/'caller.c', work/'lean.s'
        text, ctext = fixture(matrix)
        source.write_text(text)
        caller.write_text(ctext)
        run([LCB, '--check', source])
        run([LCB, '--target', 'aarch64-macos', source, '-o', asm])
        for i, (_, values, _) in enumerate(matrix):
            assert int(run([LCB, '--eval', source, f'hash_{i}'])) == checksum(values), i
        for i, (text, diagnostic) in enumerate([
            ('data $x = { w "bad" }', 'requires b'),
            (r'data $x = { b "\x01" }', 'unsupported string escape'),
            (r'data $x = { b "\777" }', 'exceeds one byte'),
            ('data $x = { b "unfinished }', 'unterminated data string'),
            ('data $x = { b "unfinished\n# still inside the string\n}', 'unterminated data string'),
            ('data $x = { b "a\nb" }\ninvalid\n', "line 3 near 'invalid'"),
        ]):
            bad = work/f'bad{i}.ssa'
            bad.write_text(text)
            reject([LCB, '--check', bad], diagnostic)
        if native_host():
            cc = os.environ.get('LCB_CC', 'clang')
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qasm = work/'qbe.s'
            # QBE passes strings directly to the assembler: literal line breaks
            # have assembler-specific behavior (Apple's assembler inserts space
            # before a leading '#'). Keep Lean's input raw and encode only these
            # bytes as escapes for the QBE reference; C checks every actual byte.
            qsource = work/'qbe-reference.ssa'
            qmatrix = [(fields.replace('\r', r'\r').replace('\n', r'\n'), expected, alignment)
                       for fields, expected, alignment in matrix]
            qsource.write_text(fixture(qmatrix)[0])
            run([oracle/'qbe', '-t', 'arm64_apple', '-o', qasm, qsource])
            for label, assembly in [('lean', asm), ('qbe', qasm)]:
                exe = work/label
                run([cc, '-std=c11', '-O2', caller, assembly, '-o', exe])
                assert run([exe]).strip() == 'data matrix passed'
    print(f'data matrix seed {options.seed}: {len(matrix)} objects, {sum(len(x[1]) for x in matrix)} exact bytes; '
          'Python/Lean checks passed; ' + ('native Lean/QBE/C passed (QBE multiline reference uses escaped line breaks)' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
