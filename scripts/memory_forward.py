#!/usr/bin/env python3
"""Independent exact-address forwarding and alias/mutation checks."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host


def inputs():
    source, declarations, checks = [], [], []
    for store, load, bits, signed in [('b','sb',8,True),('b','ub',8,False),('h','sh',16,True),
            ('h','uh',16,False),('w','sw',32,True),('w','uw',32,False),('l','l',64,False)]:
        for width in (['w','l'] if bits < 64 else ['l']):
            name=f'forward_{load}_{width}'
            ctype='uint32_t' if width=='w' else 'uint64_t'
            narrow=f'int{bits}_t' if signed else f'uint{bits}_t'
            source.append(f'''export function {width} ${name}(l %p,l %x) {{
@s
 store{store} %x,%p
 %a ={width} load{load} %p
 %b ={width} load{load} %p
 %r ={width} xor %a,%b
 %v ={width} add %r,%a
 ret %v
}}
''')
            declarations.append(f'extern {ctype} {name}(void *,uint64_t);')
            checks.append(f'memset(bytes,0,16);if({name}(bytes,seed)!=({ctype})({narrow})seed)return {len(checks)+1};memcpy(expected,&seed,8);if(memcmp(bytes,expected,{bits//8}))return {len(checks)+1};')
    for width,suffix,ctype in [('s','w','uint32_t'),('d','l','uint64_t')]:
        name=f'forward_float_{width}'
        source.append(f'''export function {suffix} ${name}(l %p,{suffix} %bits) {{
@s
 %x ={width} cast %bits
 store{width} %x,%p
 %y ={width} load{width} %p
 %r ={suffix} cast %y
 ret %r
}}
''')
        declarations.append(f'extern {ctype} {name}(void *,{ctype});')
        checks.append(f'memset(bytes,0,16);if({name}(bytes,({ctype})seed)!=({ctype})seed)return {len(checks)+1};memcpy(expected,&seed,8);if(memcmp(bytes,expected,sizeof({ctype})))return {len(checks)+1};')
    for operation, body in [
        ('alias','storeb 123,%q'),
        ('call','call $mutate_forward(l %q)'),
        ('result_call','%unused =l call $mutate_forward_result(l %q)'),
        ('indirect','call %fn(l %q)'),
        ('blit','blit %q,%p,8')]:
        source.append(f'''export function l $barrier_{operation}(l %p,l %q,l %fn) {{
@s
 %before =l loadl %p
 {body}
 %after =l loadl %p
 %r =l xor %before,%after
 ret %r
}}
''')
        declarations.append(f'extern uint64_t barrier_{operation}(void *,void *,void (*)(void *));')
        # Copies make the expected result independent of IR/codegen and avoid C alignment/alias UB.
        action='memmove(expected,expected+offset,8);' if operation=='blit' else 'expected[offset]=123;'
        offsets=[0,8] if operation=='blit' else list(range(9))
        for offset in offsets:
            checks.append(f'''memcpy(bytes,&seed,8);memcpy(bytes+8,&other,8);memcpy(expected,bytes,16);
 {{uint64_t before,after;memcpy(&before,expected,8);unsigned offset={offset};{action}memcpy(&after,expected,8);
 if(barrier_{operation}(bytes,bytes+offset,mutate_forward)!=(before^after))return {len(checks)+1};
 if(memcmp(bytes,expected,16))return {len(checks)+1};}}''')
    # Different access size/class and cross-block data must not accidentally reuse a load.
    source.append('''export function l $mixed_access(l %p) {
@s
 %a =w loadub %p
 %b =l loadl %p
 %wide =l extuw %a
 %r =l xor %wide,%b
 ret %r
}
export function l $loop_access(l %p,w %n) {
@s
 jmp @loop
@loop
 %i =w phi @s 0,@loop %next
 %sum =l phi @s 0,@loop %added
 %v =l loadl %p
 %added =l add %sum,%v
 %new =l add %v,1
 storel %new,%p
 %next =w add %i,1
 %more =w cultw %next,%n
 jnz %more,@loop,@done
@done
 ret %added
}
''')
    declarations.extend(['extern uint64_t mixed_access(void *);','extern uint64_t loop_access(void *,unsigned);'])
    checks.append('memcpy(bytes,&seed,8);if(mixed_access(bytes)!=(seed^(uint64_t)(uint8_t)seed))return 100;')
    checks.append('memcpy(bytes,&seed,8);unsigned n=i%32+1;if(loop_access(bytes,n)!=seed*n+(uint64_t)n*(n-1)/2)return 101;')
    caller='''#include <stdint.h>
#include <string.h>
'''+ '\n'.join(declarations)+'''
void mutate_forward(void *p){*(unsigned char *)p=123;}
uint64_t mutate_forward_result(void *p){mutate_forward(p);return 987;}
int main(void){
 unsigned char bytes[16],expected[16];uint64_t seed=UINT64_C(0x89abcdef01234567);
 for(unsigned i=0;i<1024;i++){
 seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;uint64_t other=~seed;
'''+ '\n'.join(checks)+'''
 }return 0;
}
'''
    return '\n'.join(source),caller,len(checks)*1024


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'memory-forward';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c'
    ir,c,count=inputs();source.write_text(ir);caller.write_text(c)
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
            if label=='optimized' and target.startswith('aarch64'):
                original=asm.read_text();damaged=original.replace('\tstrb ','\t// strb ',1)
                assert damaged!=original
                bad=case/'missing-store.s';bad.write_text(damaged);badexe=case/'missing-store'
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'missing store escaped independent memory oracle'
    print(f'{target}: memory forwarding: {count} independent truncation/FP/alias/call/blit/loop checks per mode; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-memory-forward-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
