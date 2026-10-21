#!/usr/bin/env python3
"""Independent allocation constraints and native pressure/parallel-copy cases."""
import argparse
import copy
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
from fuzz import ROOT, LCB, native_host, generate
from liveness import CASES, check as check_liveness


def check(report):
    live = report['liveness']
    check_liveness(live)
    values, colors = live['values'], report['colors']
    assert len(values) == len(colors)
    assert all(0 <= c < report['colorCount'] for c in colors)
    homes = dict(zip(values, colors))
    def distinct(names):
        names = set(names)
        assert len({homes[n] for n in names}) == len(names), (live['function'], 'overlap', names)
    distinct(report['parameters'])
    for b in live['blocks']:
        distinct(b['liveIn'])
        distinct(b['liveOut'])
        for point in b['before']:
            distinct(point)
        for edge in b['edges']:
            distinct(edge['live'])
        distinct(set(b['before'][0]) | {p['definition'] for p in b['phis']})
        for i, ins in enumerate(b['instructions']):
            if ins['definition'] is not None:
                distinct(set(b['before'][i+1]) | {ins['definition']})


def oracle():
    functions = values = colors = 0
    with tempfile.TemporaryDirectory(prefix='lcb-allocation-oracle-') as directory:
        source = Path(directory)/'small.ssa'
        generated = '\n'.join(f.source().replace('$'+f.name+'(', f'$generated_{seed}(')
                              for seed in range(16) for f in generate(seed, 1, 24, True))
        source.write_text(CASES+generated)
        paths = [source] + [p for p in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')) if p.name != 'dark.ssa']
        for path in paths:
            result = subprocess.run([LCB, '--allocation', path], capture_output=True, text=True, timeout=180)
            assert result.returncode == 0, result.stderr
            for line in result.stdout.splitlines():
                report = json.loads(line)
                check(report)
                functions += 1
                values += len(report['colors'])
                colors += report['colorCount']
                if functions == 1:
                    damaged = copy.deepcopy(report)
                    damaged['colors'] = [0]*len(report['colors'])
                    try:
                        check(damaged)
                    except AssertionError:
                        pass
                    else:
                        raise AssertionError('all-homes-alias corruption accepted')
    print(f'allocation oracle: {functions} functions, {values} values use {colors} homes; original fixtures and corruption check passed', flush=True)


def fixture(target):
    # Opaque call keeps 48 loaded values simultaneously live. No folding/CSE can
    # remove them; caller clobbers and spill/reload paths must preserve every bit.
    lines = ['export function l $pressure(l %p) {', '@s']
    for i in range(48):
        lines += [f'%p{i} =l add %p,{i*8}', f'%v{i} =l loadl %p{i}']
    lines += ['call $clobber()', '%sum0 =l copy %v0']
    for i in range(1, 48):
        lines += [f'%sum{i} =l add %sum{i-1},%v{i}']
    lines += ['ret %sum47', '}']
    lines += ['''export function l $swap(l %x,l %y,w %n) {
@s
 jmp @loop
@loop
 %a =l phi @s %x,@loop %b
 %b =l phi @s %y,@loop %a
 %i =w phi @s 0,@loop %j
 %j =w add %i,1
 %c =w cultw %j,%n
 jnz %c,@loop,@done
@done
 %r =l sub %a,%b
 ret %r
}
export function l $deadwrite(l %x,l %y) {
@s
 %dead =l mul %x,123
 %r =l sub %x,%y
 ret %r
}
export function l $chain(l %x) {
@s
 %a =l add %x,7
 %b =l mul %a,3
 %c =l xor %b,92
 ret %c
}
export function l $shift_mix(l %x,l %count) {
@s
 %a =l shl %x,%count
 %b =l shr %x,%count
 %c =w shl %x,%count
 %wide =l extuw %c
 %r0 =l xor %a,%b
 %r =l xor %r0,%wide
 ret %r
}
export function d $float_keep(d %x,d %y) {
@s
 call $clobber()
 %r =d add %x,%y
 ret %r
}
export function d $float_bits(d %x) {
@s
 %bits =l cast %x
 call $clobber()
 %r =d cast %bits
 ret %r
}
export function l $dynamic(l %n,l %x) {
@s
 %p =l alloc16 %n
 storel %x,%p
 call $clobber()
 %v =l loadl %p
 %r =l add %v,%x
 ret %r
}''']
    if target.startswith('aarch64'):
        saved = [f'x{i}' for i in range(19,29)]
        clobbered = [f'x{i}' for i in range(18)] + [f'v{i}' for i in range(8)]
        destroy = [f'mov x{i}, #123' for i in range(18)] + [f'fmov d{i}, x0' for i in range(8)]
    elif target.startswith('x86_64'):
        saved = ['rbx','r12','r13','r14','r15']
        clobbered = ['rax','rcx','rdx','rsi','rdi','r8','r9','r10','r11'] + [f'xmm{i}' for i in range(16)]
        destroy = [f'movq $123, %%{r}' for r in clobbered[:9]] + [f'pxor %%xmm{i}, %%xmm{i}' for i in range(16)]
    else:
        saved = [f's{i}' for i in range(1,12)]
        clobbered = [f'a{i}' for i in range(8)] + [f't{i}' for i in range(7)] + [f'fa{i}' for i in range(8)] + [f'ft{i}' for i in range(12)]
        destroy = [f'li {r},123' for r in clobbered[:15]] + [f'fmv.d.x {r},a0' for r in clobbered[15:]]
    destroy_asm = '__asm__ volatile("' + r'\n\t'.join(destroy) + '" ::: ' + ','.join('"'+r+'"' for r in clobbered) + ',"memory");'
    probe = '__attribute__((noinline)) static int preserved(uint64_t *p) {\n'
    for i,r in enumerate(saved): probe += f'register uint64_t k{i} __asm__("{r}") = UINT64_C({0x123456789abc0000+i});\n'
    barrier = '__asm__ volatile("" : ' + ','.join(f'"+r"(k{i})' for i in range(len(saved))) + ' :: "memory");\n'
    probe += barrier + '(void)pressure(p);\n' + barrier
    probe += 'return ' + ' && '.join(f'k{i} == UINT64_C({0x123456789abc0000+i})' for i in range(len(saved))) + ';}\n'
    caller = '''#include <stdint.h>
extern uint64_t pressure(uint64_t*), swap(uint64_t,uint64_t,unsigned), deadwrite(uint64_t,uint64_t), chain(uint64_t), dynamic(uint64_t,uint64_t), shift_mix(uint64_t,uint64_t);
extern double float_keep(double,double), float_bits(double);
volatile uint64_t barrier;
__attribute__((noinline)) void clobber(void) { barrier++; DESTROY }
PROBE
int main(void) {
 uint64_t a[48],sum=0;
 for(unsigned i=0;i<48;i++){a[i]=UINT64_C(0xf123456789abcd)*i+17;sum+=a[i];}
 if(pressure(a)!=sum)return 1;
 if(!preserved(a))return 6;
 if(float_keep(1.5,2.25)!=3.75)return 7;
 union {uint64_t u;double d;} in,out;
 in.u=UINT64_C(0x7ff8123456789abc);out.d=float_bits(in.d);if(out.u!=in.u)return 8;
 in.u=UINT64_C(0x8000000000000000);out.d=float_bits(in.d);if(out.u!=in.u)return 9;
 for(unsigned i=1;i<33;i++)if(swap(17,93,i)!=(i%2?17-93:93-17ULL))return 2;
 if(deadwrite(17,93)!=17-93ULL)return 3;
 for(unsigned i=0;i<100;i++)if(chain(i)!=(((i+7)*3)^92))return 4;
 if(dynamic(8192,UINT64_C(0xf123456789abcdef))!=UINT64_C(0xe2468acf13579bde))return 5;
 uint64_t counts[]={0,1,31,32,63,64,UINT64_C(0x100000020),UINT64_C(0x8000000000000000),UINT64_MAX};
 uint64_t values[]={0,17,UINT64_MAX,UINT64_C(0x8000000000000000),UINT64_C(0xf0123456789abcde)};
 for(unsigned j=0;j<5;j++)for(unsigned k=0;k<9;k++) {
  uint64_t x=values[j],n=counts[k];
  uint64_t expected=(x<<(n&63))^(x>>(n&63))^(uint64_t)((uint32_t)x<<(n&31));
  if(shift_mix(x,n)!=expected)return 10;
 }
 return 0;
}'''
    caller = caller.replace('DESTROY',destroy_asm).replace('PROBE',probe)
    return '\n'.join(lines), caller


def exercise(compiler, work, run, cc, target, execute=True, optimized_only=False):
    case = Path(work)/'allocation'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    text, c = fixture(target)
    source.write_text(text)
    caller.write_text(c)
    for label, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize'])]:
        assembly = case/(label+'.s')
        result = run([compiler, source, '--target', target, *flags, '-o', assembly])
        assert result.returncode == 0, result.stderr
        if target.startswith('aarch64') and flags:
            assert re.search(r'\b(?:add|sub|mul|eor|and|orr) [wx](?:19|2[0-8]), [wx](?:19|2[0-8]),', assembly.read_text()), 'allocated integer operations did not use GP homes directly'
        if execute:
            result = run([cc, caller, assembly, '-o', case/label], True)
            assert result.returncode == 0, result.stderr
            result = run([case/label], True)
            assert result.returncode == 0, (target, label, result.returncode, result.stderr)
            if label == 'allocated':
                patterns = {'aarch64': r'^\s*ldr x19, \[.*$',
                            'x86_64': r'^\s*movq -[0-9]+\(%rbp\), %rbx$',
                            'riscv64': r'^\s*ld s1, -?[0-9]+\(s0\)$'}
                pattern = patterns[target.split('-')[0]]
                damaged,count = re.subn(pattern, '\tnop', assembly.read_text(), flags=re.M)
                assert count > 0, 'no callee-save restores found in allocated code'
                broken = case/'broken-save.s'; broken.write_text(damaged)
                result = run([cc, caller, broken, '-o', case/'broken-save'], True)
                assert result.returncode == 0, result.stderr
                result = run([case/'broken-save'], True)
                assert result.returncode != 0, 'callee-save corruption was not detected'
    print(f'{target}: allocation pressure/spills, caller clobbers, callee saves, FP bits, phi swaps, dead writes, dynamic frames; execution={execute}', flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    ap.add_argument('--oracle-only', action='store_true')
    ap.add_argument('--execution-only', action='store_true')
    ap.add_argument('--target', choices=['aarch64-macos','aarch64-linux','x86_64-linux','riscv64-linux'], default='aarch64-macos')
    ap.add_argument('--docker-container')
    args = ap.parse_args()
    if not args.execution_only: oracle()
    if args.oracle_only:
        return
    if args.docker_container:
        assert args.target.endswith('-linux')
        work = ROOT/'.build/linux-arm64'/('allocation-'+args.target)
        work.mkdir(exist_ok=True)
        def run(cmd, inside=False):
            cmd = list(map(str,cmd))
            if inside:
                if cmd[0].startswith(str(work)) and args.target != 'aarch64-linux':
                    isa = args.target.split('-')[0]
                    cmd = [f'qemu-{isa}','-L',f'/usr/{isa}-linux-gnu']+cmd
                cmd = ['docker','exec',args.docker_container]+[x.replace(str(ROOT/'.build/linux-arm64'),'/work') for x in cmd]
            return subprocess.run(cmd,text=True,capture_output=True,timeout=120)
        cc = 'gcc' if args.target=='aarch64-linux' else args.target.split('-')[0]+'-linux-gnu-gcc'
        exercise(LCB,work,run,cc,args.target,True)
        return
    assert args.target == 'aarch64-macos', 'Linux execution needs --docker-container'
    if args.require_native:
        assert native_host()
    def run(cmd, inside=False):
        return subprocess.run(list(map(str, cmd)), text=True, capture_output=True, timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-allocation-') as directory:
        exercise(LCB, Path(directory), run, os.environ.get('LCB_CC', 'cc'), 'aarch64-macos', native_host())


if __name__ == '__main__':
    main()
