#!/usr/bin/env python3
"""Exact ABI aggregate copies: independent C bytes, raw FP/GP arguments and guards."""
import argparse,hashlib,json,os,shlex,subprocess
from pathlib import Path
from data_relocations import native_host,QBE_TARGET
from fuzz import LCB
FP=[0x3ff4000000000000,0x8000000000000000,0x7ff8123456789abc,0x7ff0000000000000,0xfff0000000000000,0x0000000000000001,0x400921fb54442d18,0xbfe0000000000000]
GP=[17,23,0x8000000000000000,0xffffffffffffffff,131,257]
ENV=0x123456789abcdef0
SIZES=(127,128,129,130,131,132,133,134,135,136,255,256,257,4095,4096,4097,32767,32768,32769,65535,65536,65537)

def fixture(sizes,target):
    ir=[];c=['''#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
static unsigned char pattern(size_t i){return (unsigned char)((i*17+31)%251);}
static uint64_t bits(double d){uint64_t u;memcpy(&u,&d,8);return u;}
static double floating(uint64_t u){double d;memcpy(&d,&u,8);return d;}
static int guard_copy(size_t n,void (*into)(void*,void*),uint64_t (*out)(void*),uint64_t expected){
 size_t page=(size_t)sysconf(_SC_PAGESIZE),payload=(n+page-1)/page*page,total=payload+2*page;
 unsigned char *a=mmap(0,total,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0),*b=mmap(0,total,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);
 if(a==MAP_FAILED||b==MAP_FAILED)return 91;
 if(mprotect(a+page,payload,PROT_READ|PROT_WRITE)||mprotect(b+page,payload,PROT_READ|PROT_WRITE))return 92;
 for(unsigned side=0;side<2;side++){
  unsigned char *src=a+page+(side?0:payload-n),*dst=b+page+(side?0:payload-n);
  for(size_t i=0;i<n;i++){src[i]=pattern(i);dst[i]=0xcc;}
  into(dst,src);for(size_t i=0;i<n;i++)if(dst[i]!=pattern(i)||src[i]!=pattern(i))return 93;
  into(src,src);for(size_t i=0;i<n;i++)if(src[i]!=pattern(i))return 94;
  if(out&&out(src)!=expected)return 95;
  for(size_t i=0;i<n;i++)if(src[i]!=pattern(i))return 96;
 }
 munmap(a,total);munmap(b,total);return 0;
}
'''];shim=[];checks=[]
    fp_decl=','.join('double f'+str(i) for i in range(8));gp_decl=','.join('uint64_t g'+str(i) for i in range(6))
    cargs=','.join([f'floating(UINT64_C({x}))' for x in FP]+[f'UINT64_C({x})' for x in GP])
    args=', '.join([f'd {x}' for x in FP]+[f'l {x}' for x in GP])
    params=', '.join([f'd %f{i}' for i in range(8)]+[f'l %g{i}' for i in range(6)])
    for n in sizes:
        ty=f'big{n}';mid=n//2
        ir.append(f'type :{ty} = {{ b {n} }}')
        lines=[f'export function l $incoming{n}(:{ty} %p, {params}) {{','@entry']
        for i in range(8):lines.append(f' %u{i} =l cast %f{i}')
        prev='%u0'
        for i in range(1,8):lines.append(f' %x{i} =l xor {prev}, %u{i}');prev=f'%x{i}'
        for i in range(6):lines.append(f' %s{i} =l add {prev}, %g{i}');prev=f'%s{i}'
        lines += [f' %m =l add %p, {mid}',f' %e =l add %p, {n-1}',' %a =l loadub %p',' %b =l loadub %m',' %c =l loadub %e',f' %r0 =l add {prev}, %a',' %r1 =l add %r0, %b',' %r =l add %r1, %c',' storeb 99, %p',' storeb 101, %e',' ret %r','}'];ir.append('\n'.join(lines))
        ir += [f'export function l $out{n}(l %p) {{\n@s\n %r =l call $sink{n}(:{ty} %p, {args})\n ret %r\n}}',f'export function l $varout{n}(l %p) {{\n@s\n %r =l call $variadic{n}(:{ty} %p, ..., {args})\n ret %r\n}}',f'export function l $aliasout{n}(l %p) {{\n@s\n %r =l call $aliases{n}(:{ty} %p, :{ty} %p)\n ret %r\n}}',f'function l $environment{n}(env %env, :{ty} %p) {{\n@s\n %a =l loadub %p\n %r =l add %env, %a\n ret %r\n}}',f'export function l $envout{n}(l %p) {{\n@s\n %r =l call $environment{n}(env {ENV}, :{ty} %p)\n ret %r\n}}',f'export function :{ty} $echo{n}(:{ty} %p) {{\n@s\n ret %p\n}}',f'export function :{ty} $fromptr{n}(l %p) {{\n@s\n ret %p\n}}']
        original='\n'.join(lines)
        varloads=[' %ap =l alloc8 32',' vastart %ap']+[f' %f{i} =d vaarg %ap' for i in range(8)]+[f' %g{i} =l vaarg %ap' for i in range(6)]
        ir.append(original.replace(f'$incoming{n}(:{ty} %p, {params})',f'$varin{n}(:{ty} %p, ...)').replace('@entry','@entry\n'+'\n'.join(varloads),1))
        ir.append(original.replace(f'$incoming{n}(:{ty} %p, {params})',f'$prefixin{n}({params}, :{ty} %p)'))
        ir.append(f'export function l $prefixout{n}(l %p) {{\n@entry\n %r =l call $prefixsink{n}({args}, :{ty} %p)\n ret %r\n}}')
        c += [f'typedef struct {{ unsigned char b[{n}]; }} {ty};',f'extern uint64_t incoming{n}({ty},{fp_decl},{gp_decl});',f'extern uint64_t out{n}(void*),varout{n}(void*),aliasout{n}(void*),envout{n}(void*);',f'extern {ty} echo{n}({ty});',f'extern void into{n}(void*,void*);',f'static uint64_t mix{n}({fp_decl},{gp_decl}) {{ uint64_t r='+ '^'.join(f'bits(f{i})' for i in range(8))+';'+''.join(f'r+=g{i};' for i in range(6))+f'return r+pattern(0)+pattern({mid})+pattern({n-1});}}',f'uint64_t sink{n}({ty} b,{fp_decl},{gp_decl}) {{ for(size_t i=0;i<{n};i++)if(b.b[i]!=pattern(i))return UINT64_C(0xdeadbeef);return mix{n}('+','.join([f'f{i}' for i in range(8)]+[f'g{i}' for i in range(6)])+');}',f'uint64_t variadic{n}({ty} b,...) {{va_list ap;va_start(ap,b);'+''.join(f'double f{i}=va_arg(ap,double);' for i in range(8))+''.join(f'uint64_t g{i}=va_arg(ap,uint64_t);' for i in range(6))+'va_end(ap);'+f'return sink{n}(b,'+','.join([f'f{i}' for i in range(8)]+[f'g{i}' for i in range(6)])+');}',f'uint64_t aliases{n}({ty} a,{ty} b) {{for(size_t i=0;i<{n};i++)if(a.b[i]!=pattern(i)||b.b[i]!=pattern(i))return 0;a.b[0]=200;a.b[{n-1}]=201;for(size_t i=0;i<{n};i++)if(b.b[i]!=pattern(i))return 1;return {n}+17;}}',f'static int check{n}(void) {{{ty} b;for(size_t i=0;i<{n};i++)b.b[i]=pattern(i);uint64_t expected=mix{n}({cargs});if(incoming{n}(b,{cargs})!=expected)return 1;if(out{n}(&b)!=expected)return 2;if(varout{n}(&b)!=expected)return 3;if(aliasout{n}(&b)!={n}+17)return 4;if(envout{n}(&b)!=UINT64_C({ENV})+pattern(0))return 5;for(size_t i=0;i<{n};i++)if(b.b[i]!=pattern(i))return 6;{ty} r=echo{n}(b);if(memcmp(&r,&b,{n}))return 7;return guard_copy({n},into{n},out{n},expected);}}']
        names=','.join([f'f{i}' for i in range(8)]+[f'g{i}' for i in range(6)])
        c.insert(-1,f'extern uint64_t varin{n}({ty},...);extern uint64_t prefixin{n}({fp_decl},{gp_decl},{ty});extern uint64_t prefixout{n}(void*);uint64_t prefixsink{n}({fp_decl},{gp_decl},{ty} b){{return sink{n}(b,{names});}}')
        c[-1]=c[-1].replace(f'if(out{n}(&b)!=expected)',f'if(varin{n}(b,{cargs})!=expected)return 11;if(prefixin{n}({cargs},b)!=expected)return 12;if(prefixout{n}(&b)!=expected)return 13;if(out{n}(&b)!=expected)')
        name=f'into{n}';dest=f'fromptr{n}';prefix='_' if target.endswith('macos') else ''
        shim += ['.text',f'.globl {prefix}{name}',f'{prefix}{name}:']
        if target.startswith('aarch64'):shim+=[' mov x8, x0',' mov x0, x1',f' b {prefix}{dest}']
        elif target.startswith('x86_64'):shim += [f' jmp {prefix}{dest}']
        else:shim += [f' tail {dest}']
        checks.append(f'{{int r=check{n}();if(r){{fprintf(stderr,"size={n} check=%d\\n",r);return r;}}}}')
    ir += ['data $L_lcb_aggregate_copy_1_f_param0 = { l 37 }', 'data $"8" = { l 41 }', 'export function l $f(:big129 %p) {\n@entry\n %a =l loadl $L_lcb_aggregate_copy_1_f_param0\n %b =l loadl $"8"\n %c =l loadub %p\n %d =l add %a, %b\n %r =l add %d, %c\n ret %r\n}'] if 129 in sizes else []
    if 129 in sizes:
        c.append('extern uint64_t f(big129);static int collision(void){big129 p={{0}};p.b[0]=19;return f(p)!=97;}')
        checks.append('if(collision())return 97;')
    c.append('int main(void){'+''.join(checks)+'return 0;}')
    if target.endswith('linux'):shim.append('.section .note.GNU-stack,"",@progbits')
    return '\n'.join(ir)+'\n','\n'.join(c)+'\n','\n'.join(shim)+'\n'

def exercise(compiler,work,run,cc,target,execute=True,qbe=None,sizes=SIZES,maximum=True):
    work=Path(work)/'large-aggregate-abi';work.mkdir(parents=True,exist_ok=True);cc=list(cc) if isinstance(cc,(list,tuple)) else [cc]
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();calls=[];reports=[]
    def invoke(cmd,inside=False):
        cmd=list(map(str,cmd));r=run(cmd,inside);calls.append(dict(command=cmd,inside=inside,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));return r
    text,c,shim=fixture(sizes,target);source=work/'input.ssa';caller=work/'caller.c';thunk=work/'return-thunk.s';source.write_text(text);caller.write_text(c);thunk.write_text(shim)
    identity=invoke([compiler,'--build-identity']);assert identity.returncode==0
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',None)]:
        if label=='qbe' and not(execute and qbe):continue
        asm=work/(label+'.s');exe=work/label
        command=[qbe,'-t',QBE_TARGET[target],'-o',asm,source] if label=='qbe' else [compiler,source,'--target',target,*flags,'-o',asm]
        r=invoke(command,label=='qbe');assert r.returncode==0,calls[-1]
        row=dict(label=label,execution='not-run')
        if execute:
            r=invoke([*cc,caller,thunk,asm,'-o',exe],True)
            if r.returncode and label=='qbe' and target=='riscv64-linux':r=invoke([*cc,'-no-pie',caller,thunk,asm,'-o',exe],True);row['link_profile']='reference-only-no-PIE'
            assert r.returncode==0,calls[-1]
            r=invoke([exe],True);row.update(execution='passed' if r.returncode==0 else 'failed',exit=r.returncode)
            assert r.returncode==0,calls[-1]
        reports.append(row)
    control='not-run'
    if execute:
        text=(work/'optimized.s').read_text()
        old,new=({'aarch64':'str x14, [x13], #8','x86_64':'movq %xmm15, (%r11,%rax)','riscv64':'sd t0, 0(t3)'}[target.split('-')[0]],{'aarch64':'str xzr, [x13], #8','x86_64':'movq $0, (%r11,%rax)','riscv64':'sd zero, 0(t3)'}[target.split('-')[0]])
        assert old in text;bad=work/'wrong.s';bad.write_text(text.replace(old,new));exe=work/'wrong';assert invoke([*cc,caller,thunk,bad,'-o',exe],True).returncode==0
        r=invoke([exe],True);assert r.returncode!=0;control='zeroed ABI copy detected'
    boundaries=[]
    if maximum:
        boundary=work/'boundary';boundary.mkdir(exist_ok=True)
        for n in [1048575,1048576]:
            _,c,thunk_text=fixture([n],target)
            ir=f'type :big{n} = {{ b {n} }}\nexport function :big{n} $fromptr{n}(l %p) {{\n@entry\n ret %p\n}}\n'
            c=c[:c.index('typedef struct')]+f'extern void into{n}(void*,void*);int main(void){{return guard_copy({n},into{n},0,0);}}\n'
            src=boundary/f'{n}.ssa';src.write_text(ir);caller_max=boundary/f'{n}.c';caller_max.write_text(c);shim_max=boundary/f'{n}-thunk.s';shim_max.write_text(thunk_text)
            for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
                asm=boundary/f'{n}-{mode}.s';exe=boundary/f'{n}-{mode}'
                assert invoke([compiler,src,'--target',target,*flags,'-o',asm]).returncode==0,calls[-1]
                row=dict(size=n,mode=mode,source_sha256=sha(src),caller_sha256=sha(caller_max),thunk_sha256=sha(shim_max),assembly_sha256=sha(asm),execution='not-run')
                if execute:
                    assert invoke([*cc,caller_max,shim_max,asm,'-o',exe],True).returncode==0,calls[-1]
                    assert invoke([exe],True).returncode==0,calls[-1];row['execution']='passed'
                boundaries.append(row)
        for case,text,diagnostic in [
            ('one-past','type :huge = { b 1048576, b }\nexport function :huge $f(l %p) {\n@start\n ret %p\n}\n','limit'),
            ('frame','type :huge = { b 1048576 }\nexport function l $f(:huge %p) {\n@start\n %r =l loadub %p\n ret %r\n}\n','frame'),
            ('outgoing','type :huge = { b 1048576 }\nexport function l $f(l %p) {\n@start\n call $g(:huge %p, :huge %p)\n ret 0\n}\n','outgoing')]:
            src=boundary/(case+'.ssa');src.write_text(text)
            for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
                r=invoke([compiler,src,'--target',target,*flags,'-o',boundary/(case+'-'+mode+'.s')]);assert r.returncode!=0 and diagnostic in r.stderr,(case,calls[-1])
                boundaries.append(dict(refusal=case,mode=mode,source_sha256=sha(src),stderr=r.stderr))
    qbe_sha256=None
    if execute and qbe:
        r=invoke(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True);assert r.returncode==0,calls[-1];qbe_sha256=r.stdout.strip()
    report=dict(target=target,compiler_identity=identity.stdout.strip(),compiler_sha256=sha(compiler),harness_sha256=sha(__file__),source_sha256=sha(source),caller_sha256=sha(caller),thunk_sha256=sha(thunk),sizes=list(sizes),results=reports,boundaries=boundaries,qbe_sha256=qbe_sha256,original_qbe_scope='mixed ABI matrix through65537 only; maximum boundaries independent C only',executed_matrix_modes=sum(r['execution']=='passed' for r in reports),executed_maximum_modes=sum(r.get('execution')=='passed' for r in boundaries),control=control,commands=calls,note='Numeric local loop labels; exact forward copies preserve bases. Guarded hidden-return thunk is ABI-specific; ordinary C by-value calls and return echo independently exercise C ABI. Same-address and disjoint copies only; no memmove claim for partial overlaps.')
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(target,'aggregate ABI matrix passed',list(sizes),flush=True);return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--work',type=Path,default=Path('.build/large-aggregate-abi'));p.add_argument('--target',choices=QBE_TARGET,default=native_host());p.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));p.add_argument('--qbe',type=Path);p.add_argument('--runner',default='');p.add_argument('--emission-only','--no-execute',action='store_true');p.add_argument('--require-native',action='store_true');p.add_argument('--sizes',default=','.join(map(str,SIZES)));p.add_argument('--no-maximum',action='store_true');a=p.parse_args()
    execute=not a.emission_only and (a.target==native_host() or bool(a.runner))
    assert not a.require_native or execute
    def run(cmd,inside=False):
        if inside and len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe,[int(x) for x in a.sizes.split(',')],not a.no_maximum)
if __name__=='__main__':main()
