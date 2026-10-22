#!/usr/bin/env python3
"""Independent C oracle for sparse generated-prefix collisions in stack promotion."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import subprocess
import tempfile
from fuzz import LCB

TARGETS={'aarch64-macos':'arm64_apple','x86_64-macos':'amd64_apple',
         'aarch64-linux':'arm64','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}


def native_host():
    machine={'arm64':'aarch64','AMD64':'x86_64'}.get(platform.machine(),platform.machine())
    system={'Darwin':'macos','Linux':'linux'}.get(platform.system())
    target=f'{machine}-{system}'
    return target if target in TARGETS else None


def fixture():
    functions,declarations,checks,cases=[],[],[],[]
    for variant in ['local','parameter','second_object']:
        for filler in [0,7]:
            for extra in [0,1,4096]:
                name=f'sparse_{variant}_{filler}_{extra}'
                parameter='%reserved' if variant=='parameter' else '%y'
                lines=[f'export function l ${name}(l %x,l {parameter}) {{','@start']
                lines += [f' %filler{i} =l add %x,{i}' for i in range(filler)]
                if variant=='second_object':
                    lines += [' %p0 =l alloc8 8',' %p1 =l alloc8 8',
                              ' %reserved =l add %y,100',' storel 3,%p0',' storel %x,%p1',
                              ' %v0 =l loadl %p0',' %v1 =l loadl %p1',
                              ' %sum =l add %v0,%v1',' %r =l add %sum,%reserved']
                    expected='x+y+UINT64_C(103)';index=1
                else:
                    lines += [' %p =l alloc8 8']
                    if variant=='local':lines += [' %reserved =l add %y,100']
                    lines += [' storel %x,%p',' %v =l loadl %p',' %r =l add %v,%reserved']
                    expected='x+y'+('+UINT64_C(100)' if variant=='local' else '');index=0
                lines += [' ret %r','}'];text='\n'.join(lines)
                locals_count=2+len(re.findall(r'^\s*%\S+\s*=',text,re.M))
                depth=locals_count+1+extra
                reserved='lcb.mem.'+'_'*depth+str(index)
                text=text.replace('%reserved','%'+reserved)
                functions.append(text);declarations.append(f'extern uint64_t {name}(uint64_t,uint64_t);')
                checks.append(f'if({name}(x,y)!=({expected}))return 1;')
                cases.append({'name':name,'kind':variant,'locals':locals_count,'underscore_depth':depth,
                              'generated_index':index,'exact_old_collision':extra==0})
    # SSA construction renames every name, unlike promotion's intermediate mutable variable.
    for extra in [0,4096]:
        name=f'sparse_mutable_{extra}'
        text=f'''export function l ${name}(l %x,l %reserved,w %n) {{
@start
 %i =w copy 0
 jmp @test
@test
 %more =w cultw %i,%n
 jnz %more,@body,@done
@body
 %x =l add %x,7
 %i =w add %i,1
 jmp @test
@done
 %result =l xor %x,%reserved
 ret %result
}}'''
        locals_count=3+len(re.findall(r'^\s*%\S+\s*=',text,re.M));depth=locals_count+1+extra
        functions.append(text.replace('%reserved','%lcb.ssa.'+'_'*depth+'0'))
        declarations.append(f'extern uint64_t {name}(uint64_t,uint64_t,uint32_t);')
        checks.append(f'for(unsigned n=0;n<8;n++)if({name}(x,y,n)!=((x+UINT64_C(7)*n)^y))return 2;')
        cases.append({'name':name,'kind':'mutable','locals':locals_count,'underscore_depth':depth})
    for variant in ['parameter','local']:
        for extra in [0,1,4096]:
            name=f'sparse_symbol_{variant}_{extra}'
            parameter='%reserved' if variant=='parameter' else '%x'
            lines=[f'export function l ${name}(l {parameter}) {{','@start']
            if variant=='local':lines += [' %reserved =l add %x,100']
            lines += [' %a =l loadl $prefix_collision_data',
                      ' %b =l loadl $prefix_collision_data',
                      ' %c =l loadl $prefix_collision_data',
                      ' %ab =l add %a,%b',' %sum =l add %ab,%c',
                      ' %result =l add %sum,%reserved',' ret %result','}']
            text='\n'.join(lines)
            locals_count=1+len(re.findall(r'^\s*%\S+\s*=',text,re.M))
            depth=locals_count+1+extra
            functions.append(text.replace('%reserved','%lcb.symbol.'+'_'*depth+'0'))
            declarations.append(f'extern uint64_t {name}(uint64_t);')
            checks.append(f'if({name}(x)!=x+UINT64_C({151 if variant=="local" else 51}))return 3;')
            cases.append({'name':name,'kind':'symbol_'+variant,'locals':locals_count,
                          'underscore_depth':depth,'module_symbol_references':3,
                          'exact_old_collision':extra==0})
    caller='''#include <stdint.h>
'''+ '\n'.join(declarations)+'''
int main(void){
 const uint64_t edges[]={0,1,3,7,UINT64_C(0x7fffffff),UINT64_C(0x8000000000000000),UINT64_MAX,UINT64_C(0x123456789abcdef)};
 for(unsigned i=0;i<8;i++)for(unsigned j=0;j<8;j++){
  uint64_t x=edges[i],y=edges[j];
'''+ '\n'.join(checks)+'''
 }return 0;
}
'''
    return 'data $prefix_collision_data = align 8 { l 17 }\n'+'\n'.join(functions)+'\n',caller,cases,(18+2*8+6)*64


def exercise(compiler,work,run,cc,target,execute=True,qbe=None):
    case=Path(work)/'prefix-collisions';case.mkdir(parents=True,exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';ir,c,cases,count=fixture()
    source.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        result=run(cmd,inside);assert result.returncode==0,(cmd,result.returncode,result.stdout,result.stderr);return result
    report={'target':target,'execution':execute,'cases_per_mode':count,'cases':cases,
            'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),
            'compiler_sha256':hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'caller_sha256':hashlib.sha256(caller.read_bytes()).hexdigest(),'modes':{}}
    caller_object=case/'caller.o'
    if execute:checked([cc,'-std=c11','-O2','-c',caller,'-o',caller_object],True)
    modes=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]
    if qbe:modes.append(('original-qbe',[]))
    for label,flags in modes:
        asm,exe=case/(label+'.s'),case/label
        checked([qbe,'-t',TARGETS[target],'-o',asm,source] if label=='original-qbe' else
                [compiler,source,'--target',target,*flags,'-o',asm])
        report['modes'][label]='emitted'
        if execute:
            checked([cc,caller_object,asm,'-o',exe],True);checked([exe],True)
            report['modes'][label]='passed'
    if qbe and Path(qbe).is_file():report['original_qbe_sha256']=hashlib.sha256(Path(qbe).read_bytes()).hexdigest()
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: {count} independent sparse-prefix cases per mode; {report["modes"]}',flush=True)
    return report


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--work',type=Path);ap.add_argument('--qbe',type=Path)
    ap.add_argument('--target',choices=TARGETS,default=native_host() or 'aarch64-macos')
    ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='');ap.add_argument('--require-native',action='store_true')
    args=ap.parse_args();execute=args.target==native_host() or bool(args.runner)
    if args.require_native:assert execute,'target execution unavailable; supply --runner'
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(args.cc)+cmd[1:] if cmd[0]==args.cc else shlex.split(args.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=120)
    def run_case(work):return exercise(args.compiler.resolve(),work,run,args.cc,args.target,execute,args.qbe.resolve() if args.qbe else None)
    if args.work:run_case(args.work.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-prefix-collisions-') as directory:run_case(Path(directory))


if __name__=='__main__':main()
