#!/usr/bin/env python3
"""Qualify direct integer calls against Python, native C and pinned QBE.

The supported ABI is Apple ARM64 with up to eight w/l arguments and one w/l
result. External calls have native checks, but no invented interpreter result.
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import time
import traceback
from fuzz import ROOT, LCB, run, native_host, compile_and_run, inputs

MASK = (1 << 64) - 1
WEIGHTS = (1, 3, 5, 7, 11, 13, 17, 19)


@dataclass
class Case:
    name: str
    bits: int
    body: str
    expected: object
    reference: str

    def source(self):
        w = 'w' if self.bits == 32 else 'l'
        return f'export function {w} ${self.name}(l %a,l %b) {{\n{self.body}\n}}\n'


COMMON = '''function l $constant() {
@entry
 ret 18446744073709551601
}
function l $mix2(l %a,l %b) {
@entry
 %m =l mul %a,3
 %r =l xor %m,%b
 ret %r
}
function w $word(w %a,w %b) {
@entry
 %m =w mul %a,3
 %r =w add %m,%b
 ret %r
}
function l $fac(l %n) {
@entry
 %small =w culel %n,1
 jnz %small,@base,@recur
@base
 ret 1
@recur
 %less =l sub %n,1
 %rest =l call $fac(l %less)
 %r =l mul %n,%rest
 ret %r
}
function l $even(l %n) {
@entry
 %zero =w ceql %n,0
 jnz %zero,@base,@recur
@base
 ret 1
@recur
 %less =l sub %n,1
 %r =l call $odd(l %less)
 ret %r
}
function l $odd(l %n) {
@entry
 %zero =w ceql %n,0
 jnz %zero,@base,@recur
@base
 ret 0
@recur
 %less =l sub %n,1
 %r =l call $even(l %less)
 ret %r
}
function l $poke(l %p,l %v) {
@entry
 %own =l alloc16 16
 storel %v,%own
 %old =l load %p
 %r =l add %old,%v
 storel %r,%p
 %kept =l load %own
 ret %kept
}
function $noop() {
@entry
 ret
}
export function $void_root() {
@entry
 call $noop()
 ret
}
function $void_acc(l %p,l %n) {
@entry
 %done =w ceql %n,0
 jnz %done,@end,@recur
@recur
 %old =l load %p
 %updated =l add %old,%n
 storel %updated,%p
 %less =l sub %n,1
 call $void_acc(l %p,l %less)
 ret
@end
 ret
}
function $void_word(l %p,w %v,l %bias) {
@entry
 %wide =l extuw %v
 %result =l xor %wide,%bias
 storel %result,%p
 ret
}
'''


def weight_helpers():
    source, reference = [], []
    for bits in (32, 64):
        w, ctype = ('w' if bits == 32 else 'l'), f'uint{bits}_t'
        parameters = ','.join(f'{w} %p{i}' for i in range(8))
        lines = [f'function {w} $weight{bits}({parameters}) {{', '@entry']
        previous = '0'
        for i, weight in enumerate(WEIGHTS):
            lines += [f' %m{i} ={w} mul %p{i},{weight}', f' %s{i} ={w} add {previous},%m{i}']
            previous = f'%s{i}'
        source.append('\n'.join(lines + [f' ret {previous}', '}']))
        expression = '+'.join(f'({ctype})({weight}*({ctype})p{i})' for i, weight in enumerate(WEIGHTS))
        reference.append(f'{ctype} weight{bits}(' + ','.join(f'{ctype} p{i}' for i in range(8))
                         + f') {{ return ({ctype})({expression}); }}')
    return '\n'.join(source), '\n'.join(reference)


def fixed_cases():
    mix = lambda a, b: ((3 * a) ^ b) & MASK
    return [
        Case('zero_args', 64, '@entry\n %r =l call $constant()\n ret %r',
             lambda a, b: MASK - 14, 'return UINT64_MAX-14;'),
        Case('live_across', 64, '''@entry
 %keep =l xor %a,1311768467463790320
 %x =l call $mix2(l %b,l %a)
 %y =l call $mix2(l %x,l %keep)
 %z =l xor %y,%a
 %r =l add %z,%b
 ret %r''', lambda a, b: ((mix(mix(b, a), a ^ 0x123456789abcdef0) ^ a) + b) & MASK,
             'uint64_t keep=a^UINT64_C(0x123456789abcdef0); return (((3*((3*b)^a))^keep)^a)+b;'),
        Case('word_call', 64, '''@entry
 %r =w call $word(w %b,w %a)
 %extended =l extuw %r
 %out =l xor %extended,%a
 ret %out''', lambda a, b: (((3*b+a) & 0xffffffff) ^ a),
             'return (uint64_t)(uint32_t)(3*(uint32_t)b+(uint32_t)a)^a;'),
        Case('factorial_call', 64, '''@entry
 %low =l and %a,15
 %n =l add %low,1
 %r =l call $fac(l %n)
 ret %r''', lambda a, b: math.factorial((a & 15) + 1),
             'uint64_t r=1; for(uint64_t i=2;i<=(a&15)+1;++i) r*=i; return r;'),
        Case('mutual_call', 64, '''@entry
 %n =l and %a,31
 %r =l call $even(l %n)
 ret %r''', lambda a, b: int(a % 2 == 0), 'return (a&1)==0;'),
        Case('memory_call', 64, '''@entry
 %p =l alloc16 16
 %q =l add %p,8
 storel %a,%p
 storel %b,%q
 %unused =l call $poke(l %p,l %b)
 %other =l call $poke(l %q,l %a)
 %x =l load %p
 %y =l load %q
 %sum =l add %x,%y
 %r =l xor %sum,%other
 ret %r''', lambda a, b: (((a+b)*2) & MASK) ^ a,
             'return (2*(a+b))^a;'),
        Case('loop_calls', 64, '''@entry
 %limit =l and %b,15
 jmp @loop
@loop
 %i =l phi @entry 0,@body %next
 %acc =l phi @entry %a,@body %updated
 %more =w cultl %i,%limit
 jnz %more,@body,@end
@body
 %updated =l call $mix2(l %acc,l %i)
 %next =l add %i,1
 jmp @loop
@end
 ret %acc''', loop_expected,
             'for(uint64_t i=0;i<(b&15);++i) a=(3*a)^i; return a;'),
        Case('branch_calls', 64, '''@entry
 %test =w and %a,1
 jnz %test,@yes,@no
@yes
 %left =l call $mix2(l %a,l %b)
 jmp @join
@no
 %right =l call $mix2(l %b,l %a)
 jmp @join
@join
 %value =l phi @yes %left,@no %right
 %r =l call $mix2(l %value,l %a)
 ret %r''', lambda a, b: mix(mix(a, b) if a & 1 else mix(b, a), a),
             'uint64_t v=(a&1)?((3*a)^b):((3*b)^a); return (3*v)^a;'),
        Case('void_recursive', 64, '''@entry
 %p =l alloc8 8
 storel %a,%p
 %n =l and %b,15
 call $void_acc(l %p,l %n)
 call $void_root()
 %r =l load %p
 ret %r''', lambda a,b: (a+(b&15)*((b&15)+1)//2)&MASK,
             'uint64_t n=b&15; return a+n*(n+1)/2;'),
        Case('void_word_arg', 64, '''@entry
 %p =l alloc8 8
 call $void_word(l %p,w %a,l %b)
 %r =l load %p
 ret %r''', lambda a,b: (a&0xffffffff)^b,
             'return (uint64_t)(uint32_t)a^b;'),
    ]


def loop_expected(a, b):
    for i in range(b & 15): a = ((3 * a) ^ i) & MASK
    return a


def generated_case(seed, index):
    rng = random.Random(seed * 65537 + index)
    bits, bias = (32 if index % 2 else 64), rng.getrandbits(64)
    w, mask, ctype = ('w' if bits == 32 else 'l'), (1 << bits) - 1, f'uint{bits}_t'
    first = [rng.choice(['%a', '%b', str(rng.getrandbits(64))]) for _ in range(8)]
    second = [rng.choice(['%a', '%b', '%x', str(rng.getrandbits(64))]) for _ in range(8)]
    def expected(a, b):
        values = {'%a': a, '%b': b}
        def weighted(operands):
            return sum(weight * ((values[v] if v.startswith('%') else int(v)) & mask)
                       for weight, v in zip(WEIGHTS, operands)) & mask
        values['%x'] = weighted(first)
        return (values['%x'] ^ weighted(second) ^ (a ^ bias)) & mask
    args = lambda operands: ','.join(f'{w} {v}' for v in operands)
    body = f'''@entry
 %keep =l xor %a,{bias}
 %x ={w} call $weight{bits}({args(first)})
 %y ={w} call $weight{bits}({args(second)})
 %z ={w} xor %x,%y
 %r ={w} xor %z,%keep
 ret %r'''
    cvalue = lambda v: f'({ctype})' + (v[1:] if v.startswith('%') else f'UINT64_C({v})')
    reference = (f'{ctype} x=weight{bits}(' + ','.join(map(cvalue, first)) + ');'
                 + f'{ctype} y=weight{bits}(' + ','.join(map(cvalue, second)) + ');'
                 + f'return ({ctype})(x^y^(a^UINT64_C({bias})));')
    return Case(f'calls_{seed}_{index}', bits, body, expected, reference)


def caller(cases, arguments):
    lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
    lines.append('extern void void_root(void);')
    for case in cases: lines.append(f'extern uint{case.bits}_t {case.name}(uint64_t,uint64_t);')
    lines.append('int main(void) { void_root();')
    for case in cases:
        for a, b in arguments:
            lines.append(f'printf("%" PRIu64 "\\n", (uint64_t){case.name}(UINT64_C({a}),UINT64_C({b})));')
    return '\n'.join(lines + ['return 0;', '}']) + '\n'


def controls(work):
    base = 'function l $f(l %a) { @s ret %a }\n'
    bad = [
        '%r =w call $f(l 1)', '%r =l call $f()', '%r =l call $f(w 1)',
        '%r =l call $f(l %missing)', '%r =l call %a(l 1)',
        '%r =l call $f(l 1,)', '%r =l call $f(...)', '%r =l call $f(d 1)',
        '%r =sb call $f(l 1)', '%r =l call $f(' + ','.join('l 1' for _ in range(9)) + ')',
    ]
    source = work/'control.ssa'
    for operation in bad:
        source.write_text(base + 'function l $bad(l %a) { @s ' + operation + ' ret 0 }')
        result = subprocess.run([LCB, '--check', source], text=True, capture_output=True, timeout=30)
        assert result.returncode and 'error:' in result.stderr, operation
    void_bad = [
        'function $v() { @s ret } function l $f() { @s %r =l call $v() ret %r }',
        base + 'function $v() { @s call $f(l 0) ret }',
        'function $v() { @s ret 1 }', 'function l $f() { @s ret }',
        'function $v(l %p) { @s ret } function $f() { @s call $v() ret }',
        'function $v(l %p) { @s ret } function $f() { @s call $v(w 0) ret }',
    ]
    for text in void_bad:
        source.write_text(text)
        result = subprocess.run([LCB,'--check',source],text=True,capture_output=True,timeout=30)
        assert result.returncode and 'error:' in result.stderr, text
    source.write_text(COMMON)
    assert run([LCB,'--eval',source,'void_root']).strip() == 'void'
    undefined = [
        ('function l $f() { @s %r =l call $f() ret %r }', 'f', 'call-depth budget exhausted'),
        ('function l $f() { @s %r =l call $external() ret %r }', 'f', 'no interpreter model'),
        ('function l $dangling() { @s %p =l alloc8 8 storel 99,%p ret %p }\n'
         'function l $f() { @s %p =l call $dangling() %r =l load %p ret %r }', 'f', 'outside an allocated object'),
        ('''function l $busy(l %n) {
@s
 jmp @loop
@loop
 %i =l phi @s 0,@body %next
 %more =w cultl %i,%n
 jnz %more,@body,@end
@body
 %next =l add %i,1
 jmp @loop
@end
 ret %i
}
function l $f() { @s %x =l call $busy(l 30000) %y =l call $busy(l 30000) ret %y }
''', 'f', 'block-step budget exhausted'),
    ]
    for text, name, diagnostic in undefined:
        source.write_text(text)
        result = subprocess.run([LCB, '--eval', source, name], text=True, capture_output=True, timeout=30)
        assert result.returncode and diagnostic in result.stderr, (diagnostic, result.stderr)
    return len(bad) + len(void_bad) + len(undefined)


EXTERNAL = '''export function l $external_entry(l %a,l %b) {
@entry
 %p =l alloc16 8
 storel %a,%p
 %keep =l xor %a,1311768467463790320
 %x =l call $external_mix(l %b,l %a,l 3,l 5,l 7,l 11,l 13,l 17)
 %y =w call $external_word(w %a,w %b)
 %wide =l extuw %y
 call $external_store(l %p,w %b)
 %written =l load %p
 %z =l xor %x,%keep
 %sum =l add %z,%wide
 %r =l xor %sum,%written
 ret %r
}
'''


def external_calls(work, qbe, arguments):
    source, cfile = work/'external.ssa', work/'external.c'
    source.write_text(EXTERNAL)
    # The external callee checks alignment, consumes all eight integer registers,
    # then deliberately overwrites caller-saved registers and condition flags.
    helper = ['.text', '.globl _external_mix', '.p2align 2', '_external_mix:',
              '\tmov x9, sp', '\ttst x9, #15', '\tb.ne L_bad_alignment',
              '\teor x0, x0, x1', '\tadd x0, x0, x2', '\tadd x0, x0, x3',
              '\tadd x0, x0, x4', '\tadd x0, x0, x5', '\tadd x0, x0, x6', '\tadd x0, x0, x7']
    helper += [f'\tmov x{i}, #{100+i}' for i in range(1, 18)]
    helper += ['\tcmp x1,x2', '\tret', 'L_bad_alignment:', '\tmov x0,#0', '\tret']
    # An assembly caller keeps sentinels in every callee-saved integer register.
    # x19 holds the original SP, checking both its preservation and stack balance.
    helper += ['.globl _probe_saved', '.p2align 2', '_probe_saved:',
               '\tstp x19,x20,[sp,#-112]!']
    helper += [f'\tstp x{i},x{i+1},[sp,#{(i-19)*8}]' for i in range(21,31,2)]
    helper += ['\tmov x19,sp'] + [f'\tmov x{i},#{100+i}' for i in range(20,30)]
    helper += ['\tbl _external_entry', '\tmov x0,#0', '\tmov x9,sp',
               '\tcmp x19,x9', '\tb.ne L_saved_bad']
    for i in range(20,30): helper += [f'\tcmp x{i},#{100+i}', '\tb.ne L_saved_bad']
    helper += ['\tb L_saved_done', 'L_saved_bad:', '\tmov x0,#1', 'L_saved_done:']
    helper += [f'\tldp x{i},x{i+1},[sp,#{(i-19)*8}]' for i in range(21,31,2)]
    helper += ['\tldp x19,x20,[sp],#112', '\tret']
    helper_asm = work/'external-helper.s'
    helper_asm.write_text('\n'.join(helper) + '\n')
    c_helpers = '''#include <stdint.h>
#include <string.h>
uint32_t external_word(uint32_t a,uint32_t b) { return 3*a+b; }
void external_store(uint64_t p,uint32_t v) {
 uint64_t value; memcpy(&value,(void*)(uintptr_t)p,8);
 value=(value&UINT64_C(0xffffffff00000000))|v;
 memcpy((void*)(uintptr_t)p,&value,8);
}
'''
    cfile.write_text(c_helpers + '''
#include <stdio.h>
#include <inttypes.h>
extern uint64_t external_entry(uint64_t,uint64_t);
extern uint64_t probe_saved(uint64_t,uint64_t);
int main(void) {
''' + '\n'.join(f'printf("%" PRIu64 "\\n", external_entry(UINT64_C({a}),UINT64_C({b}))); '
                 f'if(probe_saved(UINT64_C({a}),UINT64_C({b}))) return 4;'
                 for a, b in arguments) + '\nreturn 0; }\n')
    expected = [((((a^b)+56)&MASK) ^ (a^0x123456789abcdef0)) + ((3*a+b)&0xffffffff)
                for a,b in arguments]
    expected = [(value & MASK) ^ ((a&0xffffffff00000000)|(b&0xffffffff))
                for value,(a,b) in zip(expected,arguments)]
    for label, oracle in [('lean', None), ('qbe', qbe)]:
        asm = work/f'external-{label}.s'
        run([LCB, source, '-o', asm] if oracle is None else [oracle,'-t','arm64_apple','-o',asm,source])
        executable = work/f'external-{label}'
        run([os.environ['LCB_CC'], '-std=c11','-O2',cfile,asm,helper_asm,'-o',executable])
        actual = [int(line) for line in run([executable]).splitlines()]
        assert actual == expected, ('external ABI',label)
    # A corrupted caller must fail when the C helper overwrites caller-saved x9.
    asm = work/'external-lean.s'
    text = asm.read_text()
    changed = text.replace('\tbl _external_mix\n', '\tbl _external_mix\n\tstr xzr, [sp, #0]\n')
    assert changed != text
    corrupt = work/'external-corrupt.s'
    corrupt.write_text(changed)
    executable = work/'external-corrupt'
    run([os.environ['LCB_CC'],'-std=c11','-O2',cfile,corrupt,helper_asm,'-o',executable])
    assert [int(line) for line in run([executable]).splitlines()] != expected
    # Qualify the assembly caller too: corrupt a callee-saved register in lcb's
    # function and require the guard's own failure code, not an unrelated crash.
    changed = text.replace('_external_entry:\n', '_external_entry:\n\tmov x19,#0\n')
    assert changed != text
    corrupt.write_text(changed)
    guard = work/'saved-guard.c'
    guard.write_text(c_helpers +
        'extern uint64_t probe_saved(uint64_t,uint64_t);\n'
        'int main(void) { return probe_saved(1,2) ? 4 : 0; }\n')
    run([os.environ['LCB_CC'],'-std=c11','-O2',guard,corrupt,helper_asm,'-o',executable])
    result = subprocess.run([executable],text=True,capture_output=True,timeout=30)
    assert result.returncode == 4, 'callee-saved guard did not catch x19 corruption'
    return len(expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, action='append')
    options = parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    seeds = options.seed or [20261018,20261019]
    cases = fixed_cases() + [generated_case(seed,index) for seed in seeds for index in range(8)]
    arguments = inputs(20261018,64)
    helpers, reference_helpers = weight_helpers()
    expected = [case.expected(a,b) for case in cases for a,b in arguments]
    interpreted = 0
    with tempfile.TemporaryDirectory(prefix='lcb-calls-') as directory:
        work = Path(directory)
        source, asm, cfile = work/'input.ssa',work/'lean.s',work/'caller.c'
        source.write_text(COMMON + helpers + '\n' + ''.join(case.source() for case in cases))
        (work/'case.json').write_text(json.dumps({'seeds':seeds, 'arguments':arguments, 'expected':expected,
            'compiler_sha256':hashlib.sha256(LCB.read_bytes()).hexdigest(),
            'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'upstream_lock_sha256':hashlib.sha256((ROOT/'upstream-lock.json').read_bytes()).hexdigest(),
            'flake_lock_sha256':hashlib.sha256((ROOT/'flake.lock').read_bytes()).hexdigest()},indent=2))
        try:
            rejected = controls(work)
            run([LCB,'--check',source])
            run([LCB,source,'-o',asm])
            for case in cases:
                for a,b in arguments[:8]:
                    found = int(run([LCB,'--eval',source,case.name,a,b]))
                    assert found == case.expected(a,b), (case.name,a,b,found,case.expected(a,b))
                    interpreted += 1
            native = native_host()
            if native:
                oracle = work/'oracle'
                shutil.copytree(ROOT/'third_party/qbe',oracle)
                run(['make','-j2',f'CC={os.environ["LCB_CC"]}'],cwd=oracle)
                qasm = work/'qbe.s'
                run([oracle/'qbe','-t','arm64_apple','-o',qasm,source])
                cfile.write_text(caller(cases,arguments))
                for label, assembly in [('lean',asm),('qbe',qasm)]:
                    actual = compile_and_run(os.environ['LCB_CC'],assembly,cfile,work/label)
                    (work/f'{label}-output.json').write_text(json.dumps(actual))
                    assert actual == expected, (label,next((i for i,pair in enumerate(zip(actual,expected)) if pair[0]!=pair[1]),None))
                reference = work/'reference.c'
                reference.write_text('#include <stdint.h>\nvoid void_root(void) {}\n' + reference_helpers + '\n'
                    + '\n'.join(f'uint{case.bits}_t {case.name}(uint64_t a,uint64_t b) {{ {case.reference} }}' for case in cases)
                    + '\n' + caller(cases,arguments))
                run([os.environ['LCB_CC'],'-std=c11','-O2',reference,'-o',work/'reference'])
                assert [int(line) for line in run([work/'reference']).splitlines()] == expected
                external = external_calls(work,oracle/'qbe',arguments)
        except Exception:
            target = ROOT/'.build/calls-failures'/f'run-{time.time_ns()}'
            target.mkdir(parents=True,exist_ok=True)
            for path in work.iterdir():
                if path.suffix in ('.ssa','.s','.c','.json'): shutil.copy2(path,target/path.name)
            (target/'failure.txt').write_text(traceback.format_exc())
            print(f'CALL FAILURE: retained {target}',flush=True)
            raise
    print(f'calls: {len(cases)} entry functions ({len(seeds)*8} generated), {interpreted} interpreter cases, '
          f'{rejected} rejection/undefined-domain controls; '
          + (f'{len(expected)} native cases per Lean/QBE/C backend; {external} external ABI cases per backend; '
             'live-value and callee-saved corruption detected' if native else 'native not measured'))


if __name__ == '__main__': main()
