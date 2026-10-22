#!/usr/bin/env python3
"""Independent C ABI pressure oracle for the bounded ARM leaf bank."""
import argparse, hashlib, json, os, platform, re, shlex, subprocess
from pathlib import Path

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def fixture():
    params=','.join(f'l %a{i}' for i in range(20)); cparams=','.join(['uint64_t']*20)
    ir=['type :triple = { l,l,l }','thread data $leaf_tls = { l 7 }'];decl=[]
    for variant in ['pressure','hidden','blit','dynamic','frame','loop','variadic','calling']:
        result=':triple' if variant=='hidden' else 'l';lines=[f'export function {result} ${variant}({params}{',...' if variant=='variadic' else ''}) {{','@s']
        if variant=='hidden':lines+=[' %out =l alloc8 24']
        if variant=='blit':lines+=[' %src =l alloc8 137',' %dst =l alloc8 137',' storel %a0,%src',' blit %src,%dst,137']
        if variant=='dynamic':lines+=[' %n =l and %a0,255',' %size =l add %n,16',' %out =l alloc8 %size',' storel %a1,%out']
        if variant=='frame':lines+=[' %out =l alloc8 40000',' %far =l add %out,39992',' storel %a19,%far']
        if variant=='loop':lines+=[' jmp @loop','@loop',' %it =l phi @s 0,@loop %next',' %acc =l phi @s 0,@loop %added',' %added =l add %acc,%a0',' %next =l add %it,1',' %test =w cultl %next,3',' jnz %test,@loop,@done','@done']
        if variant=='variadic':lines+=[' %ap =l alloc8 32',' vastart %ap',' %extra =l vaarg %ap',' %floating =d vaarg %ap',' %bits =l cast %floating']
        if variant=='calling':lines+=[' call $clobber()']
        val='%a0'
        for i in range(1,20):
            lines += [f' %v{i} =l add {val},%a{i}'];val=f'%v{i}'
        if variant=='hidden':lines += [f' storel {val},%out',' %p1 =l add %out,8',' storel %a0,%p1',' %p2 =l add %out,16',' storel %a19,%p2',' ret %out']
        elif variant=='blit':lines += [' %loaded =l loadl %dst',f' %r =l xor {val},%loaded',' ret %r']
        elif variant=='variadic':lines += [f' %plus =l add {val},%extra',' %r =l xor %plus,%bits',' ret %r']
        elif variant=='frame':lines += [' %loaded =l loadl %far',f' %r =l xor {val},%loaded',' ret %r']
        elif variant=='loop':lines += [f' %r =l add {val},%added',' ret %r']
        elif variant=='dynamic':lines += [' %loaded =l loadl %out',f' %r =l xor {val},%loaded',' ret %r']
        else:lines+=[' ret '+val]
        lines+=['}'];ir+=['\n'.join(lines)];decl += [f'extern {"struct triple" if variant=="hidden" else "uint64_t"} {variant}({cparams}{',...' if variant=='variadic' else ''});']
    for width,ctype in [('s','float'),('d','double')]:
        arguments=','.join(f'{width if i%2==0 else "l"} %a{i}' for i in range(20))
        lines=[f'export function l $raw_{width}({arguments}) {{','@s']
        val='0'
        for i in range(20):
            operand=f'%a{i}'
            if i%2==0:
                lines += [f' %bits{i} ={ "w" if width=="s" else "l"} cast %a{i}']
                operand=f'%bits{i}'
                if width=='s':lines += [f' %wide{i} =l extuw %bits{i}'];operand=f'%wide{i}'
            lines += [f' %xor{i} =l xor {val},{operand}'];val=f'%xor{i}'
        lines+=[' ret '+val,'}'];ir+=['\n'.join(lines)]
        decl += [f'extern uint64_t raw_{width}('+','.join(ctype if i%2==0 else 'uint64_t' for i in range(20))+');']
        lines=[f'export function {width} $convert_{width}('+','.join(f'{width} %a{i}' for i in range(19))+',l %integer) {','@s',f' %converted ={width} sltof %integer']
        val='%converted'
        for i in range(19):lines += [f' %sum{i} ={width} add {val},%a{i}'];val=f'%sum{i}'
        lines += [' ret '+val,'}'];ir+=['\n'.join(lines)]
        decl += [f'extern {ctype} convert_{width}('+','.join([ctype]*19+['int64_t'])+');']
    lines=[f'function l $environment_target(env %env,{params}) {{','@s'];val='%env'
    for i in range(20):lines += [f' %sum{i} =l add {val},%a{i}'];val=f'%sum{i}'
    lines += [' ret '+val,'}'];ir+=['\n'.join(lines)]
    ir += [f'export function l $environment_bridge(l %seed,{params}) {{\n@s\n %r =l call $environment_target(env %seed,'+','.join(f'l %a{i}' for i in range(20))+')\n ret %r\n}']
    decl += [f'extern uint64_t environment_bridge(uint64_t,{cparams});']
    ir+=['export function l $tls_value() {\n@s\n %p =l copy thread $leaf_tls\n %v =l loadl %p\n ret %v\n}']
    args=','.join(f'a[{i}]' for i in range(20))
    more_checks='uint64_t xs=0,xd=0;float fs[10],sf[19];double ds[10],df[19];\n'
    more_checks+='for(unsigned i=0;i<10;i++){uint32_t b=(uint32_t)a[2*i];memcpy(&fs[i],&b,4);memcpy(&ds[i],&a[2*i],8);xs^=b^a[2*i+1];xd^=a[2*i]^a[2*i+1];}\n'
    for width,array in [('s','fs'),('d','ds')]:
        more_checks+=f'if(raw_{width}('+','.join(f'{array}[{i//2}]' if i%2==0 else f'a[{i}]' for i in range(20))+f')!=x{width})return 9;\n'
    more_checks+='int64_t integer=(int64_t)(a[19]&255)-128;float es=(float)integer;double ed=(double)integer;for(unsigned i=0;i<19;i++){df[i]=(double)((int64_t)(a[i]&255)-128);sf[i]=(float)df[i];es+=sf[i];ed+=df[i];}\n'
    for width,array,expected in [('s','sf','es'),('d','df','ed')]:
        more_checks+=f'if(convert_{width}('+','.join(f'{array}[{i}]' for i in range(19))+f',integer)!={expected})return 10;\n'
    more_checks+=f'if(environment_bridge(a[0],{args})!=sum+a[0])return 11;\n'
    more_checks+=f'if(variadic({args},a[0]^a[1],ds[0])!=((sum+(a[0]^a[1]))^a[0]))return 12;\n'
    c='''#include <stdint.h>
#include <stdio.h>
#include <string.h>
struct triple {uint64_t a,b,c;};
__attribute__((noinline)) void clobber(void){__asm__ volatile("mov x8,#81\\nmov x16,#82\\nmov x17,#83":::"x8","x16","x17","memory");}
extern uint64_t tls_value(void);
'''+ '\n'.join(decl)+'''
int main(void){uint64_t a[20],state=UINT64_C(0x987654321abcdeff);
for(unsigned n=0;n<512;n++){uint64_t sum=0;for(unsigned i=0;i<20;i++){state^=state<<13;state^=state>>7;state^=state<<17;a[i]=n<4?(n==0?0:n==1?UINT64_MAX:n==2?UINT64_C(0x8000000000000000):UINT64_C(0x80000000)):state;sum+=a[i];}
'''+f'''if(pressure({args})!=sum)return 1;
struct triple r=hidden({args});if(r.a!=sum||r.b!=a[0]||r.c!=a[19])return 2;
if(blit({args})!=(sum^a[0]))return 3;
if(dynamic({args})!=(sum^a[1]))return 4;
if(frame({args})!=(sum^a[19]))return 7;
if(loop({args})!=(sum+3*a[0]))return 8;
if(calling({args})!=sum)return 5;
if(tls_value()!=7)return 6;
'''+more_checks+'}puts("7168 checks passed");return 0;}\n'
    return '\n'.join(ir)+'\n',c

def exercise(compiler,work,run,cc,target,execute=True,before=None):
    d=Path(work)/'arm-leaf-bank';d.mkdir(parents=True,exist_ok=True);source,caller=fixture();src=d/'input.ssa';src.write_text(source);c=d/'caller.c';c.write_text(caller)
    def checked(cmd,inside=False):
        r=run(list(map(str,cmd)),inside)
        assert r.returncode==0,(list(map(str,cmd)),r.returncode,r.stdout,r.stderr)
        return r
    report={'compiler_sha256':sha(compiler),'identity':checked([compiler,'--build-identity']).stdout.strip(),'script_sha256':sha(__file__),'source_sha256':sha(src),'caller_sha256':sha(c),'target':target,'modes':{},'executed_checks':0}
    obj=d/'caller.o'
    if execute:checked([cc,'-O2','-c',c,'-o',obj],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/f'{mode}.s';checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text()
        def body(name):return re.search(r'(?:;|//) function '+name+r';[\s\S]*?(?=(?:;|//) function |\Z)',text).group()
        if mode!='baseline':
            for reg in ['x16','x17','x8']:assert reg in body('pressure'),(reg,body('pressure'))
            assert not re.search(r'\b(?:str|ldr) x(?:16|17|8), \[(?:sp|x29)',body('pressure')),'caller bank unnecessarily saved'
        if before:
            old=d/f'{mode}-before.s';checked([before,src,'--target',target,*flags,'-o',old]);oldtext=old.read_text()
            if mode=='baseline':assert text==oldtext
            # Nonleaf and TLS functions must retain exact bytes/layout.
            for name in ['calling','tls_value']:
                oldbody=re.search(r'(?:;|//) function '+name+r';[\s\S]*?(?=(?:;|//) function |\Z)',oldtext).group();assert body(name)==oldbody,name
        report['modes'][mode]={'assembly_sha256':sha(asm),'execution':'not-run'}
        if mode!='baseline':
            counts={name:{str(reg):len(re.findall(r'\b[wx]'+str(reg)+r'\b',body(name))) for reg in [16,17,8]} for name in ['pressure','hidden','environment_target','raw_s','raw_d','convert_s','convert_d','variadic']}
            assert all(n>0 for regs in counts.values() for n in regs.values()),counts
            assert counts['hidden']['8']>1,counts
            report['modes'][mode]['expanded_bank_occurrences']=counts
        if execute:
            exe=d/mode;checked([cc,obj,asm,'-o',exe],True);r=checked([exe],True);assert r.stdout=='7168 checks passed\n';report['executed_checks']+=7168;report['modes'][mode]['execution']='passed'
            if mode=='allocated':
                # Deliberately route a live callee home through caller-clobbered x16.
                original=body('calling');assert 'x19' in original
                bad=d/'caller-clobber.s';bad.write_text(text.replace(original,original.replace('x19','x16').replace('w19','w16')));assert bad.read_text()!=text;badexe=d/'caller-clobber';checked([cc,obj,bad,'-o',badexe],True);r=run([str(badexe)],True);assert r.returncode!=0;report['caller_clobber_control']={'exit':r.returncode,'status':'detected'}
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def main():
    a=argparse.ArgumentParser();a.add_argument('--compiler',type=Path,required=True);a.add_argument('--before',type=Path);a.add_argument('--work',type=Path,required=True);a.add_argument('--target',default='aarch64-macos',choices=['aarch64-macos','aarch64-linux']);a.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));a.add_argument('--runner',default='');a.add_argument('--require-native',action='store_true');args=a.parse_args()
    execute=platform.machine() in ['arm64','aarch64'] and (platform.system()=='Darwin')==args.target.endswith('macos') or bool(args.runner)
    if args.require_native:assert execute
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(args.cc)+cmd[1:] if cmd[0]==args.cc else shlex.split(args.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
    print(json.dumps(exercise(args.compiler,args.work,run,args.cc,args.target,execute,args.before),indent=2))
if __name__=='__main__':main()
