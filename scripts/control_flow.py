#!/usr/bin/env python3
"""Independent C oracle for constant CFG/phi cleanup and retained dynamic edges."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host


def fixture():
    source = []
    declarations = []
    checks = []
    for i in range(32):
        condition = [0, 1, 4294967296, -4294967296, 4294967297, -1][i % 6]
        take_left = condition & 0xffffffff != 0
        chosen = i + (17 if take_left else 93)
        source.append(f'''export function l $cfg_{i}(l %x) {{
@s
 jnz {condition}, @left, @right
@left
 jmp @merge
@right
 jmp @merge
@merge
 %v =l phi @left {i+17}, @right {i+93}
 %known =w ceql %v, {chosen}
 jnz %known, @live, @trap
@trap
 call $unexpected()
 %bad =l div 1, 0
 ret %bad
@live
 %base =l mul %x, 3
 %test =w and %x, 1
 jnz %test, @odd, @even
@odd
 %duplicate_odd =l mul %x, 3
 %a =l add %duplicate_odd, %v
 jmp @done
@even
 %duplicate_even =l mul %x, 3
 %b =l xor %duplicate_even, %v
 jmp @done
@done
 %r =l phi @odd %a, @even %b
 ret %r
}}
''')
        declarations.append(f'extern uint64_t cfg_{i}(uint64_t);')
        for x in [0, 1, 42, 43, (1 << 64)-1, 1 << 63]:
            base = (x * 3) & ((1 << 64)-1)
            expected = ((base + chosen) if x & 1 else (base ^ chosen)) & ((1 << 64)-1)
            checks.append(f'if(cfg_{i}(UINT64_C({x}))!=UINT64_C({expected}))return {i+1};')
    source.append("""export function l $unreachable_predecessor(l %x) {
@s
 %v =l add %x,17
 jmp @join
@dead
 call $unexpected()
 jmp @join
@join
 %p =l phi @s %v,@dead 123
 %r =l add %p,%v
 ret %r
}
export function l $unreachable_mutable(l %x) {
@s
 %v =l add %x,17
 jmp @join
@dead
 %v =l copy 123
 jmp @join
@join
 %v =l add %v,1
 ret %v
}
""")
    declarations += ['extern uint64_t unreachable_predecessor(uint64_t);',
                     'extern uint64_t unreachable_mutable(uint64_t);']
    for x in [0, 1, (1 << 64)-1]:
        checks += [f'if(unreachable_predecessor(UINT64_C({x}))!=UINT64_C({((x+17)*2)&((1<<64)-1)}))return 40;',
                   f'if(unreachable_mutable(UINT64_C({x}))!=UINT64_C({(x+18)&((1<<64)-1)}))return 41;']
    c = '#include <stdint.h>\n#include <stdlib.h>\nvoid unexpected(void){abort();}\n'
    c += '\n'.join(declarations) + '\nint main(void){\n' + '\n'.join(checks) + '\nreturn 0;}\n'
    return ''.join(source), c


def exercise(compiler, work, run, cc, target, execute=True, optimized_only=False):
    case = Path(work)/'control-flow'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    text, c = fixture()
    source.write_text(text)
    caller.write_text(c)
    for optimized in ([True] if optimized_only else [False, True]):
        label = 'optimized' if optimized else 'baseline'
        assembly = case/(label+'.s')
        result = run([compiler, source, '--target', target, *(['--optimize'] if optimized else []), '-o', assembly])
        assert result.returncode == 0, result.stderr
        if optimized:
            emitted = assembly.read_text()
            assert 'unexpected' not in emitted, 'unreachable call retained'
            assert emitted.count('mul') == 32, 'dominating common multiplications were not shared'
        if execute:
            result = run([cc, caller, assembly, '-o', case/label], True)
            assert result.returncode == 0, result.stderr
            result = run([case/label], True)
            assert result.returncode == 0, (label, result.returncode, result.stderr)
    print(f'{target}: CFG/phi cleanup, word conditions, live dynamic edges, common expressions; 198 independent cases, unreachable predecessor normalization; execution={execute}', flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    args = ap.parse_args()
    if args.require_native:
        assert native_host()
    def run(cmd, inside=False):
        return subprocess.run(list(map(str, cmd)), text=True, capture_output=True, timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-cfg-') as directory:
        exercise(LCB, Path(directory), run, os.environ.get('LCB_CC', 'cc'), 'aarch64-macos', native_host())


if __name__ == '__main__':
    main()
