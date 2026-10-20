#!/usr/bin/env python3
"""Compare aggregate sizes, alignments and field offsets with compiled C probes."""
import argparse
import os
import random
import shutil
import subprocess
import tempfile
from pathlib import Path
from fuzz import LCB, run

CT = {'b': 'unsigned char', 'h': 'unsigned short', 'w': 'unsigned int',
      'l': 'unsigned long long', 's': 'float', 'd': 'double'}


def fixture(seed):
    rng = random.Random(seed)
    il, declarations, probes = [], [], []
    # Include unions with differently sized/aligned variants, nested arrays and
    # explicit over-alignment. Later generated types refer only to earlier ones.
    for i in range(80):
        name = f't{i}'
        variants = []
        for _ in range(rng.randint(2, 4) if i % 4 == 0 else 1):
            fields = []
            for _ in range(rng.randint(1, 6)):
                kind = rng.choice(list(CT) + ([f':t{rng.randrange(i)}'] if i else []))
                fields.append((kind, rng.randint(1, 4)))
            variants.append(fields)
        align = 16 if i % 9 == 0 else None
        bodies = [', '.join(f'{k} {n}' for k, n in v) for v in variants]
        body = bodies[0] if len(bodies) == 1 else ' '.join('{ ' + b + ' }' for b in bodies)
        il.append(f'type :{name} = ' + (f'align {align} ' if align else '') + '{ ' + body + ' }')
        cvariants = []
        for v, fields in enumerate(variants):
            cf = [f'{CT.get(k, k[1:])} f{j}[{n}];' for j, (k, n) in enumerate(fields)]
            cvariants.append(' '.join(cf))
        body = cvariants[0] if len(cvariants) == 1 else ' '.join(
            f'struct {{ {b} }} v{v};' for v, b in enumerate(cvariants))
        tag = 'struct' if len(variants) == 1 else 'union'
        attr = f' __attribute__((aligned({align})))' if align else ''
        declarations.append(f'typedef {tag}{attr} {{ {body} }} {name};')
        probes.append(f'printf("type {name} %zu %zu\\n", sizeof({name}), _Alignof({name}));')
        for v, fields in enumerate(variants):
            for j, (kind, count) in enumerate(fields):
                path = f'f{j}' if len(variants) == 1 else f'v{v}.f{j}'
                ctype = CT.get(kind, kind[1:])
                probes.append(f'printf("field {name} {v} {j} %zu %zu {count}\\n", '
                              f'offsetof({name}, {path}), sizeof({ctype}));')
    c = '#include <stdio.h>\n#include <stddef.h>\n' + '\n'.join(declarations)
    c += '\nint main(void) {\n' + '\n'.join(probes) + '\nreturn 0;\n}\n'
    return '\n'.join(il), c


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    ap.add_argument('--seed', type=int, default=20261020)
    args = ap.parse_args()
    cc = os.environ.get('CC', 'cc')
    with tempfile.TemporaryDirectory(prefix='lcb-layout-') as tmp:
        root = Path(tmp)
        source = root / 'layout.ssa'
        il, c = fixture(args.seed)
        source.write_text(il)
        actual = run([LCB, '--type-layout', source])
        if shutil.which(cc):
            (root / 'layout.c').write_text(c)
            run([cc, '-std=c11', '-Wall', '-Wextra', '-Werror', root / 'layout.c', '-o', root / 'probe'])
            expected = run([root / 'probe'])
            assert actual == expected, 'aggregate layout differs from independent C sizeof/alignof/offsetof'
            # Ensure this oracle would detect a wrong field offset.
            corrupted = actual.splitlines()
            tokens = corrupted[1].split()
            tokens[4] = str(int(tokens[4]) + 1)
            corrupted[1] = ' '.join(tokens)
            assert '\n'.join(corrupted) + '\n' != expected
        elif args.require_native:
            raise AssertionError('C compiler required for aggregate layout probes')
        else:
            print('C layout comparison unavailable: no C compiler')

        # QBE-specific layouts that standard C cannot express faithfully.
        source.write_text('''type :raw = align 8 { 3 }
type :nested = { b, :raw 2, h, }
type :zero = { b, d 0, b }
type :minimum = align 1 { d }
type :u = { { b 9 } { d } }
''')
        assert run([LCB, '--type-layout', source]) == '''type raw 3 8
type nested 16 8
field nested 0 0 0 1 1
field nested 0 1 8 3 2
field nested 0 2 14 2 1
type zero 16 8
field zero 0 0 0 1 1
field zero 0 1 8 8 0
field zero 0 2 8 1 1
type minimum 8 8
field minimum 0 0 0 8 1
type u 16 8
field u 0 0 0 1 9
field u 1 0 0 8 1
'''
        invalid = [
            'type :x = { :later } type :later = { w }',
            'type :x = { :x }', 'type :x = { w } type :x = { l }',
            'type :x = { 8 }', 'type :x = align 3 { w }',
            'type :x = align 0 { w }', 'type :x = align 131072 { w }',
            'type :x = { w -1 }', 'type :x = { w 1048577 }',
            'type :x = { l 131073 }', 'type :x = align 8 { 1048577 }',
            'type :x = { w l }', 'type :x = { { w }, { l } }',
            'type :x = { sb }', 'export type :x = { w }',
            'type :x = { w } function :x $f() { @s ret 0 }',
        ]
        for text in invalid:
            source.write_text(text)
            result = subprocess.run([LCB, '--check', source], capture_output=True, text=True)
            assert result.returncode != 0, f'invalid aggregate accepted: {text}'
        source.write_text('type :x = { w } function w $f() { @s ret 42 }')
        assert run([LCB, '--eval', source, 'f']).strip() == '42'
        assert '_f:' in run([LCB, source])
        assert subprocess.run([LCB, '--first-path', source], capture_output=True).returncode != 0
    print('aggregate layouts: 80 generated C comparisons, QBE-specific layouts and 16 rejection controls passed')


if __name__ == '__main__':
    main()
