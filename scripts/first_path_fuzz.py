#!/usr/bin/env python3
"""Fixed-seed generated cyclic-phi loops through all first-path representations."""
import argparse
import os
import platform
import random
import shutil

from first_path import workspace
from test import ROOT, LCB, run


def generate(seed, count=12):
    randomizer = random.Random(seed)
    functions, cases, declarations = [], [], []
    for i in range(count):
        width = 'w' if i % 2 == 0 else 'l'
        bits = 32 if width == 'w' else 64
        mask = (1 << bits) - 1
        length = randomizer.randrange(2, 7)
        salt = randomizer.getrandbits(bits)
        constants = [randomizer.getrandbits(bits) for _ in range(length - 1)]
        op = randomizer.choice(('add','sub','mul','and','or','xor'))
        name = f'cycle_{i}'
        phis = []
        for j in range(length):
            initial = '%seed' if j == 0 else str(constants[j-1])
            incoming = f'%v{j+1}' if j+1 < length else '%newvalue'
            phis.append(f' %v{j} ={width} phi @entry {initial}, @body {incoming}')
        reduction = [f' %r1 ={width} add %v0, %v1']
        for j in range(2,length): reduction.append(f' %r{j} ={width} add %r{j-1}, %v{j}')
        function = f'''export function {width} ${name}(w %n, {width} %seed) {{
@entry
 jmp @loop
@loop
''' + '\n'.join(phis) + f'''
 %i =w phi @entry 0, @body %next
 %more =w cultw %i, %n
 jnz %more, @body, @exit
@body
 %newvalue ={width} {op} %v0, {salt}
 %next =w add %i, 1
 jmp @loop
@exit
''' + '\n'.join(reduction) + f'\n ret %r{length-1}\n}}'
        functions.append(function)
        ctype = 'uint32_t' if width == 'w' else 'uint64_t'
        declarations.append(f'extern {ctype} {name}(uint32_t,{ctype});')
        for n, value in [(0,0),(1,mask),(2,1),(length,mask),(length+1,1 << (bits-1)),(19,randomizer.getrandbits(bits))]:
            values = [value] + constants
            for _ in range(n):
                a = values[0]
                updated = {'add':lambda:a+salt,'sub':lambda:a-salt,'mul':lambda:a*salt,
                           'and':lambda:a&salt,'or':lambda:a|salt,'xor':lambda:a^salt}[op]() & mask
                values = values[1:] + [updated]
            cases.append((name,n,value,sum(values)&mask,ctype))
    return '\n'.join(functions)+'\n', cases, declarations


def campaign(seed, required):
    with workspace() as work:
        source, cases, declarations = generate(seed)
        src = work/'generated.ssa'
        src.write_text(source)
        for name,n,value,expected,_ in cases:
            args = [src,name,str(n),str(value)]
            assert run([LCB,'--first-path-eval',*args]).stdout.strip()==str(expected), (seed,name,n,value)
            assert run([LCB,'--eval',*args]).stdout.strip()==str(expected), (seed,name,n,value,'compatibility')
        typed, baseline = work/'typed.s', work/'baseline.s'
        run([LCB,'--first-path',src,'-o',typed])
        run([LCB, '--target', 'aarch64-macos',src,'-o',baseline])
        if platform.system() != 'Darwin' or platform.machine() != 'arm64':
            assert not required, 'native Apple ARM64 execution required'
            print(f'first-path fuzz {seed}: {len(cases)} Python/source/MIR/assembly/compatibility model cases; native not measured')
            return
        driver = work/'driver.c'
        checks = [f'if({name}({n}u,({ctype})UINT64_C({value}))!=({ctype})UINT64_C({expected})) return {i+1};'
                  for i,(name,n,value,expected,ctype) in enumerate(cases)]
        driver.write_text('#include <stdint.h>\n'+'\n'.join(declarations)+'\nint main(void) {\n'+'\n'.join(checks)+'\nreturn 0;\n}\n')
        cc = os.environ.get('LCB_CC',os.environ.get('CC','clang'))
        qbe = work/'qbe'
        shutil.copytree(ROOT/'third_party/qbe',qbe)
        run(['make','-j2',f'CC={cc}'],cwd=qbe)
        oracle = work/'oracle.s'
        run([qbe/'qbe','-t','arm64_apple','-o',oracle,src])
        for name,assembly in [('typed',typed),('baseline',baseline),('oracle',oracle)]:
            executable=work/name
            run([cc,'-std=c11','-O2',driver,assembly,'-o',executable])
            run([executable])
        # Corrupt staging order by replacing the first source load on a loop
        # backedge with zero. At least one nonzero sample must expose the error.
        text=typed.read_text()
        marker='L_lcb_7_cycle_0_edge_2_1:\n'
        assert marker in text
        start=text.index(marker)+len(marker)
        end=text.index('\n',start)
        corrupt=work/'corrupt.s'
        corrupt.write_text(text[:start]+'\tmov w9,#0'+text[end:])
        executable=work/'corrupt'
        run([cc,'-std=c11','-O2',driver,corrupt,'-o',executable])
        run([executable],success=False)
        print(f'first-path fuzz {seed}: 12 generated cyclic-phi functions, {len(cases)} inputs across Python/source/MIR/assembly/compatibility/native/QBE; backedge corruption detected')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    parser.add_argument('--seed',type=int)
    options=parser.parse_args()
    for seed in ([options.seed] if options.seed is not None else [20261019,20261020]):
        campaign(seed,options.require_native)


if __name__=='__main__':
    main()
