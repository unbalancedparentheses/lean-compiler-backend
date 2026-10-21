#!/usr/bin/env python3
"""Independent allocation constraints and native pressure/parallel-copy cases."""
import argparse
import copy
import json
import os
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


def fixture():
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
export function l $dynamic(l %n,l %x) {
@s
 %p =l alloc16 %n
 storel %x,%p
 call $clobber()
 %v =l loadl %p
 %r =l add %v,%x
 ret %r
}''']
    caller = '''#include <stdint.h>
extern uint64_t pressure(uint64_t*), swap(uint64_t,uint64_t,unsigned), deadwrite(uint64_t,uint64_t), chain(uint64_t), dynamic(uint64_t,uint64_t);
volatile uint64_t barrier;
__attribute__((noinline)) void clobber(void) { barrier++; }
int main(void) {
 uint64_t a[48],sum=0;
 for(unsigned i=0;i<48;i++){a[i]=UINT64_C(0xf123456789abcd)*i+17;sum+=a[i];}
 if(pressure(a)!=sum)return 1;
 for(unsigned i=1;i<33;i++)if(swap(17,93,i)!=(i%2?17-93:93-17ULL))return 2;
 if(deadwrite(17,93)!=17-93ULL)return 3;
 for(unsigned i=0;i<100;i++)if(chain(i)!=(((i+7)*3)^92))return 4;
 if(dynamic(8192,UINT64_C(0xf123456789abcdef))!=UINT64_C(0xe2468acf13579bde))return 5;
 return 0;
}'''
    return '\n'.join(lines), caller


def exercise(compiler, work, run, cc, target, execute=True, optimized_only=False):
    case = Path(work)/'allocation'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    text, c = fixture()
    source.write_text(text)
    caller.write_text(c)
    for label, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize'])]:
        assembly = case/(label+'.s')
        result = run([compiler, source, '--target', target, *flags, '-o', assembly])
        assert result.returncode == 0, result.stderr
        if execute:
            result = run([cc, caller, assembly, '-o', case/label], True)
            assert result.returncode == 0, result.stderr
            result = run([case/label], True)
            assert result.returncode == 0, (target, label, result.returncode, result.stderr)
    print(f'{target}: allocation pressure, calls, parallel phi swaps, dead writes, dynamic frames; execution={execute}', flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    ap.add_argument('--oracle-only', action='store_true')
    args = ap.parse_args()
    oracle()
    if args.oracle_only:
        return
    if args.require_native:
        assert native_host()
    def run(cmd, inside=False):
        return subprocess.run(list(map(str, cmd)), text=True, capture_output=True, timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-allocation-') as directory:
        exercise(LCB, Path(directory), run, os.environ.get('LCB_CC', 'cc'), 'aarch64-macos', native_host())


if __name__ == '__main__':
    main()
