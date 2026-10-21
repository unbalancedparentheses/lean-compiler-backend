#!/usr/bin/env python3
"""Compatibility CFG/SSA bounds and frame accesses beyond AArch64 immediate ranges."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject


def wide(name,width,count,dynamic=False):
    # Keep a named stack argument alive across a non-leaf frame larger than 32 KiB.
    args=','.join(f'{width} %p{i}' for i in range(9))
    lines=[f'export function {width} ${name}({args}) {{','@entry']
    if dynamic: lines += [' %size =l copy 32',' %object =l alloc16 %size']
    for i in range(count):lines += [f' %v{i} ={width} add %p8, {i}']
    lines += [f' %r ={width} call $identity_{width}({width} %v{count-1})',
              f' %sum ={width} add %r, %v0',f' ret %sum','}']
    return '\n'.join(lines)


def phi_function():
    lines=['export function w $wide_phi(w %a) {','@entry']
    for i in range(2300):lines += [f' %v{i} =w add %a, {i}']
    lines += [' jmp @loop','@loop',' %i =w phi @entry 0, @again %next',
              ' %left =w phi @entry %v0, @again %right',
              ' %right =w phi @entry %v2299, @again %left',
              ' %done =w ceqw %i, 3',' jnz %done, @end, @again','@again',
              ' %next =w add %i, 1',' jmp @loop','@end',' ret %left','}']
    return '\n'.join(lines)


def chain(count,mutable=False):
    lines=['export function l $chain(l %a) {']
    for i in range(count):
        lines += [f'@b{i}']
        if mutable: lines += [' %v =l copy %a' if i==0 else ' %v =l add %v, 1']
        if i+1<count: lines += [f' jmp @b{i+1}']
        else:
            if mutable: lines += [' %v =l add %v, %a',' ret %v']
            else: lines += [' ret %a']
    return '\n'.join(lines)+'\n}\n'


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-large-cfg-') as directory:
        work=Path(directory);source=work/'input.ssa'
        source.write_text('function w $identity_w(w %v) {\n@s\n ret %v\n}\n'+
                          'function l $identity_l(l %v) {\n@s\n ret %v\n}\n'+
                          wide('wide_word','w',2300)+'\n'+wide('wide_long','l',4500)+'\n'+
                          wide('wide_dynamic','l',4500,True)+'\n'+phi_function()+'\n')
        assembly=work/'lean.s';run([LCB, '--target', 'aarch64-macos',source,'-o',assembly])
        text=assembly.read_text()
        assert '[x15]' in text and 'add x15, x29,' in text, 'large frame addressing path not exercised'
        for name,count,width in [('wide_word',2300,32),('wide_long',4500,64),('wide_dynamic',4500,64)]:
            for value in [0,17,(1<<width)-1]:
                actual=int(run([LCB,'--eval',source,name,*([str(value)]*9)]))
                assert actual==(2*value+count-1)&((1<<width)-1)
        for value in [0,17,0xffffffff]:
            assert int(run([LCB,'--eval',source,'wide_phi',value]))==(value+2299)&0xffffffff
        c=work/'caller.c';c.write_text('''#include <stdint.h>
extern uint32_t wide_word(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
extern uint64_t wide_long(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t wide_dynamic(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint32_t wide_phi(uint32_t);
int main(void) {
 uint64_t values[]={0,17,UINT64_MAX,UINT64_C(0x1234567887654321)};
 for(unsigned i=0;i<4;i++) {
  uint64_t v=values[i]; uint32_t w=(uint32_t)v;
  if(wide_word(w,w,w,w,w,w,w,w,w)!=(uint32_t)(w+w+2299)) return 1;
  if(wide_long(v,v,v,v,v,v,v,v,v)!=v+v+4499) return 2;
  if(wide_dynamic(v,v,v,v,v,v,v,v,v)!=v+v+4499) return 3;
  if(wide_phi(w)!=(uint32_t)(w+2299)) return 4;
 }
 return 0;
}
''')
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            qa=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qa,source])
            for label,asm in [('lean',assembly),('qbe',qa)]:
                exe=work/label;run([cc,c,asm,'-o',exe]);run([exe])
            # Removing the high address part must corrupt an observed large slot.
            broken=work/'broken.s';changed=text.replace('add x15, x29, #8, lsl #12','add x15, x29, #0, lsl #12')
            assert changed!=text
            broken.write_text(changed);exe=work/'broken';run([cc,c,broken,'-o',exe])
            assert subprocess.run([exe],capture_output=True,timeout=120).returncode!=0
        source.write_text(chain(4096));run([LCB,'--check',source]);run([LCB, '--target', 'aarch64-macos',source,'-o',work/'chain.s'])
        assert int(run([LCB,'--eval',source,'chain',123]))==123
        reject([LCB,'--first-path',source],'blocks')
        source.write_text(chain(4097));reject([LCB,'--check',source],'block')
        source.write_text(chain(3000,True));run([LCB, '--target', 'aarch64-macos',source,'-o',work/'mutable.s'])
        assert int(run([LCB,'--eval',source,'chain',123]))==3245
        for count in [16384,16385]:
            source.write_text('function w $limit() {\n@entry\n'+''.join(f' %v{i} =w copy {i}\n' for i in range(count))+f' ret %v{count-1}\n}}\n')
            if count==16384: run([LCB,'--check',source])
            else: reject([LCB,'--check',source],'instruction')
    print('large CFG: 4096 blocks, 16384 instructions, 3000-block mutable SSA; large W/X slots, phi staging, saved LR and dynamic frames '+('passed native Lean/QBE/C and address corruption' if native_host() else 'checked; native unmeasured'))


if __name__=='__main__':main()
