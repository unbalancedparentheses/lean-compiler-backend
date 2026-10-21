#!/usr/bin/env python3
"""Check debug directives survive SSA and produce usable native line tables."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

SOURCE = '''function w $plain() {
@start
 ret 0
}
dbgfile "first source.c"
export function w $debug_entry(w %x) {
@start
 dbgloc 10, 2
 %v =w add %x, 1
 dbgloc 11
 %v =w add %v, 1
 dbgloc 12, 3
 ret %v
}
dbgfile "second.c"
function w $second() {
@start
 dbgloc 20
 ret 7
}
dbgfile "first source.c"
function w $third() {
@start
 dbgloc 30
 ret 9
}
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    args = ap.parse_args()
    if args.require_native:
        assert native_host()
    with tempfile.TemporaryDirectory(prefix='lcb-debug-') as directory:
        work = Path(directory)
        source, asm = work/'input.ssa', work/'lean.s'
        source.write_text(SOURCE)
        run([LCB, '--check', source])
        run([LCB, source, '-o', asm])
        assert int(run([LCB, '--eval', source, 'debug_entry', '40'])) == 42
        text = asm.read_text()
        for location in ['.loc 1 10 2', '.loc 1 11 0', '.loc 1 12 3', '.loc 2 20 0', '.loc 3 30 0']:
            assert location in text, location
        assert text.index('.loc 1 10 2') < text.index('.loc 1 11 0') < text.index('.loc 1 12 3')
        for content, reason in [
            (SOURCE.replace('dbgloc 10, 2', 'dbgloc -1'), 'nonnegative debug line'),
            (SOURCE.replace('dbgloc 10, 2', 'dbgloc 10, -2'), 'nonnegative debug column'),
            (SOURCE.replace('dbgloc 10, 2', 'dbgloc 536870912'), '29-bit'),
            (SOURCE.replace('dbgloc 10, 2', 'dbgloc 1, 536870912'), '29-bit'),
            (SOURCE.replace('dbgfile "first source.c"', '', 1), 'preceding dbgfile'),
            (SOURCE.replace('first source.c', r'bad\000file'), 'NUL'),
        ]:
            bad = work/'bad.ssa'; bad.write_text(content)
            reject([LCB, '--check', bad], reason)
        if native_host():
            cc = os.environ.get('LCB_CC', 'cc')
            oracle = work/'oracle'; shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qasm = work/'qbe.s'
            run([oracle/'qbe', '-t', 'arm64_apple', '-o', qasm, source])
            caller = work/'caller.c'
            caller.write_text('extern int debug_entry(int); int main(void) {return debug_entry(40)!=42;}')
            dwarf = shutil.which('llvm-dwarfdump') or shutil.which('dwarfdump')
            assert dwarf, 'dwarfdump required to validate line tables'
            for label, assembly in [('lean', asm), ('qbe', qasm)]:
                obj, exe = work/f'{label}.o', work/label
                run([cc, '-c', assembly, '-o', obj])
                lines = run([dwarf, '--debug-line', obj])
                for value in ['first source.c', 'second.c']:
                    assert value in lines, lines
                for line in [10, 11, 12, 20, 30]:
                    assert any(row.startswith('0x') and row.split()[1] == str(line) for row in lines.splitlines()), lines
                run([cc, caller, obj, '-o', exe]); run([exe])
    print('debug locations: SSA-preserved source records, filename switches, malformed-input controls and interpretation passed; ' +
          ('native Lean/QBE/C and DWARF line tables passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
