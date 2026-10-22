#!/usr/bin/env python3
"""Independent byte/ABI oracle for adjacent ARM temporary-indexed loads."""
import hashlib,json,re,subprocess
from pathlib import Path

def fixture():
    ir=[];decl=[];checks=[];names=[];guard_checks=[]
    for op,bits,signed in [('sb',8,True),('ub',8,False),('sh',16,True),('uh',16,False),('sw',32,True),('uw',32,False),('l',64,False),('s',32,False),('d',64,False)]:
        for width in (['w','l'] if bits<64 and op not in ['s'] else ['w'] if op=='s' else ['l']):
            ctype='uint32_t' if width=='w' else 'uint64_t';loaded=op if op in ['s','d'] else width
            for variant in ['adjacent','commuted','debug','shared','separated','block']:
                name=f'{op}_{width}_{variant}';lines=[f'export function {width} ${name}(l %p,l %index) {{','@s',' %address =l add '+('%index,%p' if variant=='commuted' else '%p,%index')]
                if variant=='debug':lines+=[' dbgloc 31, 2']
                if variant=='separated':lines+=[' %other =l xor %index,918273']
                if variant=='block':lines+=[' jmp @load','@load']
                lines += [f' %loaded ={loaded} load{op} %address']
                value='%loaded'
                if op in ['s','d']:lines += [f' %bits ={width} cast %loaded'];value='%bits'
                if variant in ['shared','separated']:
                    lines += [f' %result ={width} xor {value},'+('%address' if variant=='shared' else '%other')];value='%result'
                lines += [' ret '+value,'}'];ir+=['\n'.join(lines)];decl+=[f'extern {ctype} {name}(void*,uint64_t);'];names.append((name,variant))
                narrow=('int' if signed else 'uint')+str(bits)+'_t';expected=f'({ctype})({narrow})raw'
                if variant=='shared':expected+=f'^({ctype})(uintptr_t)(p+offset)'
                if variant=='separated':expected+=f'^({ctype})((uint64_t)offset^UINT64_C(918273))'
                if variant=='adjacent':guard_checks.append(f'{{unsigned char*q=side?map+page:map+2*page-{bits//8};memcpy(q,&seed,{bits//8});uint64_t raw=0;memcpy(&raw,q,{bits//8});if({name}(q-64,64)!=({expected}))return 11;}}')
                checks += [f'{{uint64_t raw=0;memcpy(&raw,p+offset,{bits//8});if({name}(p,(uint64_t)offset)!=({expected}))return 1;}}']
    params=','.join(f'l %a{i}' for i in range(24));lines=[f'export function l $pressure(l %p,l %index,{params}) {{','@s',' %address =l add %p,%index',' %loaded =l loadl %address',' jmp @loop','@loop',' %n =w phi @s 0,@loop %next',' %acc =l phi @s 0,@loop %sum23'];v='%acc'
    for i in range(24):lines += [f' %mixed{i} =l xor %a{i}, {1234567+i}',f' %sum{i} =l add {v},%mixed{i}'];v=f'%sum{i}'
    lines += [' %next =w add %n,1',' %again =w cultw %next,3',' jnz %again,@loop,@done','@done',' %result =l add %sum23,%loaded',' ret %result','}'];ir+=['\n'.join(lines)];decl+=['extern uint64_t pressure(void*,uint64_t,'+','.join(['uint64_t']*24)+');']
    args=','.join(f'seed+{i}' for i in range(24));checks += ['{uint64_t expected=0,raw;memcpy(&raw,p+offset,8);for(unsigned j=0;j<24;j++)expected+=(seed+j)^(UINT64_C(1234567)+j);'+f'if(pressure(p,(uint64_t)offset,{args})!=3*expected+raw)return 2;}}']
    pressure_ir=ir[-1];pressure_decl=decl[-1]
    for variant in ['reverse','live','live_reverse','live_largeframe']:
        name='pressure_'+variant;body=pressure_ir.replace('$pressure(',f'${name}(')
        if 'reverse' in variant:body=body.replace('add %p,%index','add %index,%p')
        if 'live' in variant:body=body.replace(' ret %result',' %keep =l xor %p,%index\n %final =l xor %result,%keep\n ret %final')
        if variant=='live_largeframe':body=body.replace('@s\n','@s\n %frame =l alloc16 65536\n %last =l add %frame,65528\n storel 0,%last\n',1).replace(' ret %final',' %zero =l loadl %last\n %output =l xor %final,%zero\n ret %output')
        ir += [body];decl += [pressure_decl.replace('pressure(',name+'(')]
        expected='(3*expected+raw)^((uintptr_t)p^(uint64_t)offset)' if 'live' in variant else '3*expected+raw'
        checks += ['{uint64_t expected=0,raw;memcpy(&raw,p+offset,8);for(unsigned j=0;j<24;j++)expected+=(seed+j)^(UINT64_C(1234567)+j);'+f'if({name}(p,(uint64_t)offset,{args})!=({expected}))return 2;}}']
    # Vary live pressure and operand order. Inputs remain live after the load;
    # allocation-specific scratch/home patterns are inventoried below.
    for size in [8,10,12,16,24]:
        for order in ['normal','reverse']:
            name=f'live_{size}_{order}';params=','.join(f'l %a{i}' for i in range(size))
            lines=[f'export function l ${name}(l %p,l %index,{params}) {{','@s',' %address =l add '+('%p,%index' if order=='normal' else '%index,%p'),' %loaded =l loadl %address',' %keep0 =l xor %p,%index',' %keep1 =l xor %keep0,%loaded'];v='%keep1'
            for i in range(size):lines += [f' %sum{i} =l add {v},%a{i}'];v=f'%sum{i}'
            lines += [' ret '+v,'}'];ir += ['\n'.join(lines)];decl += [f'extern uint64_t {name}(void*,uint64_t,'+','.join(['uint64_t']*size)+');']
            args=','.join(f'seed+{i}' for i in range(size));checks += [f'{{uint64_t raw;memcpy(&raw,p+offset,8);uint64_t expected=(uintptr_t)p^(uint64_t)offset^raw;for(unsigned i=0;i<{size};i++)expected+=seed+i;if({name}(p,(uint64_t)offset,{args})!=expected)return 4;}}']
    ir += ['export function l $twice(l %half) {\n@s\n %address =l add %half,%half\n %v =l loadl %address\n ret %v\n}',
           'export function l $live_plain(l %p,l %index) {\n@s\n %address =l add %p,%index\n %v =l loadl %address\n %a =l xor %p,%index\n %b =l xor %a,%v\n ret %b\n}']
    decl += ['extern uint64_t twice(uint64_t),live_plain(void*,uint64_t);']
    checks += ['{uint64_t raw;memcpy(&raw,p+offset,8);if(live_plain(p,(uint64_t)offset)!=((uintptr_t)p^(uint64_t)offset^raw))return 5;uint64_t base=(uint64_t)(uintptr_t)p+UINT64_C(0x8000000000000000);uint64_t index=(uint64_t)(uintptr_t)(p+offset)-base;if(l_l_adjacent((void*)(uintptr_t)base,index)!=raw)return 6;if(!((uintptr_t)(p+offset)&1)&&twice((uintptr_t)(p+offset)/2)!=raw)return 7;}']
    for barrier in ['call','store','blit','phi']:
        name='barrier_'+barrier;lines=[f'export function l ${name}(l %p,l %index,l %scratch) {{','@s',' %address =l add %p,%index']
        if barrier=='call':lines += [' call $indexed_barrier()']
        if barrier=='store':lines += [' storeb 77,%scratch']
        if barrier=='blit':lines += [' blit %p,%scratch,8']
        lines += [' %v =l loadl %address']
        if barrier=='phi':lines += [' jmp @join','@join',' %kept =l phi @s %address',' %result =l xor %v,%kept']
        lines += [' ret '+('%result' if barrier=='phi' else '%v'),'}'];ir += ['\n'.join(lines)];decl += [f'extern uint64_t {name}(void*,uint64_t,void*);']
        expected='raw^(uintptr_t)(p+offset)' if barrier=='phi' else 'raw'
        checks += [f'{{uint64_t raw,scratch=0;memcpy(&raw,p+offset,8);if({name}(p,(uint64_t)offset,&scratch)!=({expected}))return 8;}}']
    ir+=['data $indexed_global = { l 81985529216486895, l 18364758544493064720 }','thread data $indexed_tls = { l 81985529216486895, l 18364758544493064720 }']
    for name,base in [('global_address','$indexed_global'),('tls_address','thread $indexed_tls')]:
        ir += [f'export function l ${name}(l %index) {{\n@s\n %address =l add {base},%index\n %value =l loadl %address\n ret %value\n}}'];decl += [f'extern uint64_t {name}(uint64_t);']
    c='''#define _GNU_SOURCE
#include <sys/mman.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
'''+ '\n'.join(decl)+'''
__attribute__((noinline)) void indexed_barrier(void){__asm__ volatile("" ::: "memory");}
int main(int argc,char**argv){(void)argv;unsigned char bytes[8192];unsigned char*p=bytes+4096;uint64_t seed=UINT64_C(0xcafed00d12345678);
int offsets[]={-2048,-255,-8,-1,0,1,7,8,255,2048};
if(argc==1){for(unsigned n=0;n<32;n++){for(unsigned j=0;j<sizeof bytes;j++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;bytes[j]=(unsigned char)seed;}
for(unsigned k=0;k<10;k++){int offset=offsets[k];
'''+ '\n'.join(checks)+'''
}}
if(global_address(0)!=UINT64_C(81985529216486895)||global_address(8)!=UINT64_C(18364758544493064720)||tls_address(0)!=UINT64_C(81985529216486895)||tls_address(8)!=UINT64_C(18364758544493064720))return 3;
}
long page=sysconf(_SC_PAGESIZE);unsigned char*map=mmap(0,page*3,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);
if(map==MAP_FAILED||mprotect(map+page,page,PROT_READ|PROT_WRITE))return 10;
uint64_t edges[]={0,UINT64_MAX,UINT64_C(0x8000000000000000),UINT64_C(0x7ff0000000000001),UINT64_C(0x7ff8000012345678),UINT64_C(0x80000000),UINT64_C(0x7f800001)};
for(unsigned trial=0;trial<64;trial++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;if(trial<7)seed=edges[trial];for(unsigned side=0;side<2;side++){
'''+'\n'.join(guard_checks)+'''
}}munmap(map,page*3);
puts("indexed checks passed");return 0;}
'''
    return 'dbgfile "indexed.c"\n'+'\n'.join(ir)+'\n',c,names,len(checks)*320+4+len(guard_checks)*128

def exercise(compiler,work,run,cc,target,execute=True,before=None,qbe=None):
    d=Path(work)/'arm-indexed-load';d.mkdir(parents=True,exist_ok=True);ir,c,names,count=fixture();src=d/'input.ssa';src.write_text(ir);caller=d/'caller.c';caller.write_text(c)
    def checked(cmd,inside=False):
        r=run(list(map(str,cmd)),inside);assert r.returncode==0,(cmd,r.returncode,r.stdout,r.stderr);return r
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'before_identity':checked([before,'--build-identity']).stdout.strip() if before else None,'before_sha256':sha(before) if before else None,'source_sha256':sha(src),'caller_sha256':sha(caller),'target':target,'case_groups_per_mode':count if execute else 0,'count_qualification':'Each group contains one or more independent C comparisons; totals include guarded-page cases.','modes':{},'negative_control':'not-run','original_qbe':'not-run'}
    indexed=r'\tldr(?:b|h|sb|sh|sw)? [wx]\d+, \[x\d+, x\d+\]'
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/(mode+'.s');checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text()
        def body(name):return re.search(r'(?:;|//) function '+name+r';[\s\S]*?(?=(?:;|//) function |\Z)',text).group()
        if mode=='allocated':
            for name,variant in names:
                assert bool(re.search(indexed,body(name)))==(variant in ['adjacent','commuted','debug']),(name,body(name))
            assert re.search(r'ldr x9, \[x9, x(?:19|2[0-8]|16|17|8)\]',body('pressure'))
            assert re.search(r'ldr x9, \[x(?:19|2[0-8]|16|17|8), x10\]',body('pressure_reverse'))
            for n in ['pressure_live','pressure_live_reverse']:assert '\tldr x9, [x9, x10]' in body(n)
            assert re.search(r'ldr x(\d+), \[x\1, x\1\]',body('twice'))
            assert re.search(r'ldr x(\d+), \[x\1, x\d+\]',body('l_l_adjacent'))
            assert re.search(r'ldr x(\d+), \[x\d+, x\1\]',body('l_l_commuted'))
            for n in ['barrier_call','barrier_store','barrier_blit','barrier_phi']:assert not re.search(indexed,body(n)),n
            for n,v in names:
                if v=='debug':assert re.search(r'\.loc \d+ 31 2\n'+indexed,body(n)),n
            for name in ['global_address','tls_address']:assert not re.search(indexed,body(name))
        assert re.search(r'\.loc \d+ 31 2',text)
        if before and mode=='baseline':
            old=d/'baseline-before.s';checked([before,src,'--target',target,'-o',old]);assert old.read_bytes()==asm.read_bytes()
        report['modes'][mode]={'assembly_sha256':sha(asm),'execution':'not-run','baseline_identical':bool(before) if mode=='baseline' else None}
        if execute:
            exe=d/mode;checked([cc,'-O2',caller,asm,'-o',exe],True);r=checked([exe],True);assert r.stdout=='indexed checks passed\n';report['modes'][mode]['execution']='passed';report['modes'][mode]['executable_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',exe],True).stdout.strip()
            if mode=='allocated':
                wrong=d/'wrong-index.s';original=body('l_l_adjacent');modified=re.sub(r'(\[x\d+, )x\d+(\])',r'\1xzr\2',original);assert modified!=original;wrong.write_text(text.replace(original,modified,1));bad=d/'wrong-index';checked([cc,'-O2',caller,wrong,'-o',bad],True);r=run([str(bad)],True);assert r.returncode==1;(report.update(negative_control={'status':'detected','exit':1}))
                overread=d/'overread.s';b=body('ub_w_adjacent');damaged=b.replace('\tldrb ','\tldr ',1);assert damaged!=b;overread.write_text(text.replace(b,damaged,1));bad=d/'overread';checked([cc,'-O2',caller,overread,'-o',bad],True);r=run([str(bad),'guard-only'],True);assert r.returncode!=0,'wide byte load escaped guard';report['guard_overread_control']={'status':'detected','exit':r.returncode}
    if execute and qbe:
        asm=d/'qbe.s';exe=d/'qbe';checked([qbe,'-t','arm64_apple' if target.endswith('macos') else 'arm64','-o',asm,src],True);checked([cc,'-O2',caller,asm,'-o',exe],True);checked([exe],True);report['original_qbe']='passed';report['original_qbe_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report


def main():
    import argparse,os,platform,shutil,tempfile
    from fuzz import LCB,ROOT
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler',type=Path,default=LCB)
    parser.add_argument('--before',type=Path)
    parser.add_argument('--require-native',action='store_true')
    args=parser.parse_args()
    execute=platform.machine() in ['arm64','aarch64'] and platform.system() in ['Darwin','Linux']
    if args.require_native:assert execute,'native ARM host required'
    target='aarch64-macos' if platform.system()=='Darwin' else 'aarch64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='arm-indexed-load-') as tmp:
        work=Path(tmp);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            result=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert result.returncode==0,result.stderr;qbe=oracle/'qbe'
        print(json.dumps(exercise(args.compiler.resolve(),work,run,cc,target,execute,args.before.resolve() if args.before else None,qbe),indent=2))

if __name__=='__main__':main()
