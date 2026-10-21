#!/usr/bin/env python3
"""Dynamic stack objects across loops, calls, stack arguments and frame restoration."""
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
SOURCE = '''function $fill(l %p,l %v,w %a,w %b,l %c,w %d,l %e,l %f,w %g,l %h,w %i,l %j) {
@entry
 %a64 =l extuw %a
 %b64 =l extuw %b
 %d64 =l extuw %d
 %g64 =l extuw %g
 %i64 =l extuw %i
 %s0 =l add %v, %a64
 %s1 =l add %s0, %b64
 %s2 =l add %s1, %c
 %s3 =l add %s2, %d64
 %s4 =l add %s3, %e
 %s5 =l add %s4, %f
 %s6 =l add %s5, %g64
 %s7 =l add %s6, %h
 %s8 =l add %s7, %i64
 %s9 =l add %s8, %j
 %slot =l add %p, 8
 storel %s9, %slot
 ret
}
data $fill_ptr = { l $fill }
export function l $dynamic_list(l %size,l %count,l %seed) {
@entry
 %sentinel =l alloc16 16
 storel %seed, %sentinel
 %fn =l load $fill_ptr
 %empty =w ceql %count, 0
 jnz %empty, @done, @build
@build
 %index =l phi @entry 0, @build %next_index
 %head =l phi @entry %sentinel, @build %object
 %object =l alloc8 %size
 storel %head, %object
 call %fn(l %object,l %index,w 1,w 2,l 3,w 4,l 5,l 6,w 7,l 8,w 9,l %seed)
 %next_index =l add %index, 1
 %more =w cultl %next_index, %count
 jnz %more, @build, @walk
@walk
 %cursor =l phi @build %object, @walk %next
 %acc =l phi @build 0, @walk %sum
 %slot =l add %cursor, 8
 %value =l load %slot
 %sum =l add %acc, %value
 %next =l load %cursor
 %last =w ceql %next, %sentinel
 jnz %last, @finish, @walk
@finish
 %initial =l load %sentinel
 %result =l add %sum, %initial
 ret %result
@done
 %zero_result =l load %sentinel
 ret %zero_result
}
export function l $dynamic_external(l %fn,l %size,l %value) {
@entry
 %object =l alloc4 %size
 storel 123, %object
 call %fn(l %object,l %value,w 1,w 2,l 3,w 4,l 5,l 6,w 7,l 8,w 9,l %value)
 %slot =l add %object, 8
 %result =l load %slot
 %guard =l load %object
 %sum =l add %result, %guard
 ret %sum
}
export function l $dynamic_leaf(l %size,l %value) {
@entry
 %p =l alloc16 %size
 %offset =l sub %size, 8
 %last =l add %p, %offset
 storel %value, %last
 %result =l load %last
 ret %result
}
export function l $probe_dynamic(l %size) {
@entry
 %p =l alloc16 %size
 storel 42, %p
 %ok =l call $frame_probe()
 %value =l load %p
 %result =l add %value, %ok
 ret %result
}
'''
PROBE = '''.text
.globl _guard_dynamic
.p2align 2
_guard_dynamic:
 stp x29, x30, [sp, #-32]!
 str x19, [sp, #16]
 mov x29, sp
 mov x19, sp
 bl _probe_dynamic
 mov x9, sp
 cmp x9, x19
 b.ne L_dynamic_bad
 cmp x29, x19
 b.eq L_dynamic_restore
L_dynamic_bad:
 mov x0, #-1
L_dynamic_restore:
 mov sp, x19
 ldr x19, [sp, #16]
 ldp x29, x30, [sp], #32
 ret
.globl _frame_probe
.p2align 2
_frame_probe:
 ldr x9, [x29]
 cmp x9, x19
 cset w0, eq
 ret
'''
C_PREFIX = '''#include <stdint.h>
#include <stdio.h>
extern uint64_t dynamic_list(uint64_t,uint64_t,uint64_t), dynamic_leaf(uint64_t,uint64_t);
extern uint64_t dynamic_external(uintptr_t,uint64_t,uint64_t), guard_dynamic(uint64_t);
static int aligned = 1;
static void callback(uint64_t *p,uint64_t v,uint32_t a,uint32_t b,uint64_t c,uint32_t d,
                     uint64_t e,uint64_t f,uint32_t g,uint64_t h,uint32_t i,uint64_t j) {
 uintptr_t sp;
 __asm__ volatile("mov %0, sp" : "=r"(sp));
 if (sp & 15) aligned = 0;
 p[1] = v+a+b+c+d+e+f+g+h+i+j;
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261020)
    options = parser.parse_args()
    if options.require_native:
        assert native_host(), 'required native host unavailable'
    rng = random.Random(options.seed)
    matrix = [(size, count, rng.getrandbits(64)) for size in [16, 17, 31, 32, 4095, 4096, 4097, 65536]
              for count in [0, 1, 3, 8]]
    with tempfile.TemporaryDirectory(prefix='lcb-dynamic-') as directory:
        work = Path(directory)
        source, asm, caller, probe = work/'input.ssa', work/'lean.s', work/'caller.c', work/'probe.s'
        source.write_text(SOURCE)
        probe.write_text(PROBE)
        run([LCB, '--target', 'aarch64-macos', source, '-o', asm])
        checks = []
        for size, count, seed in matrix:
            wanted = (seed * (count+1) + 45*count + count*(count-1)//2) & MASK
            assert int(run([LCB, '--eval', source, 'dynamic_list', size, count, seed])) == wanted
            assert int(run([LCB, '--eval', source, 'dynamic_leaf', size, seed])) == seed
            checks.append(f'if (dynamic_list({size},{count},UINT64_C({seed})) != UINT64_C({wanted}) || '
                          f'dynamic_leaf({size},UINT64_C({seed})) != UINT64_C({seed})) return 1;\n')
            callback_wanted = (2*seed + 45 + 123) & MASK
            checks.append(f'if (dynamic_external((uintptr_t)callback,{size},UINT64_C({seed})) != UINT64_C({callback_wanted}) || !aligned) return 2;\n')
            checks.append(f'if (guard_dynamic({size}) != 43) return 3;\n')
        caller.write_text(C_PREFIX + 'int main(void) {\n' + ''.join(checks) + 'puts("dynamic allocation passed"); return 0;}\n')
        reject([LCB, '--eval', source, 'dynamic_leaf', 0, 1], 'outside an allocated object')
        reject([LCB, '--eval', source, 'dynamic_leaf', 1048577, 1], 'memory budget')
        if native_host():
            cc = os.environ.get('LCB_CC', 'clang')
            oracle = work/'oracle'
            shutil.copytree(ROOT/'third_party/qbe', oracle)
            run(['make', '-j2', f'CC={cc}'], cwd=oracle)
            qasm = work/'qbe.s'
            run([oracle/'qbe', '-t', 'arm64_apple', '-o', qasm, source])
            for label, assembly in [('lean', asm), ('qbe', qasm)]:
                exe = work/label
                run([cc, '-std=c11', '-O2', '-fno-omit-frame-pointer', caller, assembly, probe, '-o', exe])
                assert run([exe]).strip() == 'dynamic allocation passed'
            mutant = work/'mutant.s'
            changed = asm.read_text().replace('\tstr x9, [sp, #24]', '\tstr xzr, [sp, #24]')
            assert changed != asm.read_text(), 'missing dynamic outgoing stack argument'
            mutant.write_text(changed)
            run([cc, '-std=c11', '-O2', '-fno-omit-frame-pointer', caller, mutant, probe, '-o', work/'mutant'])
            result = subprocess.run([work/'mutant'], capture_output=True, timeout=30)
            assert result.returncode in (1, 2), 'dynamic stack argument corruption escaped checks'
    print(f'dynamic allocation: {2*len(matrix)} interpreter cases, two runtime-domain refusals; ' +
          ('native Lean/QBE/C loops, callbacks, stack arguments and SP/FP record/restoration checks passed' if native_host() else 'native not measured'))


if __name__ == '__main__':
    main()
