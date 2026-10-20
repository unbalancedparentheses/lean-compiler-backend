#!/usr/bin/env python3
"""Exercise QBE unquoted names through module, block and operand boundaries."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

SOURCE = '''data $.data$value = { l 41 }
data $pointer.v1 = { l $.data$value }
function l $.inner$function(l %arg.1$value) {
@.entry$block
 %value.copy =l copy %arg.1$value
 %condition$0 =w ceql %value.copy, 1
 jnz %condition$0, @left.part, @right$part
@left.part
 jmp @.join
@right$part
 jmp @.join
@.join
 %phi$value =l phi @left.part $.data$value, @right$part $.data$value
 %loaded.value =l load %phi$value
 %sum$value =l add %loaded.value, %arg.1$value
 ret %sum$value
}
export function l $names_entry() {
@entry
 %r =l call $.inner$function(l 1)
 ret %r
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=0)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    with tempfile.TemporaryDirectory(prefix='lcb-names-') as directory:
        work = Path(directory)
        source, asm, caller = work/'input.ssa', work/'lean.s', work/'caller.c'
        source.write_text(SOURCE)
        caller.write_text('extern unsigned long long names_entry(void); int main(void) {return names_entry()!=42;}')
        run([LCB, '--check', source])
        run([LCB, source, '-o', asm])
        assert int(run([LCB, '--eval', source, 'names_entry'])) == 42
        for i, name in enumerate(['bad;name', 'bad:name', '9bad', 'bad/name', 'bad-name', 'caf\u00e9']):
            invalid = work/f'bad{i}.ssa'
            invalid.write_text(f'function l ${name}() {{ @s ret 0 }}')
            reject([LCB, '--check', invalid], 'unsupported name')
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
                run([exe])
    print('names: dotted/dollar identifiers and malformed-name rejection passed; ' +
          ('native Lean/QBE/C passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
