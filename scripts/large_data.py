#!/usr/bin/env python3
"""Sparse native globals with an independently bounded interpreter allocation budget."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host

SIZE = 16*1024*1024


def exercise(compiler, work, run, cc, target, execute=True):
    case = Path(work)/'large-data';case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa',case/'caller.c'
    source.write_text(f'''export data $scratch = align 64 {{ z {SIZE} }}
export data $adjacent = align 32 {{ z 17 }}
export data $mixed = {{ z 8, b 93, z 8 }}
export data $scratch_end = {{ l $scratch+{SIZE-1} }}
export function l $touch(l %index,l %value) {{
@s
 %p =l add $scratch,%index
 storeb %value,%p
 %r =l loadub %p
 ret %r
}}
''')
    caller.write_text(f'''#include <stdint.h>
#include <stdio.h>
extern unsigned char scratch[{SIZE}],adjacent[17],mixed[17],*scratch_end;
extern uint64_t touch(uint64_t,uint64_t);
int main(void) {{
 if(((uintptr_t)scratch&63)||((uintptr_t)adjacent&31)||scratch_end!=scratch+{SIZE-1})return 1;
 for(unsigned i=0;i<17;i++)if(adjacent[i]||mixed[i]!=(i==8?93:0))return 2;
 for(uint64_t i=0;i<{SIZE};i+=4096){{if(scratch[i])return 3;if(touch(i,i/4096)!=((i/4096)&255))return 4;}}
 if(scratch[{SIZE-1}]||touch({SIZE-1},173)!=173)return 5;
 for(uint64_t i=0;i<{SIZE};i+=4096)if(scratch[i]!=((i/4096)&255))return 6;
 for(unsigned i=0;i<17;i++)if(adjacent[i])return 7;
 return 0;
}}
''')
    result=run([compiler,'--eval',source,'touch','0','0'])
    assert result.returncode and 'interpreter initialization budget' in result.stderr,result.stderr
    for label,flags in [('baseline',[]),('optimized',['--optimize'])]:
        asm,obj,exe=case/(label+'.s'),case/(label+'.o'),case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        output=asm.read_text();assert '.zerofill __DATA,__bss' in output if target.endswith('macos') else '.bss' in output
        if execute:
            result=run([cc,'-c',asm,'-o',obj],True);assert result.returncode==0,result.stderr
            # A 16 MiB zero-only global must occupy virtual BSS, not file-backed bytes.
            assert obj.stat().st_size<65536,(target,'zero-filled data bloated object',obj.stat().st_size)
            result=run([cc,caller,obj,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
    boundary=case/'boundary.ssa';boundary.write_text('data $bound = { z 268435456 }')
    result=run([compiler,'--check',boundary]);assert result.returncode==0,result.stderr
    for text,diagnostic in [('data $bad = { z 268435457 }','zero fill size'),
                            ('data $x = { z 268435456 } data $y = { b 0 }','module data exceeds')]:
        boundary.write_text(text);result=run([compiler,'--check',boundary]);assert result.returncode and diagnostic in result.stderr,result.stderr
    print(f'{target}: 16 MiB BSS, 4096 page offsets/tail, alignment and relocation, compact objects, 256 MiB admission boundary and interpreter refusal; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-large-data-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
