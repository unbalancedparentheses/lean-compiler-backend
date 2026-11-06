#!/usr/bin/env python3
"""First-path native/reference, replay-stability and rejection qualification.

This qualifies the explicitly uncertified typed pipeline, not a preservation proof.
"""
import argparse
from contextlib import contextmanager
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import re
import struct
import time
import traceback
import os
from pathlib import Path
import platform
import shutil
import tempfile

from test import ROOT, LCB, run


@contextmanager
def workspace():
    with tempfile.TemporaryDirectory(prefix='lcb-first-path-') as directory:
        work = Path(directory)
        try:
            yield work
        except Exception:
            retained = ROOT / '.build' / 'first-path-failures' / str(time.time_ns())
            retained.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(work, retained)
            (retained / 'failure.txt').write_text(traceback.format_exc())
            print(f'first-path failure artifacts retained in {retained}')
            raise


def packet_fields(packet):
    position = 0
    def blob():
        nonlocal position
        size, = struct.unpack_from('<Q', packet, position)
        position += 8
        value = packet[position:position+size]
        assert len(value) == size
        position += size
        return value
    assert blob() == b'LCB-artifact'
    version, = struct.unpack_from('<Q', packet, position)
    position += 8
    assert version == 2
    fields = [blob() for _ in range(4)]
    assert position == len(packet)
    return fields


def replay_checks(work, src, functions):
    replay_outputs = {}
    for function in functions:
        name = re.search(r'\$(\w+)', function).group(1)
        job, artifact = work/f'{name}.job', work/f'{name}.artifact'
        run([LCB, '--write-job', src, name, job])
        before = job.read_bytes()
        run([LCB, '--write-job', src, name, job])
        assert job.read_bytes() == before
        replay = run([LCB, '--replay-job', job]).stdout
        replay_outputs[job] = replay
        run([LCB, '--write-artifact', job, artifact])
        assert run([LCB, '--replay-artifact', artifact]).stdout == replay
        ids = dict(line.split(': ', 1) for line in run([LCB, '--job-info', job]).stdout.splitlines())
        assert ids.pop('status') == 'uncertified'
        encoded_job, code, debug, evidence = packet_fields(artifact.read_bytes())
        assert encoded_job == before
        # Code packet starts with its domain/version, then the exact input packet.
        position = 8 + len(b'LCB-code') + 8
        length, = struct.unpack_from('<Q', code, position)
        code_input = code[position+8:position+8+length]
        for key, content in [('code-input',code_input),('code',code),('debug',debug),('evidence',evidence)]:
            assert ids[key] == hashlib.sha256(content).hexdigest(), f'{name}: {key} hash mismatch'
    # Different completion order in independent processes must not affect jobs.
    with ThreadPoolExecutor(max_workers=4) as executor:
        pending = {executor.submit(run, [LCB, '--replay-job', path]): path
                   for path in reversed(list(replay_outputs))}
        for task in as_completed(pending):
            assert task.result().stdout == replay_outputs[pending[task]], 'process schedule changed output'
    # Truncation, version, trailing-byte and altered output rejection across processes.
    broken = work/'broken.artifact'
    packet = artifact.read_bytes()
    for mutation in [packet[:-1], packet+b'\0', packet[:-1]+bytes([packet[-1]^1])]:
        broken.write_bytes(mutation)
        run([LCB, '--replay-artifact', broken], success=False)
    broken_job = work/'broken.job'
    data = bytearray(job.read_bytes())
    data[8+len(b'LCB-job')] = 1  # superseded wire version
    broken_job.write_bytes(data)
    run([LCB, '--replay-job', broken_job], success=False)
    print(f'first-path: {len(functions)} job/artifact roundtrips; all dependency hashes match independent hashlib; corrupt replay rejected')


def high_multiply_assembly(work):
    """High multiplies have no QBE spelling; they are reachable only through
    numbered-source jobs. Build a `mul` job, change only its binary-operation tag
    (FOUNDATIONS tag table) and replay it, so the job validator and canonical
    codec check the edited job like any other."""
    texts = []
    for name, tag, mnemonic in [('mulhu_l', 9, 'umulh'), ('mulhs_l', 10, 'smulh')]:
        src, job = work/f'{name}.ssa', work/f'{name}.job'
        src.write_text(f'export function l ${name}(l %a, l %b) {{\n@entry\n %r =l mul %a, %b\n ret %r\n}}\n')
        run([LCB, '--write-job', src, name, job])
        data = job.read_bytes()
        # destination 2, long, binary, mul, local 0, local 1
        pattern = ((2).to_bytes(8, 'little') + bytes([1, 1, 2, 0]) + (0).to_bytes(8, 'little') +
                   bytes([0]) + (1).to_bytes(8, 'little'))
        assert data.count(pattern) == 1, name
        position = data.index(pattern) + 8 + 2
        job.write_bytes(data[:position] + bytes([tag]) + data[position+1:])
        text = run([LCB, '--replay-job', job]).stdout
        assert f'\t{mnemonic} x9, x9, x10\n' in text and '\tmul ' not in text, name
        texts.append(text)
    # A word high multiply has no AArch64 instruction and must be refused.
    word_src, word_job = work/'mulhw.ssa', work/'mulhw.job'
    word_src.write_text('export function w $mulhw(w %a, w %b) {\n@entry\n %r =w mul %a, %b\n ret %r\n}\n')
    run([LCB, '--write-job', word_src, 'mulhw', word_job])
    data = word_job.read_bytes()
    pattern = ((2).to_bytes(8, 'little') + bytes([0, 1, 2, 0]) + (0).to_bytes(8, 'little') +
               bytes([0]) + (1).to_bytes(8, 'little'))
    assert data.count(pattern) == 1
    position = data.index(pattern) + 8 + 2
    word_job.write_bytes(data[:position] + bytes([9]) + data[position+1:])
    assert 'high multiply' in run([LCB, '--replay-job', word_job], success=False).stderr
    assembly = work/'high.s'
    assembly.write_text(texts[0] + texts[1])
    print('first-path: API-only umulh/smulh jobs replay; word-width high multiply refused')
    return assembly


def high_multiply_harness():
    return '''#include <stdint.h>
#include <stdio.h>
extern uint64_t mulhu_l(uint64_t,uint64_t);
extern int64_t mulhs_l(int64_t,int64_t);
int main(void) {
  uint64_t state = 20261106, edges[] = {0, 1, 2, UINT64_MAX, UINT64_MAX-1, UINT64_C(1)<<63,
    (UINT64_C(1)<<63)-1, (UINT64_C(1)<<63)+1, UINT64_C(1)<<32, UINT32_MAX};
  for (unsigned i=0; i<20000; ++i) {
    uint64_t a, b;
    if (i < 100) { a = edges[i % 10]; b = edges[i / 10]; }
    else {
      state=state*UINT64_C(6364136223846793005)+UINT64_C(1442695040888963407); a = state;
      state=state*UINT64_C(6364136223846793005)+UINT64_C(1442695040888963407); b = state >> (i % 64);
    }
    if (mulhu_l(a,b) != (uint64_t)(((unsigned __int128)a*b)>>64)) return 1;
    if (mulhs_l((int64_t)a,(int64_t)b) != (int64_t)(((__int128)(int64_t)a*(int64_t)b)>>64)) return 2;
  }
  puts("first-path high multiply native checks passed");
}
'''


def fixtures():
    functions = []
    for width in ('w', 'l'):
        for op in ('add', 'sub', 'mul', 'and', 'or', 'xor', 'shl', 'shr', 'sar', 'udiv', 'urem', 'div', 'rem'):
            functions.append(f'export function {width} ${op}_{width}({width} %a, {width} %b) {{\n'
                             f'@entry\n %r ={width} {op} %a, %b\n ret %r\n}}')
        for op in ('ceq', 'cult', 'cule', 'cslt', 'csle'):
            functions.append(f'export function w ${op}_{width}({width} %a, {width} %b) {{\n'
                             f'@entry\n %r =w {op}{width} %a, %b\n ret %r\n}}')
    functions += [
        'export function w $identity(w %x) {\n@entry\n ret %x\n}',
        'export function l $constant() {\n@entry\n %r =l copy -81985529216486896\n ret %r\n}',
        'export function w $branch2() {\n@entry\n jnz 2, @yes, @no\n@yes\n ret 7\n@no\n ret 9\n}',
        'export function w $sameedge() {\n@entry\n jnz 2, @yes, @yes\n@yes\n %x =w phi @entry 19\n ret %x\n}',
        '''export function w $sum(w %n) {
@entry
 jmp @loop
@loop
 %i =w phi @entry 0, @body %next
 %s =w phi @entry 0, @body %total
 %more =w cultw %i, %n
 jnz %more, @body, @exit
@body
 %total =w add %s, %i
 %next =w add %i, 1
 jmp @loop
@exit
 ret %s
}''',
        '''export function w $swap(w %n) {
@entry
 jmp @loop
@loop
 %a =w phi @entry 11, @body %b
 %b =w phi @entry 22, @body %a
 %i =w phi @entry 0, @body %next
 %more =w cultw %i, %n
 jnz %more, @body, @exit
@body
 %next =w add %i, 1
 jmp @loop
@exit
 ret %a
}''',
        '''export function l $mixed(w %n, l %x) {
@entry
 jmp @loop
@loop
 %i =w phi @entry 0, @body %next
 %v =l phi @entry %x, @body %updated
 %more =w cultw %i, %n
 jnz %more, @body, @exit
@body
 %next =w add %i, 1
 %updated =l add %v, 4294967296
 jmp @loop
@exit
 ret %v
}''',
        '''export function l $eight(l %a,l %b,l %c,l %d,l %e,l %f,l %g,l %h) {
@entry
 %s0 =l add %a, %b
 %s1 =l add %c, %d
 %s2 =l add %e, %f
 %s3 =l add %g, %h
 %s4 =l add %s0, %s1
 %s5 =l add %s2, %s3
 %r =l add %s4, %s5
 ret %r
}''',
    ]
    # Largest admitted frame: 255 phi values + 255 staging slots = 4080.
    phis = '\n'.join(f' %p{i} =w phi @entry {i}' for i in range(255))
    functions.append(f'export function w $frame4080() {{\n@entry\n jmp @end\n@end\n{phis}\n ret %p254\n}}')
    return functions


def harness(strict_word_result=True):
    declarations, checks = [], []
    operations = {'add': '+', 'sub': '-', 'mul': '*', 'and': '&', 'or': '|', 'xor': '^', 'ceq': '==', 'cult': '<'}
    for width, ctype in [('w', 'uint32_t'), ('l', 'uint64_t')]:
        for op, symbol in operations.items():
            result = 'uint32_t' if op in ('ceq', 'cult') else ctype
            name = f'{op}_{width}'
            declarations.append(f'extern {result} {name}({ctype},{ctype});')
            checks.append(f'if ({name}(({ctype})a,({ctype})b) != ({result})((({ctype})a) {symbol} (({ctype})b))) return 1;')
        # Same-width counts are reduced modulo the width; sar is arithmetic.
        bits = 32 if width == 'w' else 64
        signed = 'int32_t' if width == 'w' else 'int64_t'
        for op, expression in [('shl', f'(({ctype})a) << ((({ctype})b) % {bits})'),
                               ('shr', f'(({ctype})a) >> ((({ctype})b) % {bits})'),
                               ('sar', f'({ctype})((({signed})({ctype})a) >> ((({ctype})b) % {bits}))')]:
            name = f'{op}_{width}'
            declarations.append(f'extern {ctype} {name}({ctype},{ctype});')
            checks.append(f'if ({name}(({ctype})a,({ctype})b) != ({ctype})({expression})) return 1;')
        # Division is checked only inside its defined domain (C has the same one).
        minimum = 'INT32_MIN' if width == 'w' else 'INT64_MIN'
        for op, symbol, signed_op in [('udiv', '/', False), ('urem', '%', False), ('div', '/', True), ('rem', '%', True)]:
            name = f'{op}_{width}'
            declarations.append(f'extern {ctype} {name}({ctype},{ctype});')
            x, y = (f'(({signed})({ctype})a)', f'(({signed})({ctype})b)') if signed_op else (f'(({ctype})a)', f'(({ctype})b)')
            guard = f'({ctype})b != 0' + (f' && !({x} == {minimum} && {y} == -1)' if signed_op else '')
            checks.append(f'if ({guard} && {name}(({ctype})a,({ctype})b) != ({ctype})({x} {symbol} {y})) return 1;')
        # Unsigned/signed orderings, also against equal and adjacent operands
        # (where LS/LE differ from LO/LT and SUBS overflows near the extremes).
        for op, symbol, signed_op in [('cule', '<=', False), ('cslt', '<', True), ('csle', '<=', True)]:
            name = f'{op}_{width}'
            declarations.append(f'extern uint32_t {name}({ctype},{ctype});')
            view = signed if signed_op else ctype
            for x, y in [('a', 'b'), ('b', 'a'), ('a', 'a'), ('a', 'a + 1'), ('a + 1', 'a'), ('a - 1', 'a'), ('a', 'a - 1')]:
                checks.append(f'if ({name}(({ctype})({x}),({ctype})({y})) != '
                              f'(uint32_t)((({view})({ctype})({x})) {symbol} (({view})({ctype})({y})))) return 1;')
    source = '''#include <stdint.h>
#include <stdio.h>
''' + '\n'.join(declarations) + '''
extern uint32_t sum(uint32_t),swap(uint32_t),branch2(void),sameedge(void),frame4080(void);
extern uint64_t mixed(uint32_t,uint64_t),constant(void),word_probe(void),saved_probe(void);
extern uint64_t eight(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
int main(void) {
  uint64_t state = 20261019;
  for (unsigned i=0; i<2000; ++i) {
    state=state*UINT64_C(6364136223846793005)+UINT64_C(1442695040888963407);
    uint64_t a = i==0 ? UINT64_MAX : state;
    state=state*UINT64_C(6364136223846793005)+UINT64_C(1442695040888963407);
    uint64_t b = i==0 ? 1 : state;
    if (i > 0 && i <= 650) {
      /* Every count 0..129 (beyond twice the width) with zero, one, sign-bit,
         all-ones and mixed operands at both widths; the LCG alone gives odd b. */
      static const uint64_t edge[5] = {0, 1, UINT64_C(1)<<63, UINT64_MAX, UINT64_C(0x0123456789abcdef)};
      a = edge[i % 5] ^ ((i / 5) % 2 ? (UINT64_C(1)<<31) : 0);
      b = (i - 1) / 5;
    }
    if (i > 650 && i % 3 == 0) b >>= (i % 64); /* small divisors */
    if (i > 650 && i % 7 == 0) b = (uint64_t)-(int64_t)(b & 15); /* small negative divisors */
''' + '\n'.join(checks) + '''
    unsigned n = i % 100;
    if(sum(n) != n*(n-1)/2) return 2;
    if(swap(n) != (n%2 ? 22u : 11u)) return 3;
    if(mixed(n,a) != a + ((uint64_t)n << 32)) return 4;
    if(eight(a,b,1,2,3,4,5,6) != a+b+21) return 5;
  }
  if(branch2()!=7 || sameedge()!=19 || frame4080()!=254) return 6;
  if(constant()!=UINT64_C(18364758544493064720)) return 7;
  if(word_probe()!=UINT64_C(305419896) || saved_probe()!=0) return 8;
  puts("first-path native checks passed");
}
'''

    if not strict_word_result:
        source = source.replace('word_probe()!=', '(uint32_t)word_probe()!=')
    return source


def probes():
    lines = ['.text', '.globl _word_probe', '.p2align 2', '_word_probe:',
             'sub sp,sp,#16', 'str x30,[sp,#0]', 'movz x0,#0x5678',
             'movk x0,#0x1234,lsl #16', 'movk x0,#0xface,lsl #48',
             'bl _identity', 'ldr x30,[sp,#0]', 'add sp,sp,#16', 'ret',
             '.globl _saved_probe', '.p2align 2', '_saved_probe:', 'sub sp,sp,#112']
    for i in range(19, 31):
        lines += [f'str x{i},[sp,#{8*(i-19)}]']
    for i in range(19, 30):
        lines += [f'mov x{i},#{i}']
    lines += ['mov w0,#4', 'bl _swap', 'mov w0,#0']
    for i in range(19, 30):
        lines += [f'cmp x{i},#{i}', 'b.ne L_first_path_bad_saved']
    lines += ['b L_first_path_restore', 'L_first_path_bad_saved:', 'mov w0,#1', 'L_first_path_restore:']
    for i in range(19, 31):
        lines += [f'ldr x{i},[sp,#{8*(i-19)}]']
    return '\n'.join(lines + ['add sp,sp,#112', 'ret', ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    args = parser.parse_args()
    with workspace() as work:
        src, assembly = work/'program.ssa', work/'program.s'
        functions = fixtures()
        src.write_text('\n'.join(functions)+'\n')
        run([LCB,'--first-path',src,'-o',assembly])
        first = assembly.read_bytes()
        run([LCB,'--first-path',src,'-o',assembly])
        assert assembly.read_bytes() == first, 'fresh-process output differs'
        protected = work/'protected.s'
        protected.write_text('preserve-on-failure')
        refusal = run([LCB,'--first-path',src,'--require-proof','-o',protected], success=False)
        assert 'certificationUnavailable' in refusal.stderr
        assert protected.read_text() == 'preserve-on-failure', 'failed certification overwrote output'
        singleton = work/'single.ssa'
        singleton.write_text(functions[0])
        alone = run([LCB,'--first-path',singleton]).stdout
        # Compare complete function fragments, independent of module wrapper.
        fragment = alone.split('.text\n',1)[1].split('.subsections_via_symbols',1)[0].strip()
        assert fragment in first.decode(), 'unrelated functions changed code fragment'
        src.write_text('\n'.join(reversed(functions))+'\n')
        reordered = run([LCB,'--first-path',src]).stdout
        assert fragment in reordered, 'module ordering changed function fragment'
        src.write_text('\n'.join(functions)+'\n')
        bad = work/'excluded.ssa'
        bad.write_text('function w $f(w %a) { @entry %r =w neg %a ret %r }')
        assert 'unary operations' in run([LCB,'--first-path',bad],success=False).stderr
        run([LCB, '--target', 'aarch64-macos',bad])  # Existing compatibility support remains available.
        print('first-path: fresh-process/module-order stability, explicit proof refusal and compatibility isolation passed')
        replay_checks(work, src, functions)
        high = high_multiply_assembly(work)
        if platform.system() != 'Darwin' or platform.machine() != 'arm64':
            assert not args.require_native, 'Apple ARM64 native execution required'
            print('first-path native execution: not measured on this host')
            return
        compiler = os.environ.get('LCB_CC', os.environ.get('CC','clang'))
        driver, probe = work/'driver.c', work/'probes.s'
        driver.write_text(harness())
        probe.write_text(probes())
        def check(asm, name, success=True):
            exe=work/name
            run([compiler,'-std=c11','-O2',driver,probe,asm,'-o',exe])
            result=run([exe],success=success)
            if success: assert result.stdout.strip()=='first-path native checks passed'
            return result
        check(assembly,'typed')
        high_driver, high_exe = work/'high.c', work/'high'
        high_driver.write_text(high_multiply_harness())
        run([compiler,'-std=c11','-O2',high_driver,high,'-o',high_exe])
        assert run([high_exe]).stdout.strip() == 'first-path high multiply native checks passed'
        baseline=work/'baseline.s'
        run([LCB, '--target', 'aarch64-macos',src,'-o',baseline])
        check(baseline,'baseline')
        qbe=work/'qbe'
        shutil.copytree(ROOT/'third_party/qbe',qbe)
        run(['make','-j2',f'CC={compiler}'],cwd=qbe)
        oracle=work/'qbe.s'
        run([qbe/'qbe','-t','arm64_apple','-o',oracle,src])
        # The QBE integer return ABI only promises the low word. Its identity
        # function may preserve incoming high bits, unlike our stronger emitted
        # word-result-zeroing policy. Do not call that an upstream mismatch.
        driver.write_text(harness(strict_word_result=False))
        check(oracle,'oracle')
        driver.write_text(harness())
        # Qualify comparisons using a legal, in-frame wrong operand offset.
        corrupt=work/'corrupt.s'
        text=assembly.read_text()
        old='ldr w10, [sp, #8]'
        assert old in text
        corrupt.write_text(text.replace(old,'ldr w10, [sp, #0]',1))
        check(corrupt,'corrupt',success=False)
        corrupt.write_text(text.replace('L_lcb_4_swap_entry:\n', 'L_lcb_4_swap_entry:\n\tmov x19,#0\n',1))
        assert corrupt.read_text()!=text
        # Isolate the probe: corrupting x19 can also break the C loop itself.
        driver.write_text('extern unsigned long long saved_probe(void);\n'
                          'int main(void) { return saved_probe() ? 8 : 0; }\n')
        assert check(corrupt,'corrupt-saved',success=False).returncode==8
        print(f'first-path: {len(functions)} functions; 144,000 arithmetic/shift/division/comparison checks (division only inside its defined domain) and 8,000 loop/ABI cases per typed/baseline/QBE backend; maximal frame, W/X alias and saved-register probes; both corruption controls detected')


if __name__ == '__main__':
    main()
