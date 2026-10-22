#!/usr/bin/env python3
"""Guarded-page C oracle for adjacent ARM64 unsigned load/extension selection."""
import argparse,hashlib,json,os,platform,re,shlex,subprocess,tempfile
from pathlib import Path
from fuzz import LCB


def fixture():
    functions=[];decl=[];checks=[];cases=[]
    for kind,bits,signed in [('ub',8,False),('uh',16,False),('sb',8,True),('sh',16,True)]:
        for ext in ['ub','uh']:
            for variant in ['adjacent','debug','block','alias','shared']:
                name=f'{kind}_{ext}_{variant}';lines=[f'export function l ${name}(l %p,l %q) {{','@s',f' %a =w load{kind} %p']
                if variant=='debug':lines+=[' dbgloc 8, 1']
                if variant=='block':lines+=[' jmp @next','@next']
                if variant=='alias':lines+=[' storeb 90,%q']
                lines += [f' %b =l ext{ext} %a']
                if variant=='shared':lines+=[' %wide =l extuw %a',' %r =l add %b,%wide',' ret %r']
                else:lines+=[' ret %b']
                lines+=['}'];functions.append('\n'.join(lines));decl.append(f'extern uint64_t {name}(void*,void*);')
                loaded=f'(uint32_t)({"int" if signed else "uint"}{bits}_t)seed';wanted=f'(uint64_t)(uint{8 if ext=="ub" else 16}_t)loaded'+('+loaded' if variant=='shared' else '')
                checks.append(f'''memcpy(p,&seed,{bits//8});memcpy(saved,p,{bits//8});
 {{uint32_t loaded={loaded};uint64_t expected={wanted};
 if({name}(p,p)!=expected)return 1;
 {"saved[0]=90;" if variant=="alias" else ""}
 if(memcmp(p,saved,{bits//8}))return 2;}}''')
                cases.append({'name':name,'bits':bits,'kind':kind,'ext':ext,'variant':variant,'matching':not signed and kind==ext})
    params=','.join(f'l %x{i}' for i in range(20));lines=[f'export function l $pressure(l %p,{params}) {{','@s',' %a =w loadub %p',' %b =l extub %a'];value='%b'
    for i in range(20):lines += [f' %sum{i} =l add {value},%x{i}'];value=f'%sum{i}'
    lines+=[' ret '+value,'}'];functions.append('\n'.join(lines));decl.append('extern uint64_t pressure(void*,'+','.join(['uint64_t']*20)+');')
    pressure='memcpy(p,&seed,1);if(pressure(p,'+','.join(str(i) for i in range(20))+')!=(uint8_t)seed+UINT64_C(190))return 3;'
    caller='''#define _GNU_SOURCE
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
'''+ '\n'.join(decl)+'''
int main(void){long page=sysconf(_SC_PAGESIZE);unsigned char *map=mmap(0,page*3,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);
if(map==MAP_FAILED||mprotect(map+page,page,PROT_READ|PROT_WRITE))return 10;
uint64_t state=UINT64_C(0xcafed00d12345678);uint64_t edges[]={0,127,128,255,256,32767,32768,65535,UINT64_MAX};
for(unsigned i=0;i<128;i++){state^=state<<13;state^=state>>7;state^=state<<17;uint64_t seed=i<9?edges[i]:state;
for(unsigned side=0;side<2;side++){unsigned char saved[2];unsigned char *p;
'''+ '\n'.join(f'p=side?map+page:map+2*page-{case["bits"]//8};\n'+check for case,check in zip(cases,checks))+'\np=side?map+page:map+2*page-1;'+pressure+'''}}
munmap(map,page*3);return 0;}
'''
    return 'dbgfile "arm-load-extensions.c"\n'+'\n'.join(functions)+'\n',caller,cases,(len(cases)+1)*256


def exercise(compiler,work,run,cc,target,execute=True):
    assert target in ['aarch64-linux','aarch64-macos'];d=Path(work)/'arm-load-extensions';d.mkdir(parents=True,exist_ok=True)
    ir,c,cases,count=fixture();src=d/'input.ssa';caller=d/'caller.c';src.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        p=run(cmd,inside);assert p.returncode==0,(cmd,p.stdout,p.stderr);return p
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(caller),'target':target,'checks_per_mode':count if execute else 0,'emitted_checks_per_mode':count,'modes':{},'negative_control':'not-run'}
    obj=d/'caller.o'
    if execute:checked([cc,'-O2','-c',caller,'-o',obj],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/(mode+'.s');exe=d/mode;checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text()
        def body(name):
            label=('_' if target.endswith('macos') else '')+name
            return text.split('\n'+label+':\n',1)[1].split('\n.globl ',1)[0].split('\n.size ',1)[0]
        if mode=='allocated':
            for kind,load,ext in [('ub','ldrb','uxtb'),('uh','ldrh','uxth')]:
                b=body(f'{kind}_{kind}_adjacent');assert not re.search(r'\t'+ext+r' w\d+, w\d+',b),b
                for v in ['debug','block','shared','alias']:
                    b=body(f'{kind}_{kind}_{v}');assert re.search(r'\t'+ext+r' w\d+, w\d+',b),(kind,v,b)
            assert '\tuxtb ' in body('sb_ub_adjacent')
            assert '\tuxtb ' in body('uh_ub_adjacent')
        if mode=='baseline':assert '\tuxtb ' in body('ub_ub_adjacent')
        report['modes'][mode]={'structural':'passed','execution':'not-run'}
        if execute:
            checked([cc,obj,asm,'-o',exe],True);checked([exe],True);report['modes'][mode]['execution']='passed'
            if mode=='allocated':
                # A widened byte load must fault on the end guard.
                b=body('ub_ub_adjacent');damaged=re.sub(r'\tldrb (w\d+),',r'\tldr \1,',b,count=1);assert damaged!=b
                bad=d/'overread.s';bad.write_text(text.replace(b,damaged,1));badexe=d/'overread';checked([cc,obj,bad,'-o',badexe],True)
                p=run([badexe],True);assert p.returncode!=0,'overread escaped guard';report['negative_control']={'status':'detected','exit':p.returncode}
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--work',type=Path);ap.add_argument('--target',choices=['aarch64-linux','aarch64-macos'],default='aarch64-macos' if platform.system()=='Darwin' else 'aarch64-linux');ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='');ap.add_argument('--require-native',action='store_true');a=ap.parse_args()
    execute=(platform.machine() in ['arm64','aarch64'] and ((platform.system()=='Darwin')==a.target.endswith('macos'))) or bool(a.runner)
    if a.require_native:assert execute
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(a.cc)+cmd[1:] if cmd[0]==a.cc else shlex.split(a.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
    if a.work:exercise(a.compiler.resolve(),a.work.resolve(),run,a.cc,a.target,execute)
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-arm-load-') as d:exercise(a.compiler.resolve(),Path(d),run,a.cc,a.target,execute)
if __name__=='__main__':main()
