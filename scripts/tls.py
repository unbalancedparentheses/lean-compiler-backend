#!/usr/bin/env python3
"""Darwin TLS descriptors and lookups, C interoperation and concurrent isolation."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

SOURCE='''export thread data $tls_counter = align 8 { l 7 }
thread export data $tls_array = align 16 { b 1, b 2, b 3, b 4, z 12 }
export function l $tls_read() {
@entry
 %v =l load thread $tls_counter
 ret %v
}
export function $tls_write(l %v) {
@entry
 storel %v, thread $tls_counter
 ret
}
export function l $tls_addr() {
@entry
 ret thread $tls_counter
}
export function l $tls_array_addr() {
@entry
 ret thread $tls_array
}
export function l $tls_select(w %choose) {
@entry
 jnz %choose, @counter, @array
@counter
 jmp @join
@array
 jmp @join
@join
 %address =l phi @counter thread $tls_counter, @array thread $tls_array
 ret %address
}
export function l $tls_add(l %a) {
@entry
 %r =l add %a, thread $tls_counter
 ret %r
}
export function l $tls_external() {
@entry
 %v =l load extern thread $external_tls
 ret %v
}
export function l $tls_model(l %v) {
@entry
 call $tls_write(l %v)
 %r =l call $tls_read()
 ret %r
}
export function l $tls_call() {
@entry
 %size =l copy 32
 %p =l alloc16 %size
 %r =l call $c_mix(l 11,d d_1.5,l 22,s s_2.5,l thread $tls_counter,l 33,l thread $tls_array,l 44,l 55,l 66,l 77,l 88,l thread $tls_counter,...,d d_3.5,l 99)
 ret %r
}
function w $word_result(w %a) {
@entry
 ret %a
}
export function l $word_widen(w %a) {
@entry
 %r =l call $word_result(w %a)
 ret %r
}
export function l $word_widen_indirect(w %a) {
@entry
 %fn =l copy $word_result
 %r =l call %fn(w %a)
 ret %r
}
'''

CALLER=r'''
#include <stdint.h>
#include <stdarg.h>
#include <pthread.h>
#include <stdio.h>
extern _Thread_local uint64_t tls_counter;
extern _Thread_local unsigned char tls_array[16];
_Thread_local uint64_t external_tls=123;
extern uint64_t tls_read(void),tls_addr(void),tls_add(uint64_t),tls_external(void),tls_call(void),tls_model(uint64_t);
extern uint64_t word_widen(uint32_t),word_widen_indirect(uint32_t),tls_select(uint32_t);
extern void tls_write(uint64_t);
uint64_t c_mix(uint64_t a,double f,uint64_t b,float g,uintptr_t p,uint64_t c,uintptr_t q,
               uint64_t d,uint64_t e,uint64_t h,uint64_t i,uint64_t j,uintptr_t r,...) {
 va_list ap; va_start(ap,r); double tail=va_arg(ap,double); uint64_t last=va_arg(ap,uint64_t); va_end(ap);
 if(a!=11 || f!=1.5 || b!=22 || g!=2.5 || c!=33 || d!=44 || e!=55 || h!=66 || i!=77 || j!=88 || tail!=3.5 || last!=99) return 0;
 if(p!=(uintptr_t)&tls_counter || r!=p || q!=(uintptr_t)tls_array || (q&15)) return 0;
 if(tls_array[0]!=1 || tls_array[3]!=4 || tls_array[15]!=0) return 0;
 return 777;
}
static pthread_mutex_t lock=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t ready=PTHREAD_COND_INITIALIZER;
static unsigned arrived;
static void *worker(void *argument) {
 uintptr_t id=(uintptr_t)argument;
 int bad=tls_counter!=7 || tls_read()!=7 || external_tls!=123;
 tls_counter=1000+id; external_tls=2000+id;
 pthread_mutex_lock(&lock);
 arrived++;
 if(arrived==8) pthread_cond_broadcast(&ready);
 while(arrived<8) pthread_cond_wait(&ready,&lock);
 pthread_mutex_unlock(&lock);
 bad|=tls_read()!=1000+id || tls_external()!=2000+id;
 bad|=tls_addr()!=(uintptr_t)&tls_counter || tls_add(id)!=(uintptr_t)&tls_counter+id;
 bad|=tls_call()!=777 || tls_select(1)!=(uintptr_t)&tls_counter || tls_select(0)!=(uintptr_t)tls_array;
 tls_write(3000+id);bad|=tls_counter!=3000+id;
 bad|=tls_model(4000+id)!=4000+id;
 return (void *)(uintptr_t)bad;
}
int main(void) {
 if(tls_read()!=7 || tls_external()!=123 || tls_call()!=777) return 1;
 for(unsigned i=0;i<4;i++) { uint32_t x=(uint32_t[]){0,1,0x80000000u,0xffffffffu}[i]; if(word_widen(x)!=x || word_widen_indirect(x)!=x) return 2; }
 pthread_t threads[8];
 for(uintptr_t i=0;i<8;i++) if(pthread_create(&threads[i],0,worker,(void *)i)) return 3;
 for(unsigned i=0;i<8;i++) { void *result; if(pthread_join(threads[i],&result) || result) return 4; }
 if(tls_counter!=7 || tls_read()!=7 || external_tls!=123) return 5;
 puts("TLS passed"); return 0;
}
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--require-native',action='store_true');options=parser.parse_args()
    if options.require_native:assert native_host()
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-tls-') as directory:
        work=Path(directory);src=work/'input.ssa';asm=work/'lean.s';c=work/'caller.c';src.write_text(SOURCE);c.write_text(CALLER);run([LCB, '--target', 'aarch64-macos',src,'-o',asm])
        assert int(run([LCB,'--eval',src,'tls_read']))==7
        for x in [0,1,0x80000000,0xffffffff,(1<<64)-1]:
            assert int(run([LCB,'--eval',src,'tls_model',x]))==x
            for name in ['word_widen','word_widen_indirect']:assert int(run([LCB,'--eval',src,name,x&0xffffffff]))==x&0xffffffff
        assert int(run([LCB,'--eval',src,'tls_read']))==7
        assert int(run([LCB,'--eval',src,'tls_select',1]))==int(run([LCB,'--eval',src,'tls_addr']))
        assert int(run([LCB,'--eval',src,'tls_select',0]))==int(run([LCB,'--eval',src,'tls_array_addr']))
        reject([LCB,'--eval',src,'tls_external'],'no interpreter model')
        for i,text in enumerate([
            'thread data $v={l 1} function l $f() { @s ret $v }',
            'data $v={l 1} function l $f() { @s ret thread $v }',
            'thread function l $f() { @s ret 0 }',
            'thread data $v={l 1} data $p={l $v}',
            'function l $f() { @s ret thread $f }',
        ]):
            bad=work/f'bad{i}.ssa';bad.write_text(text);reject([LCB,'--check',bad],'')
        restricted=work/'restricted.ssa';restricted.write_text('function l $f() { @s ret thread $external_tls }');reject([LCB,'--first-path',restricted],'thread-local')
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);run(['make','-j2',f'CC={cc}'],cwd=oracle)
            reproducer=ROOT/'tests/regressions/qbe-two-tls-call-arguments.ssa'
            rejected=subprocess.run([oracle/'qbe','-t','arm64_apple',reproducer],capture_output=True,text=True)
            assert rejected.returncode and 'isreg(i->to)' in rejected.stderr, 'pinned QBE TLS regression changed'
            reduced=work/'reduced.s';run([LCB, '--target', 'aarch64-macos',reproducer,'-o',reduced])
            run([cc,reproducer.with_suffix('.c'),reduced,'-o',work/'reduced']);run([work/'reduced'])
            # QBE 1.3 cannot allocate two inline TLV arguments. Use explicit helper
            # calls for its comparison, retaining the original input for Lean/C.
            rewritten=SOURCE.replace(' %r =l call $c_mix', ' %counter =l call $tls_addr()\n %array =l call $tls_array_addr()\n %r =l call $c_mix')
            rewritten='\n'.join(line.replace('thread $tls_counter','%counter').replace('thread $tls_array','%array') if '$c_mix' in line else line for line in rewritten.splitlines())+'\n'
            qsrc=work/'qbe-helper-input.ssa';qsrc.write_text(rewritten)
            qasm=work/'qbe.s';run([oracle/'qbe','-t','arm64_apple','-o',qasm,qsrc])
            for label,assembly in [('lean',asm),('qbe',qasm)]:
                exe=work/label;run([cc,'-std=c11','-O2','-pthread',c,assembly,'-o',exe]);run([exe])
            damaged=work/'damaged.s';damaged.write_text(asm.read_text().replace('\t.quad 7\n','\t.quad 8\n'));run([cc,'-std=c11','-O2','-pthread',c,damaged,'-o',work/'damaged']);reject([work/'damaged'],'')
        print('TLS: single-thread interpreter initialization/access and signature controls; '+('8 concurrent C threads, native Lean/C isolation and mixed live arguments passed; original QBE two-TLS-call assertion reproduced (not a match), helper-form QBE comparison and corruption passed' if native_host() else 'native execution unmeasured'))

if __name__=='__main__':main()
