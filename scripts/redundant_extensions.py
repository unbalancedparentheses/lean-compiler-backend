#!/usr/bin/env python3
"""Independent bit-level oracle for extending loads followed by extensions."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host

LOADS = [(kind, bits, signed, width)
         for kind, bits, signed in [('sb',8,True),('ub',8,False),('sh',16,True),
                                    ('uh',16,False),('sw',32,True),('uw',32,False)]
         for width in ['w','l']] + [('w',32,False,'w'),('l',64,False,'l')]
EXTENSIONS = [(kind, bits, signed, width)
              for kind, bits, signed in [('sb',8,True),('ub',8,False),('sh',16,True),
                                         ('uh',16,False),('sw',32,True),('uw',32,False)]
              for width in (['l'] if bits == 32 else ['w','l'])]


def inputs():
    # First fixture makes the signed-load corruption observable even before the
    # optimization exists: extuh must preserve the sign-filled upper byte.
    combinations = [(LOADS[0], ('uh',16,False,'w'))]
    combinations += [(load, ext) for load in LOADS for ext in EXTENSIONS
                     if (load,ext) != combinations[0]]
    source, declarations, checks = [], [], []
    for load, ext in combinations:
        kind, bits, signed, load_width = load
        extension, narrow, ext_signed, result_width = ext
        result_type = 'uint32_t' if result_width == 'w' else 'uint64_t'
        load_type = 'uint32_t' if load_width == 'w' else 'uint64_t'
        load_cast = f'{"int" if signed else "uint"}{bits}_t'
        ext_cast = f'{"int" if ext_signed else "uint"}{narrow}_t'
        for barrier in ['none','store','call']:
            name = f'extension_{kind}_{load_width}_{extension}_{result_width}_{barrier}'
            effect = {'none':'', 'store':' storeb 90,%p',
                      'call':' call $extension_mutate(l %p)'}[barrier]
            source.append(f'''export function {result_width} ${name}(l %p) {{
@s
 %loaded ={load_width} load{kind} %p
{effect}
 %extended ={result_width} ext{extension} %loaded
 ret %extended
}}
''')
            declarations.append(f'extern {result_type} {name}(void *);')
            checks.append(f'''memcpy(bytes,&seed,8);memcpy(expected,bytes,8);
 {{ {load_type} loaded=({load_type})({load_cast})seed;
 {result_type} wanted=({result_type})({ext_cast})loaded;
 if({name}(bytes)!=wanted)return 1;
 {"expected[0]=90;" if barrier != 'none' else ""}
 if(memcmp(bytes,expected,8))return 2; }}''')
    caller = '''#include <stdint.h>
#include <string.h>
''' + '\n'.join(declarations) + '''
void extension_mutate(void *p){*(unsigned char *)p=90;}
int main(void){
 static const uint64_t edges[]={0,1,127,128,255,256,32767,32768,65535,65536,
 UINT64_C(2147483647),UINT64_C(2147483648),UINT64_C(4294967295),
 UINT64_C(4294967296),UINT64_C(9223372036854775808),UINT64_MAX};
 unsigned char bytes[8],expected[8];uint64_t random=UINT64_C(0x89abcdef01234567);
 for(unsigned i=0;i<144;i++){
 random^=random<<13;random^=random>>7;random^=random<<17;
 uint64_t seed=i<sizeof(edges)/sizeof(edges[0])?edges[i]:random;
''' + '\n'.join(checks) + '''
 }return 0;
}
'''
    return '\n'.join(source), caller, len(checks)*144


def exercise(compiler, work, run, cc, target, execute=True):
    case = Path(work)/'redundant-extensions'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    ir, c, count = inputs()
    source.write_text(ir);caller.write_text(c)
    caller_object = case/'caller.o'
    if execute:
        result = run([cc,'-O2','-c',caller,'-o',caller_object],True)
        assert result.returncode == 0,result.stderr
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe = case/(label+'.s'),case/label
        result = run([compiler,source,'--target',target,*flags,'-o',asm])
        assert result.returncode == 0,(target,label,result.stderr)
        if not execute:
            continue
        result = run([cc,caller_object,asm,'-o',exe],True)
        assert result.returncode == 0,result.stderr
        result = run([exe],True)
        assert result.returncode == 0,(target,label,result.returncode,result.stderr)
        if target.startswith('aarch64') and label == 'optimized':
            original = asm.read_text()
            damaged = original.replace('\tldrsb w','\tldrb w',1)
            assert damaged != original,'expected signed byte load for corruption control'
            bad,badexe = case/'unsigned-load.s',case/'unsigned-load'
            bad.write_text(damaged)
            result = run([cc,caller_object,bad,'-o',badexe],True)
            assert result.returncode == 0,result.stderr
            result = run([badexe],True)
            assert result.returncode == 1,('signed-load corruption escaped oracle',result.returncode,result.stderr)
    print(f'{target}: redundant extensions: {count} independent matching/mismatched/cross-width '
          f'and mutation checks per mode; execution={execute}',flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    args = parser.parse_args()
    if args.require_native:
        assert native_host()
    def run(cmd,inside=False):
        return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-redundant-extensions-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__ == '__main__':
    main()
