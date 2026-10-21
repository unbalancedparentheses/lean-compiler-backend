#!/usr/bin/env python3
"""Large constant stack objects: entry/static and non-entry/dynamic target paths."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host

SIZES = [4097, 4704, 65536, 1024*1024-1024]


def fixture():
    source, declarations, checks = [], [], []
    for size in SIZES:
        for mode in ['entry','later']:
            name=f'object_{size}_{mode}'
            branch=' jmp @body\n@body\n' if mode=='later' else ''
            source.append(f'''export function l ${name}(l %x,l %y) {{
@s
{branch} %p =l alloc16 {size}
 %end =l add %p,{size-8}
 storel %x,%p
 storel %y,%end
 %ok =w call $touch_large(l %p,l {size},l %x,l %y)
 %wide =l extuw %ok
 %a =l loadl %p
 %b =l loadl %end
 %mix =l xor %a,%b
 %r =l xor %mix,%wide
 ret %r
}}
''')
            declarations.append(f'extern uint64_t {name}(uint64_t,uint64_t);')
            for x,y in [(0,0),(17,123456789),((1<<64)-1,1<<63)]:
                checks.append(f'if({name}(UINT64_C({x}),UINT64_C({y}))!=UINT64_C({x^y^1}))return 1;')
    c='''#include <stdint.h>
#include <string.h>
static unsigned calls;
unsigned touch_large(unsigned char *p,uint64_t size,uint64_t first,uint64_t last) {
 uint64_t a,b;memcpy(&a,p,8);memcpy(&b,p+size-8,8);
 if(((uintptr_t)p&15)||a!=first||b!=last)return 0;
 for(uint64_t i=16;i<size-8;i+=4096)p[i]=(unsigned char)i;
 ++calls;return 1;
}
'''+ '\n'.join(declarations)+'\nint main(void){\n'+'\n'.join(checks)+f'\nreturn calls!={len(checks)};\n}}\n'
    return ''.join(source),c


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'large-objects';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c'
    text,c=fixture();source.write_text(text);caller.write_text(c)
    for label,flags in [('baseline',[]),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
    bad=case/'oversized.ssa';bad.write_text('function l $f() { @s %p =l alloc16 1048577 ret 0 }')
    result=run([compiler,'--check',bad]);assert result.returncode and 'constant size' in result.stderr,result.stderr
    print(f'{target}: large constant objects 4097..1047552 bytes, entry/nonentry paths, page/tail/call checks; 24 cases per mode; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-large-objects-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
