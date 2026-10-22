#!/usr/bin/env python3
"""Independent full-byte/guard checks for constant block copies through 1 MiB."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import LCB, ROOT, native_host

SIZES=[0,1,7,8,127,128,129,130,135,136,4095,4096,4097,8191,8192,8193,65535,65536,65537,1048569,1048575,1048576]


def inputs(sizes=SIZES):
    source=[]
    for size in sizes:
        source.append('export function l $large_copy_'+str(size)+'''(l %src,l %dst,l %value) {
@s
 blit %src,%dst,'''+str(size)+'''
 %pointers =l xor %src,%dst
 %result =l xor %pointers,%value
 ret %result
}
''')
    source.append('''data $large_blit_source = align 16 { z 8193 }
export function w $interpreter_large_blit(l %left,l %right) {
@s
 %last =l add $large_blit_source,8192
 storeb %left,$large_blit_source
 storeb %right,%last
 %dst =l alloc16 8193
 blit $large_blit_source,%dst,8193
 %tail =l add %dst,8192
 %a =w loadub %dst
 %b =w loadub %tail
 %high =w shl %b,8
 %result =w or %a,%high
 ret %result
}
export function w $zero_unresolved() {
@s
 blit $undefined_zero_source,$undefined_zero_destination,0
 ret 7
}
export function l $copy_twice(l %src,l %middle,l %dst,l %value) {
@s
 blit %src,%middle,4097
 blit %middle,%dst,4097
 ret %value
}
''')
    declarations='\n'.join(f'extern uint64_t large_copy_{n}(void *,void *,uint64_t);' for n in sizes)
    entries=','.join('{'+str(n)+',large_copy_'+str(n)+'}' for n in sizes)
    caller='''#include <stdint.h>
#include <stdlib.h>
#include <string.h>
'''+declarations+'''
extern unsigned zero_unresolved(void);
extern unsigned interpreter_large_blit(uint64_t,uint64_t);
extern uint64_t copy_twice(void *,void *,void *,uint64_t);
typedef uint64_t (*copy_fn)(void *,void *,uint64_t);
static const struct {unsigned size;copy_fn fn;} cases[]={'''+entries+'''};
int main(void){
 const unsigned capacity=1048576+64;
 unsigned char *a=malloc(capacity),*b=malloc(capacity),*before=malloc(capacity),*expected=malloc(capacity),*middle=malloc(capacity);
 if(!a||!b||!before||!expected||!middle)return 90;
 if(zero_unresolved()!=7)return 91;
 for(unsigned i=0;i<32;i++)if(interpreter_large_blit(i*37u,65535u-i*17u)!=((i*37u&255)|((65535u-i*17u)&255)<<8))return 92;
 for(unsigned c=0;c<sizeof(cases)/sizeof(cases[0]);c++){
  for(unsigned alignment=0;alignment<3;alignment++){
   for(unsigned direction=0;direction<2;direction++){
    unsigned from=alignment?1+alignment:8,to=alignment?11+2*alignment:16;
    unsigned char *src=direction?a:b,*dst=direction?b:a;
    for(unsigned i=0;i<capacity;i++){src[i]=(unsigned char)((i*131u+(i>>8)+c*17u)^alignment);dst[i]=(unsigned char)(i*37u+c+99);}
    memcpy(before,src,capacity);memcpy(expected,dst,capacity);
    memcpy(expected+to,src+from,cases[c].size);
    uint64_t value=UINT64_C(0xfedcba9876543210)+c;
    if(cases[c].fn(src+from,dst+to,value)!=((uintptr_t)(src+from)^(uintptr_t)(dst+to)^value))return 1;
    if(memcmp(src,before,capacity)||memcmp(dst,expected,capacity))return 2;
    memcpy(before,dst,capacity);
    if(cases[c].fn(dst+to,dst+to,value)!=value)return 3;
    if(memcmp(dst,before,capacity))return 4;
   }
  }
 }
 memset(middle,37,capacity);memset(b,89,capacity);
 if(copy_twice(a+1,middle+3,b+7,UINT64_C(0xdeadbeef76543210))!=UINT64_C(0xdeadbeef76543210))return 5;
 if(memcmp(a+1,middle+3,4097)||memcmp(a+1,b+7,4097))return 6;
 free(a);free(b);free(before);free(expected);free(middle);return 0;
}
'''
    return '\n'.join(source),caller


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None,full_qbe=False):
    case=Path(work)/'large-blit';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c'
    ir,c=inputs();source.write_text(ir);caller.write_text(c)
    for left,right in [(0,0),(128,255),(18446744073709551615,32768)]:
        result=run([compiler,'--eval',source,'interpreter_large_blit',left,right])
        assert result.returncode==0,result.stderr
        assert int(result.stdout)==(left&255)|((right&255)<<8)
    caller_object=case/'caller.o'
    if execute:
        result=run([cc,'-O2','-c',caller,'-o',caller_object],True);assert result.returncode==0,result.stderr
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('qbe',[])] if qbe else []):
        asm,exe=case/(label+'.s'),case/label
        selected_source,selected_caller=source,caller_object
        if label=='qbe' and not full_qbe:
            selected_source=case/'qbe-input.ssa';reference_caller=case/'qbe-caller.c'
            reference_ir,reference_c=inputs([n for n in SIZES if n<=65537])
            selected_source.write_text(reference_ir);reference_caller.write_text(reference_c)
            selected_caller=case/'qbe-caller.o'
            if execute:
                result=run([cc,'-O2','-c',reference_caller,'-o',selected_caller],True);assert result.returncode==0,result.stderr
        command=[qbe,'-t',qtarget,'-o',asm,selected_source] if label=='qbe' else [compiler,source,'--target',target,*flags,'-o',asm]
        result=run(command,label=='qbe');assert result.returncode==0,(label,result.stderr)
        if label!='qbe':
            assert asm.stat().st_size<150000,'large copies must not expand into unbounded straight-line code'
            assert 'undefined_zero_' not in asm.read_text(),'zero copy retained undefined symbol references'
        if execute:
            result=run([cc,selected_caller,asm,'-o',exe],True)
            if result.returncode and label=='qbe' and target=='riscv64-linux' and 'R_RISCV_HI20' in result.stderr:
                print('original QBE RV64 default-PIE link failed; retrying unchanged reference assembly with -no-pie: '+result.stderr,flush=True)
                result=run([cc,'-no-pie',selected_caller,asm,'-o',exe],True)
            assert result.returncode==0,(label,result.stderr)
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
            if label=='optimized' and target.startswith('aarch64'):
                damaged=asm.read_text().replace('\tstr x11, [x10], #8','\tadd x10, x10, #8',1)
                assert damaged!=asm.read_text()
                bad,badexe=case/'missing-chunk.s',case/'missing-chunk';bad.write_text(damaged)
                result=run([cc,caller_object,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'missing loop chunk escaped full-byte oracle'
    invalid=case/'oversized.ssa';invalid.write_text('function w $f(l %p) { @s blit %p,%p,1048577 ret 0 }')
    result=run([compiler,invalid,'--target',target,'-o',case/'oversized.s'])
    assert result.returncode!=0 and '1 MiB resource limit' in result.stderr
    print(f'{target}: large blits: {len(SIZES)} sizes through 1 MiB, {len(SIZES)*12} aligned/unaligned/disjoint/identical full-byte cases per mode, repeated loops and zero unresolved symbols; execution={execute}; original-QBE={('through 1 MiB' if full_qbe else 'through 65537 bytes') if qbe else 'unmeasured'}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');ap.add_argument('--full-qbe',action='store_true',help='also run original QBE on the expensive 1 MiB expansion cases');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-large-blit-') as directory:
        work=Path(directory);qbe=None
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            result=run(['make','-C',oracle,'-j2','CC='+os.environ.get('LCB_CC','cc')]);assert result.returncode==0,result.stderr
            qbe=oracle/'qbe'
        exercise(LCB,work,run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host(),qbe,'arm64_apple',args.full_qbe)


if __name__=='__main__':main()
