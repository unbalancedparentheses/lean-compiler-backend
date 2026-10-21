#!/usr/bin/env python3
"""QBE environment register x9 across ordinary, stack, variadic and indirect arguments."""
import argparse
import os
from pathlib import Path
import random
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

MASK=(1<<64)-1


def fixture():
    params=','.join([f'l %a{i}' for i in range(8)]+['w %a8'])
    source=[f'export function l $environment_target(env %e,{params},...) {{\n@entry\n',
            ' %small =l and %e, 31\n %size =l add %small, 16\n %ap =l alloc16 %size\n vastart %ap\n',
            ' %tail =l vaarg %ap\n %wide =l extuw %a8\n %s0 =l add %e, %wide\n']
    acc='%s0'
    for i in range(8):
        source.append(f' %s{i+1} =l add {acc}, %a{i}\n');acc=f'%s{i+1}'
    source.append(f' %result =l add {acc}, %tail\n ret %result\n}}\n')
    for mode in ['internal','indirect','callback']:
        source.append(f'export function l $env_{mode}('+('l %fn,' if mode=='callback' else '')+'l %seed) {\n@entry\n')
        arguments=['env %seed']
        for i in range(9):
            width='l' if i<8 else 'w'
            source.append(f' %a{i} ={width} add %seed, {i}\n');arguments.append(f'{width} %a{i}')
        source.append(' %tail =l add %seed, 100\n')
        arguments+=['...','l %tail']
        target='$environment_target'
        if mode=='indirect': source.append(' %fn =l copy $environment_target\n')
        if mode!='internal': target='%fn'
        source.append(f' %r =l call {target}('+','.join(arguments)+')\n ret %r\n}\n')
    source.append('''function l $plain(l %v) {
@entry
 %r =l add %v, 7
 ret %r
}
export function l $env_ignored(l %v) {
@entry
 %fn =l copy $plain
 %r =l call %fn(env 999,l %v)
 ret %r
}
''')
    return ''.join(source)


PROBE='''.text
.globl _environment_callback
.p2align 2
_environment_callback:
 add x0, x0, x9
 add x0, x0, x1
 add x0, x0, x2
 add x0, x0, x3
 add x0, x0, x4
 add x0, x0, x5
 add x0, x0, x6
 add x0, x0, x7
 ldr w10, [sp]
 add x0, x0, x10
 ldr x10, [sp, #8]
 add x0, x0, x10
 ret
.globl _call_env_from_c
.p2align 2
_call_env_from_c:
 sub sp, sp, #32
 stp x29, x30, [sp, #16]
 add x29, sp, #16
 mov x9, x0
 mov x0, #1
 mov x1, #2
 mov x2, #3
 mov x3, #4
 mov x4, #5
 mov x5, #6
 mov x6, #7
 mov x7, #8
 mov x10, #9
 str w10, [sp]
 mov x10, #10
 str x10, [sp, #8]
 bl _environment_target
 ldp x29, x30, [sp, #16]
 add sp, sp, #32
 ret
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    parser.add_argument('--seed',type=int,default=20261020)
    options=parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    rng=random.Random(options.seed)
    seeds=[0,1,MASK,1<<63,1<<32]+[rng.getrandbits(64) for _ in range(7)]
    with tempfile.TemporaryDirectory(prefix='lcb-environment-') as directory:
        work=Path(directory)
        source,asm,caller,probe=work/'input.ssa',work/'lean.s',work/'caller.c',work/'probe.s'
        source.write_text(fixture());probe.write_text(PROBE)
        run([LCB, '--target', 'aarch64-macos',source,'-o',asm])
        checks=[]
        for seed in seeds:
            expected=(seed+sum((seed+i)&MASK for i in range(8))+((seed+8)&0xffffffff)+seed+100)&MASK
            for mode in ['internal','indirect']:
                assert int(run([LCB,'--eval',source,f'env_{mode}',seed]))==expected
                checks.append(f'if (env_{mode}(UINT64_C({seed})) != UINT64_C({expected})) return 1;\n')
            assert int(run([LCB,'--eval',source,'env_ignored',seed]))==(seed+7)&MASK
            checks.append(f'if (env_callback((uintptr_t)environment_callback,UINT64_C({seed})) != UINT64_C({expected}) || '
                          f'call_env_from_c(UINT64_C({seed})) != UINT64_C({(seed+55)&MASK}) || '
                          f'env_ignored(UINT64_C({seed})) != UINT64_C({(seed+7)&MASK})) return 2;\n')
        caller.write_text('#include <stdint.h>\n#include <stdio.h>\n'
                          'extern uint64_t env_internal(uint64_t),env_indirect(uint64_t),env_ignored(uint64_t),call_env_from_c(uint64_t);\n'
                          'extern uint64_t env_callback(uintptr_t,uint64_t),environment_callback(void);\n'
                          'int main(void) {\n'+''.join(checks)+'puts("environment passed"); return 0; }\n')
        for i,text in enumerate([
            'function l $f(l %a,env %e) { @s ret %e }',
            'function l $f() { @s %r =l call $g(l 1,env 2) ret %r }',
            'function l $f() { @s %r =l call $g(...,env 2) ret %r }',
            'function l $f(env %e) { @s ret %e } function l $g() { @s %r =l call $f() ret %r }',
        ]):
            bad=work/f'bad{i}.ssa';bad.write_text(text)
            reject([LCB,'--check',bad],'environment')
        restricted=work/'restricted.ssa';restricted.write_text('function l $f(env %e) { @s ret %e }')
        reject([LCB,'--first-path',restricted],'environment parameters')
        if native_host():
            cc=os.environ.get('LCB_CC','clang')
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,source])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label
                run([cc,'-std=c11','-O2',caller,assembly,probe,'-o',exe])
                assert run([exe]).strip()=='environment passed'
    print('environment: 36 interpreter cases; '+('native Lean/QBE and independent x9 ABI probes passed' if native_host() else 'native not measured'))


if __name__=='__main__': main()
