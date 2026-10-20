#!/usr/bin/env python3
"""Apple ARM64 integer variadics in both C ABI directions, including dynamic frames."""
import argparse
import os
from pathlib import Path
import random
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

MASK = (1 << 64)-1
NAMED = [1, 7, 8, 9, 10, 12, 58]
TAIL = ['w','l','w','l','l','w']


def fixed_widths(count):
    return ['w' if i%3==0 else 'l' for i in range(count)]


def value(seed, offset, width):
    return (seed+offset) % (1 << (32 if width=='w' else 64))


def expected(count, seed):
    fixed = sum(value(seed,i,w) for i,w in enumerate(fixed_widths(count)))
    tail = sum(value(seed,100+i,w) for i,w in enumerate(TAIL))
    return (fixed+tail+value(seed,100,'w')+21) & MASK


def fixture():
    source = ['''function l $nested(l %base, ...) {
@entry
 %ap =l alloc8 8
 vastart %ap
 %a =w vaarg %ap
 %b =l vaarg %ap
 %wide =l extuw %a
 %sum =l add %base, %wide
 %result =l add %sum, %b
 ret %result
}
''']
    declarations, helpers = [], []
    for count in NAMED:
        ws = fixed_widths(count)
        params = ','.join(f'{w} %f{i}' for i,w in enumerate(ws))
        source.append(f'export function l $sum_{count}({params}, ...) {{\n@entry\n')
        source += [' %sizew =w and %f0, 31\n %sizel =l extuw %sizew\n %size =l add %sizel, 16\n',
                   ' %ap =l alloc16 %size\n %again =l alloc8 8\n vastart %ap\n']
        acc='0'
        for i,w in enumerate(ws):
            arg=f'%f{i}'
            if w=='w':
                source.append(f' %fw{i} =l extuw {arg}\n')
                arg=f'%fw{i}'
            source.append(f' %fs{i} =l add {acc}, {arg}\n')
            acc=f'%fs{i}'
        for i,w in enumerate(TAIL):
            source.append(f' %v{i} ={w} vaarg %ap\n')
            arg=f'%v{i}'
            if w=='w':
                source.append(f' %vw{i} =l extuw {arg}\n')
                arg=f'%vw{i}'
            source.append(f' %vs{i} =l add {acc}, {arg}\n')
            acc=f'%vs{i}'
        source += [' %nested =l call $nested(l 5, ..., w 7, l 9)\n',
                   ' vastart %again\n %first =w vaarg %again\n %first64 =l extuw %first\n',
                   f' %total =l add {acc}, %nested\n %result =l add %total, %first64\n ret %result\n}}\n']
        cparams=','.join(f'{"uint32_t" if w=="w" else "uint64_t"} f{i}' for i,w in enumerate(ws))
        declarations.append(f'extern uint64_t sum_{count}({cparams},...);\n')
        helpers.append(f'static uint64_t helper_{count}({cparams},...) {{ va_list ap; va_start(ap,f{count-1}); uint64_t r=21;\n')
        for i in range(count): helpers.append(f'r += f{i};\n')
        for i,w in enumerate(TAIL):
            helpers.append(f'{"uint32_t" if w=="w" else "uint64_t"} v{i}=va_arg(ap,{"uint32_t" if w=="w" else "uint64_t"}); r+=v{i};\n')
        helpers.append('r+=v0; va_end(ap); return r; }\n')
        # Export a C target for direct calls as well as a function pointer callback.
        helpers.append(f'uint64_t c_sum_{count}({cparams},...) {{ va_list ap; va_start(ap,f{count-1});\n')
        for i,w in enumerate(TAIL): helpers.append(f'{"uint32_t" if w=="w" else "uint64_t"} v{i}=va_arg(ap,{"uint32_t" if w=="w" else "uint64_t"});\n')
        helpers.append('va_end(ap); return helper_'+str(count)+'('+','.join(f'f{i}' for i in range(count))+','+','.join(f'v{i}' for i in range(len(TAIL)))+'); }\n')
        for mode in ['internal','indirect','external','callback']:
            wrapper_params='l %seed' if mode!='callback' else 'l %fn,l %seed'
            source.append(f'export function l ${mode}_{count}({wrapper_params}) {{\n@entry\n')
            args=[]
            for i,w in enumerate(ws):
                source.append(f' %a{i} ={w} add %seed, {i}\n')
                args.append(f'{w} %a{i}')
            args.append('...')
            for i,w in enumerate(TAIL):
                source.append(f' %t{i} ={w} add %seed, {100+i}\n')
                args.append(f'{w} %t{i}')
            target=f'$sum_{count}' if mode=='internal' else f'$c_sum_{count}'
            if mode=='indirect':
                source.append(f' %fn =l copy $sum_{count}\n')
                target='%fn'
            if mode=='callback': target='%fn'
            source.append(f' %result =l call {target}('+','.join(args)+')\n ret %result\n}\n')
            declarations.append(f'extern uint64_t {mode}_{count}('+('uintptr_t,' if mode=='callback' else '')+'uint64_t);\n')
    return ''.join(source), ''.join(declarations), ''.join(helpers)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    parser.add_argument('--seed',type=int,default=20261020)
    options=parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    rng=random.Random(options.seed)
    seeds=[0,MASK,1<<32,rng.getrandbits(64),rng.getrandbits(64)]
    text,declarations,helpers=fixture()
    with tempfile.TemporaryDirectory(prefix='lcb-variadic-') as directory:
        work=Path(directory)
        source,asm,caller=work/'input.ssa',work/'lean.s',work/'caller.c'
        source.write_text(text)
        run([LCB,source,'-o',asm])
        checks=[]
        for count in NAMED:
            for seed in seeds:
                wanted=expected(count,seed)
                for mode in ['internal','indirect']:
                    assert int(run([LCB,'--eval',source,f'{mode}_{count}',seed]))==wanted,(mode,count,seed)
                args=[f'({"uint32_t" if w=="w" else "uint64_t"})UINT64_C({value(seed,i,w)})' for i,w in enumerate(fixed_widths(count))]
                args += [f'({"uint32_t" if w=="w" else "uint64_t"})UINT64_C({value(seed,100+i,w)})' for i,w in enumerate(TAIL)]
                checks.append(f'if (sum_{count}('+','.join(args)+f') != UINT64_C({wanted})) return 1;\n')
                for mode in ['internal','indirect','external']:
                    checks.append(f'if ({mode}_{count}(UINT64_C({seed})) != UINT64_C({wanted})) return 2;\n')
                checks.append(f'if (callback_{count}((uintptr_t)helper_{count},UINT64_C({seed})) != UINT64_C({wanted})) return 3;\n')
        caller.write_text('#include <stdint.h>\n#include <stdarg.h>\n#include <stdio.h>\n'+helpers+declarations+'int main(void) {\n'+''.join(checks)+'puts("variadics passed"); return 0; }\n')
        controls=[
            ('function $f(l %p) { @s vastart %p ret }','vastart requires'),
            ('function l $f(...) { @s %p =l alloc8 8 vastart %p %r =l vaarg %p ret %r }','outside an allocated object'),
            ('function $f(...) { @s ret } function $g() { @s call $f(..., ..., w 1) ret }','duplicate variadic'),
            ('function $f(w %n,...) { @s ret } function $g() { @s call $f(w 1,w 2) ret }','variadic boundary'),
        ]
        for i,(text,diagnostic) in enumerate(controls):
            bad=work/f'bad{i}.ssa';bad.write_text(text)
            reject([LCB,'--eval',bad,'f'] if i==1 else [LCB,'--check',bad],diagnostic)
        restricted=work/'restricted.ssa'
        restricted.write_text('function l $f(l %x, ...) { @s ret %x }')
        reject([LCB,'--first-path',restricted],'variadic functions')
        if native_host():
            cc=os.environ.get('LCB_CC','clang')
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s'
            run([oracle/'qbe','-t','arm64_apple','-o',qasm,source])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label
                run([cc,'-std=c11','-O2',caller,assembly,'-o',exe])
                assert run([exe]).strip()=='variadics passed'
    print(f'variadics: {len(NAMED)} named-argument boundaries through 64 total arguments; 70 interpreted calls; '+
          ('native Lean/QBE/C direct and indirect calls in both directions passed' if native_host() else 'native not measured'))


if __name__=='__main__': main()
