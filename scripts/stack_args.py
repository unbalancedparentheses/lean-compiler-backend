#!/usr/bin/env python3
"""Apple ARM64 integer stack-argument qualification, independent C/Python/QBE.

Exercises C->Lean, Lean->C, Lean->Lean and non-leaf functions receiving and
forwarding packed stack arguments. It does not qualify other ABI classes.
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import tempfile
import time
import traceback
from fuzz import ROOT, LCB, run, native_host, compile_and_run, inputs

MASK = (1 << 64) - 1
COUNTS = (8, 9, 10, 11, 12, 15, 16, 17, 24, 32, 64)
KEEP = 0x123456789ABCDEF0


@dataclass
class Spec:
    name: str
    widths: list
    biases: list

    def values(self, a, b):
        return [((a if i % 2 == 0 else b) ^ bias) & ((1 << bits) - 1)
                for i, (bits, bias) in enumerate(zip(self.widths, self.biases))]

    def weighted(self, values):
        return sum((i * 13 + 1) * value for i, value in enumerate(values)) & MASK

    def expected(self, a, b):
        values = self.values(a, b)
        total = self.weighted(values)
        return [total, total ^ KEEP, total ^ KEEP, total ^ values[0]]

    def ssa(self):
        w = lambda bits: 'w' if bits == 32 else 'l'
        parameters = ','.join(f'{w(bits)} %p{i}' for i, bits in enumerate(self.widths))
        arguments = ','.join(f'{w(bits)} %p{i}' for i, bits in enumerate(self.widths))
        lines = [f'export function l $in_{self.name}({parameters}) {{', '@entry']
        previous = '0'
        for i, bits in enumerate(self.widths):
            value = f'%p{i}'
            if bits == 32:
                lines.append(f' %wide{i} =l extuw {value}')
                value = f'%wide{i}'
            lines += [f' %term{i} =l mul {value},{i * 13 + 1}',
                      f' %sum{i} =l add {previous},%term{i}']
            previous = f'%sum{i}'
        lines += [f' ret {previous}', '}']
        for prefix, target in [('out', 'c'), ('forward', 'in')]:
            lines += [f'export function l ${prefix}_{self.name}(l %a,l %b) {{', '@entry',
                      f' %keep =l xor %a,{KEEP}']
            for i, bias in enumerate(self.biases):
                lines.append(f' %v{i} =l xor %{ "a" if i % 2 == 0 else "b" },{bias}')
            args = ','.join(f'{w(bits)} %v{i}' for i, bits in enumerate(self.widths))
            lines += [f' %called =l call ${target}_{self.name}({args})',
                      ' %saved =l xor %called,%keep', ' %result =l xor %saved,%a',
                      ' ret %result', '}']
        lines += [f'export function l $relay_{self.name}({parameters}) {{', '@entry']
        lines += [' %keep =l extuw %p0'] if self.widths[0] == 32 else [' %keep =l copy %p0']
        lines += [f' %called =l call $c_{self.name}({arguments})',
                  ' %result =l xor %called,%keep', ' ret %result', '}']
        return '\n'.join(lines) + '\n'

    def c_parameters(self):
        return ','.join(f'uint{bits}_t p{i}' for i, bits in enumerate(self.widths))

    def c_arguments(self, a, b):
        return ','.join(f'(uint{bits}_t)UINT64_C({value})'
                        for bits, value in zip(self.widths, self.values(a, b)))

    def c_helper(self):
        lines = [f'uint64_t c_{self.name}({self.c_parameters()}) {{', ' uint64_t r=0;']
        lines += [f' r+=(uint64_t)p{i}*UINT64_C({i * 13 + 1});' for i in range(len(self.widths))]
        return '\n'.join(lines + [' return r;', '}']) + '\n'

    def c_reference(self):
        args = ','.join(f'p{i}' for i in range(len(self.widths)))
        lines = [f'uint64_t in_{self.name}({self.c_parameters()}) {{ return c_{self.name}({args}); }}',
                 f'uint64_t relay_{self.name}({self.c_parameters()}) {{ return c_{self.name}({args})^(uint64_t)p0; }}']
        values = ','.join(f'(uint{bits}_t)({"a" if i % 2 == 0 else "b"}^UINT64_C({bias}))'
                          for i, (bits, bias) in enumerate(zip(self.widths, self.biases)))
        for prefix in ('out', 'forward'):
            lines.append(f'uint64_t {prefix}_{self.name}(uint64_t a,uint64_t b) '
                         f'{{ return c_{self.name}({values})^UINT64_C({KEEP}); }}')
        return '\n'.join(lines) + '\n'


def specs(seed):
    rng, result = random.Random(seed), []
    for count in COUNTS:
        for pattern in ('w', 'l', 'alt', 'blocks', 'random'):
            if pattern == 'w': widths = [32] * count
            elif pattern == 'l': widths = [64] * count
            elif pattern == 'alt': widths = [32 if i % 2 else 64 for i in range(count)]
            elif pattern == 'blocks': widths = [32 if i % 4 < 2 else 64 for i in range(count)]
            else: widths = [rng.choice([32, 64]) for _ in range(count)]
            result.append(Spec(f'n{count}_{pattern}', widths, [rng.getrandbits(64) for _ in widths]))
    return result


def caller(selected, arguments):
    lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
    for spec in selected:
        for prefix in ('in', 'relay'):
            lines.append(f'extern uint64_t {prefix}_{spec.name}({spec.c_parameters()});')
        for prefix in ('out', 'forward'):
            lines.append(f'extern uint64_t {prefix}_{spec.name}(uint64_t,uint64_t);')
    lines.append('int main(void) {')
    for spec in selected:
        for a, b in arguments:
            for prefix in ('in', 'out', 'forward', 'relay'):
                args = spec.c_arguments(a, b) if prefix in ('in', 'relay') else f'UINT64_C({a}),UINT64_C({b})'
                lines.append(f'printf("%" PRIu64 "\\n", {prefix}_{spec.name}({args}));')
    return '\n'.join(lines + ['return 0;', '}']) + '\n'


def mutant_checks(work, selected, assembly, cfile, expected, done):
    text = assembly.read_text()
    if any(s.name == 'n12_w' for s in selected):
        # Four packed word arguments fill 16 bytes. An eight-byte final store
        # overwrites the first local parameter, which is needed after the call.
        changed = text.replace('\tstr w9, [sp, #12]', '\tstur x9, [sp, #12]')
        assert changed != text
        mutant = work/'wide-store.s'
        mutant.write_text(changed)
        assert compile_and_run(os.environ['LCB_CC'], mutant, cfile, work/'wide-store') != expected
        done.add('outgoing-width')
    if any(s.name == 'n9_l' for s in selected):
        start = text.index('_in_n9_l:\n')
        end = text.index('L_lcb_block_', start)
        prologue = text[start:end]
        match = re.search(r'\tldr x9, \[sp, #(\d+)\]', prologue)
        assert match
        offset = int(match.group(1))
        changed = prologue[:match.start()] + match.group(0).replace(f'#{offset}', f'#{offset + 8}') + prologue[match.end():]
        mutant = work/'incoming-offset.s'
        mutant.write_text(text[:start] + changed + text[end:])
        assert compile_and_run(os.environ['LCB_CC'], mutant, cfile, work/'incoming-offset') != expected
        done.add('incoming-offset')


def recursive_case(work, qbe, seed, arguments):
    rng = random.Random(seed ^ 0xABCDEF)
    spec = Spec('recursive_stack', [32 if i % 2 == 0 else 64 for i in range(16)],
                [rng.getrandbits(64) for _ in range(16)])
    spelling = lambda bits: 'w' if bits == 32 else 'l'
    parameters = ','.join(f'{spelling(bits)} %p{i}' for i,bits in enumerate(spec.widths))
    args = ','.join(f'{spelling(bits)} %p{i}' for i,bits in enumerate(spec.widths))
    source = work/'recursive.ssa'
    leaf = spec.ssa().split('export function l $out_',1)[0]
    body = f'''function l $recurse(l %depth,{parameters}) {{
@entry
 %own =l alloc16 8
 %first =l extuw %p0
 storel %first,%own
 %sum =l call $in_recursive_stack({args})
 %again =w cnel %depth,0
 jnz %again,@child,@base
@base
 %baseOwn =l load %own
 %baseResult =l add %sum,%baseOwn
 ret %baseResult
@child
 %less =l sub %depth,1
 %nested =l call $recurse(l %less,{args})
 %retained =l load %own
 %withOwn =l add %sum,%retained
 %result =l add %withOwn,%nested
 ret %result
}}
export function l $recursive_entry(l %a,l %b) {{
@entry
 %depth =l and %a,3
'''
    for i,bias in enumerate(spec.biases):
        body += f' %v{i} =l xor %{ "a" if i % 2 == 0 else "b" },{bias}\n'
    actual = ','.join(f'{spelling(bits)} %v{i}' for i,bits in enumerate(spec.widths))
    body += f' %result =l call $recurse(l %depth,{actual})\n ret %result\n}}\n'
    source.write_text(leaf + body)
    expected = [(((a&3)+1) * (spec.weighted(spec.values(a,b)) + spec.values(a,b)[0])) & MASK
                for a,b in arguments]
    (work/'recursion.json').write_text(json.dumps({'seed':seed,'spec':spec.__dict__,
        'arguments':arguments,'expected':expected},indent=2))
    # Cover every recursion depth without requiring an external-function model.
    for a in range(4):
        b = MASK-a
        wanted = (((a&3)+1)*(spec.weighted(spec.values(a,b))+spec.values(a,b)[0])) & MASK
        assert int(run([LCB,'--eval',source,'recursive_entry',a,b])) == wanted
    if qbe:
        asm, qasm, cfile = work/'recursive-lean.s',work/'recursive-qbe.s',work/'recursive.c'
        run([LCB,source,'-o',asm])
        run([qbe,'-t','arm64_apple','-o',qasm,source])
        caller = '#include <stdint.h>\n#include <stdio.h>\n#include <inttypes.h>\n'
        caller += 'extern uint64_t recursive_entry(uint64_t,uint64_t);\nint main(void) {\n'
        caller += '\n'.join(f'printf("%" PRIu64 "\\n",recursive_entry(UINT64_C({a}),UINT64_C({b})));'
                            for a,b in arguments) + '\nreturn 0; }\n'
        cfile.write_text(caller)
        for label,assembly in [('lean',asm),('qbe',qasm)]:
            found = compile_and_run(os.environ['LCB_CC'],assembly,cfile,work/f'recursive-{label}')
            assert found == expected, ('recursive stack arguments',label)
        args = ','.join(f'(uint{bits}_t)({"a" if i%2==0 else "b"}^UINT64_C({bias}))'
                        for i,(bits,bias) in enumerate(zip(spec.widths,spec.biases)))
        reference = work/'recursive-reference.c'
        reference.write_text('#include <stdint.h>\n' + spec.c_helper() +
            'uint64_t recursive_entry(uint64_t a,uint64_t b) { return ((a&3)+1)*('
            + f'c_recursive_stack({args})+(uint64_t)(uint32_t)(a^UINT64_C({spec.biases[0]}))); }}\n'
            + caller)
        run([os.environ['LCB_CC'],'-std=c11','-O2',reference,'-o',work/'recursive-reference'])
        assert [int(line) for line in run([work/'recursive-reference']).splitlines()] == expected
    print('recursive stack arguments: 4 interpreter cases; ' +
          (f'{len(expected)} native cases per Lean/QBE/C backend; caller stack objects retained'
           if qbe else 'native not measured'),flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    parser.add_argument('--seed', type=int, default=20261019)
    options = parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    matrix, arguments = specs(options.seed), inputs(options.seed, 11)
    interpreted = native_cases = 0
    controls = set()
    with tempfile.TemporaryDirectory(prefix='lcb-stack-args-') as directory:
        work = Path(directory)
        try:
            qbe = None
            if native_host():
                oracle = work/'oracle'
                shutil.copytree(ROOT/'third_party/qbe', oracle)
                run(['make', '-j2', f'CC={os.environ["LCB_CC"]}'], cwd=oracle)
                qbe = oracle/'qbe'
            for start in range(0, len(matrix), 8):
                selected = matrix[start:start + 8]
                source, asm, cfile = work/'input.ssa', work/'lean.s', work/'caller.c'
                source.write_text(''.join(spec.ssa() for spec in selected))
                expected = [value for spec in selected for a, b in arguments for value in spec.expected(a,b)]
                (work/'case.json').write_text(json.dumps({'seed': options.seed, 'arguments': arguments,
                    'specs': [spec.__dict__ for spec in selected], 'expected': expected,
                    'compiler_sha256': hashlib.sha256(LCB.read_bytes()).hexdigest(),
                    'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    'upstream_lock_sha256': hashlib.sha256((ROOT/'upstream-lock.json').read_bytes()).hexdigest(),
                    'flake_lock_sha256': hashlib.sha256((ROOT/'flake.lock').read_bytes()).hexdigest()}, indent=2))
                run([LCB, '--check', source])
                run([LCB, source, '-o', asm])
                for spec in selected:
                    a, b = MASK, 0x80000000
                    values = spec.values(a,b)
                    for index,prefix in [(0,'in'),(2,'forward')]:
                        wanted = spec.expected(a,b)[index]
                        args = values if prefix in ('in','relay') else [a,b]
                        found = int(run([LCB,'--eval',source,f'{prefix}_{spec.name}',*args]))
                        assert found == wanted
                        interpreted += 1
                # External C has no fabricated interpreter model.
                for prefix in ('out','relay'):
                    spec = selected[0]
                    args = spec.values(1,2) if prefix=='relay' else [1,2]
                    result = subprocess.run([str(LCB),'--eval',str(source),f'{prefix}_{spec.name}',*map(str,args)],
                                            text=True,capture_output=True,timeout=30)
                    assert result.returncode and 'no interpreter model' in result.stderr
                if qbe:
                    helpers = '#include <stdint.h>\n' + ''.join(spec.c_helper() for spec in selected)
                    cfile.write_text(helpers + caller(selected,arguments))
                    qasm = work/'qbe.s'
                    run([qbe,'-t','arm64_apple','-o',qasm,source])
                    for label, assembly in [('lean',asm),('qbe',qasm)]:
                        actual = compile_and_run(os.environ['LCB_CC'],assembly,cfile,work/label)
                        (work/f'{label}-output.json').write_text(json.dumps(actual))
                        assert actual == expected, (label,start,next((i for i,pair in enumerate(zip(actual,expected)) if pair[0]!=pair[1]),None))
                    reference = work/'reference.c'
                    reference.write_text(helpers + ''.join(spec.c_reference() for spec in selected) + caller(selected,arguments))
                    run([os.environ['LCB_CC'],'-std=c11','-O2',reference,'-o',work/'reference'])
                    actual = [int(line) for line in run([work/'reference']).splitlines()]
                    assert actual == expected, ('native C reference',start)
                    mutant_checks(work,selected,asm,cfile,expected,controls)
                    native_cases += len(expected)
                print(f'stack argument batch {start//8 + 1}: passed',flush=True)
            recursive_case(work,qbe,options.seed,arguments)
        except Exception:
            target = ROOT/'.build/stack-args-failures'/f'run-{time.time_ns()}'
            target.mkdir(parents=True,exist_ok=True)
            for path in work.iterdir():
                if path.suffix in ('.ssa','.s','.c','.json'): shutil.copy2(path,target/path.name)
            (target/'failure.txt').write_text(traceback.format_exc())
            print(f'STACK ARGUMENT FAILURE: retained {target}',flush=True)
            raise
    if qbe: assert controls == {'outgoing-width','incoming-offset'}, controls
    print(f'stack arguments: {len(matrix)} signatures, {len(matrix)*4} entry functions, '
          f'{interpreted} interpreter cases; ' +
          (f'{native_cases} native cases per Lean/QBE/C backend; both ABI corruptions detected'
           if qbe else 'native not measured'))


if __name__ == '__main__': main()
