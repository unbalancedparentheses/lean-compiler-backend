#!/usr/bin/env python3
"""Apple scalar variadics with mixed named GP/FP banks and typed floating tails."""
import argparse
import os
from pathlib import Path
import shutil
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject


def fixture(va_list_bytes=8):
    out=[]; decl=[]; cdefs=[]; checks=[]
    for n in [0,4,5]:
        kinds=['w']*9+['s','d']*n+['w']
        params=','.join(f'{k} %a{i}' for i,k in enumerate(kinds))
        cparams=','.join(f'{dict(w="int",s="float",d="double")[k]} a{i}' for i,k in enumerate(kinds))
        args=','.join(f'{k} '+('7' if k=='w' else f'{k}_1.5') for k in kinds)
        cargs=','.join('7' if k=='w' else '1.5' for k in kinds)
        body=f'export function d $mixed_va_{n}({params},...) {{\n@entry\n %size =l copy {max(16, va_list_bytes)}\n %ap =l alloc16 %size\n vastart %ap\n'
        body+=' %x =d vaarg %ap\n %i =w vaarg %ap\n %y =d vaarg %ap\n %l =l vaarg %ap\n %r =d add %x, %y\n'
        body+=' %c0 =w ceqw %i, 123\n %cl =w ceql %l, 456\n %c1 =w and %c0, %cl\n'
        prev='%c1'
        for i,k in enumerate(kinds):
            literal='7' if k=='w' else f'{k}_1.5'
            body+=f' %check{i} =w ceq{k} %a{i}, {literal}\n %ok{i} =w and {prev}, %check{i}\n';prev=f'%ok{i}'
        body+=f' jnz {prev}, @good, @bad\n@good\n ret %r\n@bad\n ret d_-1000\n}}\n'
        out.append(body)
        for mode in ['internal','external','indirect']:
            target=f'$mixed_va_{n}' if mode!='external' else f'$c_va_{n}'
            body=f'export function l $va_{mode}_{n}() {{\n@entry\n'
            if mode=='indirect':body+=f' %fn =l copy {target}\n';target='%fn'
            body+=f' %r =d call {target}({args},...,d d_1.25,w 123,d d_2.5,l 456)\n %bits =l cast %r\n ret %bits\n}}\n'
            out.append(body)
            decl.append(f'extern uint64_t va_{mode}_{n}(void);\n')
            checks.append(f'if(va_{mode}_{n}()!=UINT64_C(4615626668101337088)) return 1;\n')
        decl.append(f'extern double mixed_va_{n}({cparams},...);\n')
        cdefs.append(f'double c_va_{n}({cparams},...) {{ va_list ap; va_start(ap,a{len(kinds)-1}); double x=va_arg(ap,double); int i=va_arg(ap,int); double y=va_arg(ap,double); uint64_t l=va_arg(ap,uint64_t); va_end(ap);\n')
        for i in range(len(kinds)): cdefs.append(f'if(a{i} != '+('7' if kinds[i]=='w' else '1.5')+') return -1000;\n')
        cdefs.append('return i==123 && l==456 ? x+y : -1000; }\n')
        checks.append(f'if(mixed_va_{n}({cargs},1.25,123,2.5,UINT64_C(456)) != 3.75) return 2;\n')
    out.append('''function s $single_va(w %n,...) {
@entry
 %ap =l alloc8 8
 vastart %ap
 %x =s vaarg %ap
 %y =s vaarg %ap
 %r =s add %x, %y
 ret %r
}
export function l $single_tail() {
@entry
 %r =s call $single_va(w 0,...,s s_1.25,s s_2.5)
 %bits =w cast %r
 %wide =l extuw %bits
 ret %wide
}
''')
    decl.append('extern uint64_t single_tail(void);\n');checks.append('if(single_tail()!=UINT64_C(1081081856)) return 3;\n')
    c='#include <stdint.h>\n#include <stdarg.h>\n'+''.join(decl+cdefs)+'int main(void) {\n'+''.join(checks)+'return 0;}\n'
    return ''.join(out).replace('alloc8 8', f'alloc8 {va_list_bytes}'),c


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--require-native',action='store_true');options=parser.parse_args()
    if options.require_native:assert native_host()
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-float-va-') as directory:
        work=Path(directory);src=work/'input.ssa';asm=work/'lean.s';c=work/'caller.c'
        text,caller=fixture();src.write_text(text);c.write_text(caller);run([LCB,src,'-o',asm])
        for n in [0,4,5]:
            for mode in ['internal','indirect']:
                assert int(run([LCB,'--eval',src,f'va_{mode}_{n}']))==4615626668101337088
        assert int(run([LCB,'--eval',src,'single_tail']))==1081081856
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,src])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label;run([cc,'-O2',c,assembly,'-o',exe]);run([exe])
        print('floating variadics: 7 interpreter calls; mixed named register/stack boundaries and s/d tails; '+('native Lean/QBE/C passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__':main()
