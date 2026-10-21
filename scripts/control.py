#!/usr/bin/env python3
"""Native/differential QBE CFG tests, including parallel phi cycles and loops."""
import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host, compile_and_run


@dataclass
class Case:
    name: str
    bits: int
    body: str
    reference: object

    def source(self):
        width = 'w' if self.bits == 32 else 'l'
        body = self.body.replace('TYPE', width).replace('SUFFIX', width)
        return f'export function {width} ${self.name}({width} %a, {width} %b, {width} %n) {{\n{body}\n}}\n'


def cases():
    result = []
    for bits in (32, 64):
        mask = (1 << bits) - 1
        result += [
            Case(f'choose{bits}', bits, '''@entry
 jnz %n, @yes, @no
@yes
 %left =TYPE add %a, 1
 jmp @merge
@no
 %right =TYPE sub %b, 1
 jmp @merge
@merge
 %value =TYPE phi @yes %left, @no %right
 ret %value''', lambda a,b,n,m=mask: ((a+1) if n & 0xffffffff else (b-1)) & m),
            Case(f'sum{bits}', bits, '''@entry
 %limit =TYPE and %n, 127
 jmp @loop
@loop
 %i =TYPE phi @entry 0, @body %next
 %acc =TYPE phi @entry 0, @body %added
 %condition =w cultSUFFIX %i, %limit
 jnz %condition, @body, @end
@body
 %added =TYPE add %acc, %i
 %next =TYPE add %i, 1
 jmp @loop
@end
 ret %acc''', lambda a,b,n: (n & 127) * ((n & 127)-1) // 2),
            Case(f'swap{bits}', bits, '''@entry
 %limit =TYPE and %n, 31
 jmp @loop
@loop
 %x =TYPE phi @entry %a, @body %y
 %y =TYPE phi @entry %b, @body %x
 %i =TYPE phi @entry 0, @body %next
 %condition =w cultSUFFIX %i, %limit
 jnz %condition, @body, @end
@body
 %next =TYPE add %i, 1
 jmp @loop
@end
 %scaled =TYPE mul %y, 17
 %value =TYPE xor %x, %scaled
 ret %value''', lambda a,b,n,m=mask: ((b ^ (a*17)) if n & 1 else (a ^ (b*17))) & m),
            Case(f'critical{bits}', bits, '''@entry
 jnz %n, @merge, @other
@other
 %changed =TYPE add %b, 5
 jmp @merge
@merge
 %value =TYPE phi @entry %a, @other %changed
 ret %value''', lambda a,b,n,m=mask: (a if n & 0xffffffff else b+5) & m),
            Case(f'same{bits}', bits, '''@entry
 jnz %n, @merge, @merge
@merge
 %value =TYPE phi @entry %a
 ret %value''', lambda a,b,n: a),
            Case(f'fall{bits}', bits, '''@entry
 %next =TYPE add %a, 1
@done
 ret %next''', lambda a,b,n,m=mask: (a+1) & m),
        ]
    # Names that collided with naive function/block-label concatenation.
    result += [Case('collision_a_b',64,'@entry\n jmp @c\n@c\n ret %a',lambda a,b,n:a),
               Case('collision_a',64,'@entry\n jmp @b_c\n@b_c\n ret %b',lambda a,b,n:b)]
    return result


def rejected(work):
    cases = {
        'target': ('@entry\n jmp @missing', 'unknown block'),
        'entry_target': ('@entry\n jmp @entry', 'entry block'),
        'duplicate_label': ('@entry\n ret 0\n@entry\n ret 1', 'duplicate block'),
        'nondominating': ('''@entry
 jnz %n, @yes, @no
@yes
 %v =l copy 7
 jmp @merge
@no
 jmp @merge
@merge
 ret %v''', 'does not dominate'),
        'use_before': ('@entry\n %v =l add %future,1\n %future =l copy 2\n ret %v', 'does not precede'),
        'phi_missing': ('@entry\n jnz %n,@yes,@merge\n@yes\n jmp @merge\n@merge\n %v =l phi @yes 1\n ret %v', 'predecessors exactly'),
        'phi_duplicate': ('@entry\n jmp @merge\n@merge\n %v =l phi @entry 1,@entry 2\n ret %v', 'predecessors exactly'),
        'phi_unknown': ('@entry\n jmp @merge\n@merge\n %v =l phi @missing 1\n ret %v', 'predecessors exactly'),
        'phi_undefined': ('@entry\n jmp @merge\n@merge\n %v =l phi @entry %missing\n ret %v', 'undefined temporary'),
        'entry_phi': ('@entry\n %v =l phi @entry 1\n ret %v', 'predecessors exactly'),
        'late_phi': ('@entry\n jmp @merge\n@merge\n %a =l copy 0\n %v =l phi @entry 1\n ret %v', 'phi definitions must precede'),
        'phi_width': ('@entry\n %a =w copy 1\n jmp @merge\n@merge\n %v =l phi @entry %a\n ret %v', 'w-to-l'),
    }
    for name, (body, diagnostic) in cases.items():
        path, output = work / f'{name}.ssa', work / f'{name}.s'
        path.write_text(f'function l $bad(l %n) {{\n{body}\n}}\n')
        found = subprocess.run([str(LCB), '--target', 'aarch64-macos', str(path), '-o', str(output)], text=True, capture_output=True, timeout=20)
        assert found.returncode != 0 and diagnostic in found.stderr, (name, found.stderr)
        assert not output.exists(), name
    path = work / 'infinite.ssa'
    path.write_text('function w $infinite() {\n@entry\n jmp @loop\n@loop\n jmp @loop\n}\n')
    found = subprocess.run([str(LCB), '--eval', str(path), 'infinite'], text=True, capture_output=True, timeout=20)
    assert found.returncode != 0 and 'budget exhausted' in found.stderr, found.stderr
    print(f'CFG negative controls: {len(cases)} plus explicit interpreter budget exhaustion')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    options = parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    functions, rng = cases(), random.Random(20261018)
    arguments = [(0,0,0),(1,2,1),((1<<64)-1,1,127),(1,2,1<<32),(1<<63,1,31)]
    arguments += [(rng.getrandbits(64), rng.getrandbits(64), rng.getrandbits(64)) for _ in range(128)]
    expected, interpreted = [], 0
    with tempfile.TemporaryDirectory(prefix='lcb-control-') as directory:
        work = Path(directory)
        rejected(work)
        source, asm, cfile = work/'input.ssa', work/'lean.s', work/'caller.c'
        source.write_text(''.join(f.source() for f in functions))
        run([LCB, '--check', source])
        run([LCB, '--target', 'aarch64-macos', source, '-o', asm])
        lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
        for f in functions:
            ctype = f'uint{f.bits}_t'
            lines.append(f'extern {ctype} {f.name}({ctype},{ctype},{ctype});')
        lines.append('int main(void) {')
        for f in functions:
            mask = (1 << f.bits) - 1
            for index, values in enumerate(arguments):
                a,b,n = [v & mask for v in values]
                wanted = f.reference(a,b,n)
                expected.append(wanted)
                if index < 12:
                    found = int(run([LCB,'--eval',source,f.name,a,b,n]))
                    assert found == wanted, (f.name,a,b,n,found,wanted)
                    interpreted += 1
                args = ','.join(f'(uint{f.bits}_t)UINT64_C({v})' for v in values)
                lines.append(f'printf("%" PRIu64 "\\n", (uint64_t){f.name}({args}));')
        cfile.write_text('\n'.join(lines + ['return 0;', '}'])+'\n')
        if native_host():
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make','-j2',f'CC={os.environ["LCB_CC"]}'],cwd=oracle)
            qbe_asm = work/'qbe.s'
            run([oracle/'qbe','-t','arm64_apple','-o',qbe_asm,source])
            for label, assembly in [('lean',asm),('qbe',qbe_asm)]:
                actual = compile_and_run(os.environ['LCB_CC'],assembly,cfile,work/label)
                assert actual == expected, (label,next((i for i,pair in enumerate(zip(actual,expected)) if pair[0]!=pair[1]),None))
            halt = work/'halt.ssa'
            halt.write_text('export function w $halt() {\n@entry\n hlt\n}\n')
            run([LCB, '--target', 'aarch64-macos',halt,'-o',work/'halt.s'])
            cfile.write_text('extern unsigned halt(void); int main(void) { return halt(); }\n')
            run([os.environ['LCB_CC'],cfile,work/'halt.s','-o',work/'halt'])
            stopped = subprocess.run([str(work/'halt')],capture_output=True,timeout=20)
            assert stopped.returncode < 0, 'hlt must terminate, not return'
    print(f'CFG matrix: {len(functions)} functions, {interpreted} interpreter cases; '
          + (f'{len(expected)} native cases per backend; hlt termination checked' if native_host() else 'native not measured'))


if __name__ == '__main__': main()
