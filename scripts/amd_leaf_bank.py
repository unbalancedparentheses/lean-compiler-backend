#!/usr/bin/env python3
"""Independent C ABI oracle for restricted AMD64 leaf register homes."""
import argparse,hashlib,json,os,platform,re,shlex,subprocess
from pathlib import Path

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def fixture():
    ir=['type :triple = {l,l,l}','type :mix = {l,d}','thread data $leaf_tls = {l 7}'];decl=[];checks=[];eligible=[]
    for name,gps in [('pressure',1),('gp4',4),('gp5',5),('gp6',6),('hidden',3),('hidden4',4),('blit',1),('dynamic',1),('frame',1),('loop',1),('calling',1),('variadic',4),('environment_target',4),('mixed',3),('rollback',2)]:
        params=['l %p']+[f'l %s{i}' for i in range(1,gps)];ctypes=['uint64_t*']+['uint64_t']*(gps-1);args=['a']+[f'a[{i}]' for i in range(1,gps)];terms=['sum']+[f'a[{i}]' for i in range(1,gps)]
        result=':triple' if name in ['hidden','hidden4'] else 'l'
        if name=='environment_target':params=['env %env']+params
        if name in ['mixed','rollback']:
            params=[':mix %mix']+params;ctypes=['struct mix']+ctypes;args=['mix']+args;terms+=['a[0]','a[19]']
        if name=='rollback':
            params=[f'd %f{i}' for i in range(8)]+params;ctypes=['double']*8+ctypes;args=['0.0']*8+args
        if name=='variadic':params+=['...'];ctypes+=['...']
        lines=[f'export function {result} ${name}('+','.join(params)+') {','@s']
        if name in ['hidden','hidden4']:lines+=[' %out =l alloc8 24']
        if name=='blit':lines+=[' %dst =l alloc8 160',' blit %p,%dst,160']
        if name in ['dynamic','frame']:
            lines+=[' %n =l loadl %p',' %masked =l and %n,255',' %size =l add %masked,40000',f' %out =l alloc8 {"%size" if name=="dynamic" else "40000"}',' %far =l add %out,39992',' storel 99,%far']
        for i in range(20):lines += [f' %p{i} =l add %p,{i*8}',f' %v{i} =l loadl %p{i}']
        extra=[]
        if name=='calling':lines+=[' call $clobber()']
        if name=='variadic':lines+=[' %ap =l alloc8 32',' vastart %ap',' %extra =l vaarg %ap',' %floating =d vaarg %ap',' %bits =l cast %floating'];extra+=['%extra']
        if name=='loop':lines+=[' jmp @loop','@loop',' %it =l phi @s 0,@loop %next',' %acc =l phi @s 0,@loop %added',' %added =l add %acc,%v0',' %next =l add %it,1',' %test =w cultl %next,3',' jnz %test,@loop,@done','@done'];extra+=['%added'];terms+=['3*a[0]']
        if name in ['mixed','rollback']:lines+=[' %m0 =l loadl %mix',' %mp =l add %mix,8',' %m1 =l loadl %mp'];extra+=['%m0','%m1']
        val='0';values=[f'%v{i}' for i in range(20)]+[f'%s{i}' for i in range(1,gps)]+extra+(['%env'] if name=='environment_target' else [])
        for i,v in enumerate(values):lines += [f' %sum{i} =l add {val},{v}'];val=f'%sum{i}'
        if name in ['hidden','hidden4']:lines += [f' storel {val},%out',' %o1 =l add %out,8',' storel %v0,%o1',' %o2 =l add %out,16',' storel %v19,%o2',' ret %out']
        elif name=='variadic':lines += [f' %r =l xor {val},%bits',' ret %r']
        elif name in ['dynamic','frame']:lines += [' %stored =l loadl %far',f' %r =l add {val},%stored',' ret %r'];terms+=['99']
        else:lines+=[' ret '+val]
        lines+=['}'];ir+=['\n'.join(lines)]
        if name not in ['gp5','gp6','hidden4','calling']:eligible+=[name]
        if name=='environment_target':
            ir+=['export function l $environment_bridge(l %env,'+','.join(params[1:])+') {\n@s\n %r =l call $environment_target(env %env,'+','.join(['l %p']+[f'l %s{i}' for i in range(1,gps)])+')\n ret %r\n}'];name='environment_bridge';ctypes=['uint64_t']+ctypes;args=['a[0]']+args;terms+=['a[0]']
        decl+=[f'extern {"struct triple" if result==":triple" else "uint64_t"} {name}('+','.join(ctypes)+');'];call=name+'('+','.join(args)+')';expected='('+ '+'.join(terms)+')'
        if result==':triple':checks += [f'{{struct triple r={call};if(r.a!={expected}||r.b!=a[0]||r.c!=a[19])return 2;}}']
        elif name=='variadic':checks += [f'if(variadic('+','.join(args)+f',a[0]^a[1],mix.b)!=(({expected}+(a[0]^a[1]))^a[19]))return 3;']
        else:checks += [f'if({call}!={expected})return 4;']
    for kind,ctype,signed in [('sb','int8_t',True),('ub','uint8_t',False),('sh','int16_t',True),('uh','uint16_t',False)]:
        name='subword_'+kind;lines=[f'export function l ${name}(l %p,{kind} %small) {{','@s',f' %extended =l {"extsw" if signed else "extuw"} %small']
        for i in range(20):lines += [f' %p{i} =l add %p,{i*8}',f' %v{i} =l loadl %p{i}']
        val='%extended'
        for i in range(20):lines += [f' %sum{i} =l add {val},%v{i}'];val=f'%sum{i}'
        lines+=[' ret '+val,'}'];ir+=['\n'.join(lines)];eligible+=[name];decl+=[f'extern uint64_t {name}(uint64_t*,{ctype});'];checks+=[f'if({name}(a,({ctype})a[0])!=sum+(uint64_t)({"int64_t" if signed else "uint64_t"})({ctype})a[0])return 8;']
    for width,ctype in [('s','float'),('d','double')]:
        params=[f'{width} %a{i}' for i in range(18)]+['l %x','l %y'];lines=[f'export function l $raw_{width}('+','.join(params)+') {','@s'];val='%x'
        for i in range(18):
            lines += [f' %b{i} ={ "w" if width=="s" else "l"} cast %a{i}'];v=f'%b{i}'
            if width=='s':lines+=[f' %w{i} =l extuw %b{i}'];v=f'%w{i}'
            lines += [f' %r{i} =l xor {val},{v}'];val=f'%r{i}'
        lines+= [f' %r =l xor {val},%y',' ret %r','}'];ir+=['\n'.join(lines)];eligible += ['raw_'+width]
        decl += [f'extern uint64_t raw_{width}('+','.join([ctype]*18+['uint64_t','uint64_t'])+');'];checks += [f'if(raw_{width}('+','.join(f'{"fs" if width=="s" else "ds"}[{i}]' for i in range(18))+f',a[18],a[19])!=x{width})return 5;']
        lines=[f'export function {width} $convert_{width}('+','.join(f'{width} %a{i}' for i in range(19))+',l %integer) {','@s',f' %converted ={width} sltof %integer'];val='%converted'
        for i in range(19):lines += [f' %v{i} ={width} add {val},%a{i}'];val=f'%v{i}'
        lines+=[' ret '+val,'}'];ir+=['\n'.join(lines)];eligible += ['convert_'+width]
        decl += [f'extern {ctype} convert_{width}('+','.join([ctype]*19+['int64_t'])+');'];checks += [f'if(convert_{width}('+','.join(f'{"sf" if width=="s" else "df"}[{i}]' for i in range(19))+f',integer)!=e{width})return 6;']
    ir+=['export function l $tls_value() {\n@s\n %p =l copy thread $leaf_tls\n %v =l loadl %p\n ret %v\n}'];decl+=['extern uint64_t tls_value(void);'];checks+=['if(tls_value()!=7)return 7;']
    count=len(checks)*256
    c='''#include <stdint.h>
#include <stdio.h>
#include <string.h>
struct triple {uint64_t a,b,c;};struct mix{uint64_t a;double b;};
__attribute__((noinline)) void clobber(void){__asm__ volatile("movq $81, %%r8\\nmovq $82, %%r9":::"r8","r9","memory");}
'''+ '\n'.join(decl)+'''
int main(void){uint64_t a[20],state=UINT64_C(0x987654321abcdeff);
for(unsigned n=0;n<256;n++){uint64_t sum=0;for(unsigned i=0;i<20;i++){state^=state<<13;state^=state>>7;state^=state<<17;a[i]=n<4?(n==0?0:n==1?UINT64_MAX:n==2?UINT64_C(0x8000000000000000):UINT64_C(0x80000000)):state;sum+=a[i];}
struct mix mix={.a=a[0]};memcpy(&mix.b,&a[19],8);
float fs[18],sf[19];double ds[18],df[19];uint64_t xs=a[18]^a[19],xd=xs;
for(unsigned i=0;i<18;i++){uint32_t b=(uint32_t)a[i];memcpy(&fs[i],&b,4);memcpy(&ds[i],&a[i],8);xs^=b;xd^=a[i];}
int64_t integer=(int64_t)(a[19]&255)-128;float es=(float)integer;double ed=(double)integer;
for(unsigned i=0;i<19;i++){df[i]=(double)((int64_t)(a[i]&255)-128);sf[i]=(float)df[i];es+=sf[i];ed+=df[i];}
'''+ '\n'.join(checks)+f'\n}}puts("{count} checks passed");return 0;}}\n'
    return '\n'.join(ir)+'\n',c,eligible,count

def exercise(compiler,work,run,cc,target,execute=True,before=None):
    d=Path(work)/'amd-leaf-bank';d.mkdir(parents=True,exist_ok=True);source,caller,eligible,count=fixture();src=d/'input.ssa';src.write_text(source);c=d/'caller.c';c.write_text(caller)
    def checked(cmd,inside=False):
        r=run(list(map(str,cmd)),inside);assert r.returncode==0,(list(map(str,cmd)),r.returncode,r.stdout,r.stderr);return r
    report={'compiler_sha256':sha(compiler),'identity':checked([compiler,'--build-identity']).stdout.strip(),'script_sha256':sha(__file__),'source_sha256':sha(src),'caller_sha256':sha(c),'target':target,'modes':{},'executed_checks':0};obj=d/'caller.o'
    if before:report['before_sha256']=sha(before)
    if execute:checked([cc,'-O2','-c',c,'-o',obj],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/f'{mode}.s';checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text();prefix='_' if target.endswith('macos') else ''
        def body(text,name):
            start=text.index(prefix+name+':\n');end=text.find('\n.text',start);return text[start:end if end>=0 else len(text)]
        if before:
            old=d/f'{mode}-before.s';checked([before,src,'--target',target,*flags,'-o',old]);oldtext=old.read_text()
            if mode=='baseline':assert text==oldtext
            for name in ['gp5','gp6','hidden4','calling','tls_value','environment_bridge']:assert body(text,name)==body(oldtext,name),name
        report['modes'][mode]={'assembly_sha256':sha(asm),'execution':'not-run'}
        if mode!='baseline':
            counts={name:{str(reg):len(re.findall(r'%r'+str(reg)+r'(?:d|w|b)?\b',body(text,name))) for reg in [8,9]} for name in eligible}
            assert all(n>=2 for regs in counts.values() for n in regs.values()),counts
            writes={name:{str(reg):len(re.findall(r'\tmovq %rax, %r'+str(reg)+r'\b',body(text,name))) for reg in [8,9]} for name in eligible}
            assert all(n>0 for regs in writes.values() for n in regs.values()),writes
            report['modes'][mode]['extra_bank_home_writes']=writes
            report['modes'][mode]['extra_bank_occurrences']=counts
        if execute:
            exe=d/mode;checked([cc,obj,asm,'-o',exe],True);r=checked([exe],True);assert r.stdout==f'{count} checks passed\n';report['executed_checks']+=count;report['modes'][mode]['execution']='passed'
            if mode=='allocated':
                controls={}
                for name in ['calling','gp5','gp6']:
                    original=body(text,name)
                    # Replace a real early incoming home, including its later reads.
                    homes=re.findall(r'\tmovq %rax, %(rbx|r1[2-5])',original.split('\n.L_lcb_')[0].split('\nL_lcb_')[0]);assert homes,name
                    oldreg=homes[0];reg='r9' if name=='gp6' else 'r8'
                    order={}
                    if name in ['gp5','gp6']:
                        first_write=original.index('\tmovq %rax, %'+oldreg);later_read=original.index('\tmovq %'+reg+', %rax');assert first_write<later_read
                        order={'early_home_write_offset':first_write,'later_incoming_read_offset':later_read}
                    changed=original.replace('%'+oldreg,'%'+reg);assert changed!=original
                    bad=d/(name+'-corrupt.s');bad.write_text(text.replace(original,changed));badexe=d/(name+'-corrupt');checked([cc,obj,bad,'-o',badexe],True);r=run([str(badexe)],True);assert r.returncode!=0,(name,'mutation escaped');controls[name]={'exit':r.returncode,'status':'detected',**order}
                report['negative_controls']=controls
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def main():
    p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--before',type=Path);p.add_argument('--work',type=Path,required=True);p.add_argument('--target',choices=['x86_64-linux','x86_64-macos'],default='x86_64-macos' if platform.system()=='Darwin' else 'x86_64-linux');p.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));p.add_argument('--runner',default='');p.add_argument('--require-native',action='store_true');a=p.parse_args()
    execute=(platform.machine() in ['x86_64','amd64'] and (platform.system()=='Darwin')==a.target.endswith('macos')) or bool(a.runner)
    if a.require_native:assert execute
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(a.cc)+cmd[1:] if cmd[0]==a.cc else shlex.split(a.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
    print(json.dumps(exercise(a.compiler,a.work,run,a.cc,a.target,execute,a.before),indent=2))
if __name__=='__main__':main()
