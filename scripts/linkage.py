#!/usr/bin/env python3
"""Exercise Apple custom sections, common definitions and linker coalescing."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

SOURCE = '''export common data $shared = align 8 { z 8 }
section "__DATA" "__custom_data"
export data $custom_value = align 8 { l 40 }
section "__TEXT" "__custom_code"
export function l $custom_entry() {
@start
 %v =l loadl $custom_value
 %sum =l add %v, 2
 storel %sum, $shared
 ret %sum
}
export function l $ordinary_entry() {
@start
 %v =l call $custom_entry()
 ret %v
}
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    args = ap.parse_args()
    if args.require_native:
        assert native_host()
    with tempfile.TemporaryDirectory(prefix='lcb-linkage-') as directory:
        work = Path(directory)
        source, asm = work/'input.ssa', work/'lean.s'
        source.write_text(SOURCE)
        run([LCB, '--check', source]); run([LCB, source, '-o', asm])
        assert int(run([LCB, '--eval', source, 'ordinary_entry'])) == 42
        text = asm.read_text()
        assert '.comm _shared,8,3' in text
        assert '.section __TEXT,__custom_code' in text
        assert text.index('.text', text.index('; function ordinary_entry')) < text.index('_ordinary_entry:')
        for content, reason in [
            (SOURCE.replace('{ z 8 }', '{ l 0 }'), 'only zero-fill'),
            (SOURCE.replace('export common data', 'common thread data'), 'thread data'),
            (SOURCE.replace('export common data', 'common section "__DATA,__x" data'), 'common data'),
            (SOURCE.replace('export common data', 'common common data'), 'duplicate common'),
            (SOURCE.replace('export function l $ordinary', 'common function l $ordinary'), 'requires data'),
            (SOURCE.replace('__custom_code', 'this_section_name_is_too_long'), '1..16 ASCII'),
            (SOURCE.replace('__custom_code', r'bad\n.globl _oops'), 'ASCII'),
            (SOURCE.replace('__custom_code', '__custom_code,unknown_type'), 'section type'),
            (SOURCE.replace('__custom_code', '__custom_code,regular,unknown_flag'), 'section attribute'),
            (SOURCE.replace('section "__DATA"', 'section "__DATA" "__x" section "__DATA"'), 'duplicate section'),
        ]:
            bad = work/'bad.ssa'; bad.write_text(content)
            reject([LCB, '--check', bad], reason)
        if native_host():
            cc = os.environ.get('LCB_CC', 'cc')
            oracle = work/'oracle'; shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qasm = work/'qbe.s'; run([oracle/'qbe', '-t', 'arm64_apple', '-o', qasm, source])
            caller, other = work/'caller.c', work/'other.s'
            caller.write_text('''#include <stdint.h>
extern uint64_t shared[4], custom_value, ordinary_entry(void);
int main(void) { shared[3]=99; return ordinary_entry()!=42 || shared[0]!=42 || shared[3]!=99 || custom_value!=40; }
''')
            other.write_text('.comm _shared,32,3\n')
            objdump = shutil.which('llvm-objdump')
            for label, assembly in [('lean', asm), ('qbe', qasm)]:
                obj, exe = work/f'{label}.o', work/label
                run([cc, '-c', assembly, '-o', obj])
                sections = run([objdump, '--section-headers', obj] if objdump else ['otool', '-l', obj])
                for name in ['__custom_data', '__custom_code', '__text']:
                    assert name in sections, sections
                run([cc, caller, obj, other, '-o', exe]); run([exe])
            attributed = work/'attributed.ssa'
            attributed.write_text(SOURCE.replace('"__custom_data"', '"__custom_data,regular,no_dead_strip"')
                                  .replace('"__TEXT" "__custom_code"', '"__TEXT,__custom_code,regular,pure_instructions"'))
            run([LCB, attributed, '-o', asm])
            run([cc, caller, asm, other, '-o', work/'attributed']); run([work/'attributed'])
            # Darwin .comm alignment is a logarithm, unlike ELF's byte count.
            aligned = work/'aligned.ssa'; aligned.write_text('common data $aligned = align 64 { z 64 }')
            run([LCB, aligned, '-o', asm])
            assert '.comm _aligned,64,6' in asm.read_text()
            probe = work/'align.c'; probe.write_text('#include <stdint.h>\nextern char aligned[64]; int main(void) {return (uintptr_t)aligned%64;}')
            run([cc, probe, asm, '-o', work/'align']); run([work/'align'])
    print('linkage: custom code/data sections, default-section restoration, common zero-fill and invalid-linkage controls passed; ' +
          ('native Lean/QBE/C, object sections, common coalescing and 64-byte alignment passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
