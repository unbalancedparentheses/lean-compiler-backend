#!/usr/bin/env python3
"""AMD64 variadic definitions may omit a syntactically unused environment."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
from fuzz import ROOT, LCB
from unused_environment import native_target

SIGNATURES = [(1,0),(6,0),(7,0),(1,8),(1,9),(6,8),(7,9)]
SEEDS = [0,1,7,255,65535,0xffffffff,0x80000000,1<<63,(1<<64)-1]
MASK=(1<<64)-1


def expected(gp,fp,seed):
    values=[(seed+i+1)&MASK for i in range(gp)]
    values += [struct.unpack('<Q',struct.pack('<d',i+1.5))[0] for i in range(fp)]
    for i in range(3):values += [(seed+101+i)&MASK,struct.unpack('<Q',struct.pack('<d',i+3.5))[0]]
    return (33+sum(v*(2*i+1) for i,v in enumerate(values)))&MASK


def inputs(signatures=SIGNATURES):
    ir=[];c=['#include <stdint.h>\n#include <stdarg.h>\n#include <string.h>\nstatic uint64_t bits(double x){uint64_t r;memcpy(&r,&x,8);return r;}\n'];checks=[]
    for n,(gp,fp) in enumerate(signatures):
        params=[f'l %a{i}' for i in range(gp)]+[f'd %f{i}' for i in range(fp)]
        cp=[f'uint64_t a{i}' for i in range(gp)]+[f'double f{i}' for i in range(fp)]
        last=f'f{fp-1}' if fp else f'a{gp-1}'
        ir.append(f'export function l $target_{n}(env %unused,'+','.join(params)+',...) {\n@s\n %ap =l alloc8 24\n vastart %ap\n')
        c.append(f'extern uint64_t target_{n}('+','.join(cp)+',...);\n')
        c.append(f'uint64_t c_target_{n}('+','.join(cp)+f',...) {{va_list ap;va_start(ap,{last});uint64_t h=33;\n')
        vals=[f'%a{i}' for i in range(gp)];cvals=[f'a{i}' for i in range(gp)]
        for i in range(fp):ir.append(f' %bits{i} =l cast %f{i}\n');vals.append(f'%bits{i}');cvals.append(f'bits(f{i})')
        for i in range(3):
            ir.append(f' %v{i} =l vaarg %ap\n %d{i} =d vaarg %ap\n %db{i} =l cast %d{i}\n')
            c.append(f'uint64_t v{i}=va_arg(ap,uint64_t);double d{i}=va_arg(ap,double);\n')
            vals += [f'%v{i}',f'%db{i}'];cvals += [f'v{i}',f'bits(d{i})']
        acc='33'
        for i,v in enumerate(vals):
            ir.append(f' %m{i} =l mul {v},{2*i+1}\n %h{i} =l add {acc},%m{i}\n');acc=f'%h{i}'
            c.append(f'h+=(uint64_t){cvals[i]}*UINT64_C({2*i+1});\n')
        ir.append(f' ret {acc}\n}}\n');c.append('va_end(ap);return h;}\n')
        for mode in ['direct','indirect','external','callback']:
            ir.append(f'export function l ${mode}_{n}('+('l %fn,' if mode=='callback' else '')+'l %seed) {\n@s\n')
            args=[]
            for i in range(gp):ir.append(f' %a{i} =l add %seed,{i+1}\n');args.append(f'l %a{i}')
            args += [f'd d_{i+1.5}' for i in range(fp)]+['...']
            for i in range(3):ir.append(f' %v{i} =l add %seed,{101+i}\n');args += [f'l %v{i}',f'd d_{i+3.5}']
            target=f'$target_{n}'
            if mode=='indirect':ir.append(f' %fn =l copy {target}\n');target='%fn'
            if mode=='external':target=f'$c_target_{n}'
            if mode=='callback':target='%fn'
            ir.append(f' %r =l call {target}('+','.join(args)+')\n ret %r\n}\n')
            c.append(f'extern uint64_t {mode}_{n}('+('uintptr_t,' if mode=='callback' else '')+'uint64_t);\n')
        args=[f'seed+UINT64_C({i+1})' for i in range(gp)]+[str(i+1.5) for i in range(fp)]
        for i in range(3):args += [f'seed+UINT64_C({101+i})',str(i+3.5)]
        checks.append(f'uint64_t want{n}=33;\n')
        vals=[f'seed+UINT64_C({i+1})' for i in range(gp)]+[f'bits({i+1.5})' for i in range(fp)]
        for i in range(3):vals += [f'seed+UINT64_C({101+i})',f'bits({i+3.5})']
        checks += [f'want{n}+=(uint64_t)({v})*UINT64_C({2*i+1});\n' for i,v in enumerate(vals)]
        checks.append(f'if(target_{n}('+','.join(args)+f')!=want{n})return 1;\n')
        checks += [f'if({mode}_{n}(seed)!=want{n})return 2;\n' for mode in ['direct','indirect','external']]
        checks.append(f'if(callback_{n}((uintptr_t)c_target_{n},seed)!=want{n})return 3;\n')
    c.append('static const uint64_t seeds[]={'+','.join(f'UINT64_C({v})' for v in SEEDS)+'};\nint main(void){for(unsigned i=0;i<sizeof(seeds)/sizeof(*seeds);i++){uint64_t seed=seeds[i];\n'+''.join(checks)+'}return 0;}\n')
    return ''.join(ir),''.join(c)


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None):
    assert target in ['x86_64-linux','x86_64-macos']
    case=Path(work)/'unused-environment-variadic';case.mkdir(parents=True,exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';ir,c=inputs();source.write_text(ir);caller.write_text(c)
    used=case/'used.ssa';used.write_text('export function l $bad(env %e,l %x,...) {\n@s\n ret %e\n}\n')
    for flags in [[],['--allocate'],['--optimize']]:
        r=run([compiler,'--target',target,*flags,used,'-o',case/'used.s']);assert r.returncode!=0 and 'used environment' in r.stderr,r.stderr
    for indirect in [False,True]:
        path=case/('explicit-indirect.ssa' if indirect else 'explicit-direct.ssa')
        text='function l $f(env %unused,l %x,...) {\n@s\n ret %x\n}\nexport function l $root() {\n@s\n'
        if indirect:text+=' %fn =l copy $f\n'
        text+=' %r =l call '+('%fn' if indirect else '$f')+'(env 123,l 1,...,l 2)\n ret %r\n}\n';path.write_text(text)
        for flags in [[],['--allocate'],['--optimize']]:
            r=run([compiler,'--target',target,*flags,path,'-o',case/'explicit.s']);assert r.returncode!=0 and 'variadic environment calls' in r.stderr,r.stderr
        if qbe:
            r=run([qbe,'-t',qtarget,'-o',case/'explicit-qbe.s',path],True);assert r.returncode!=0 and 'variadic env calls' in r.stderr,r.stderr
    for n,(gp,fp) in enumerate(SIGNATURES):
        for seed in SEEDS:
            for mode in ['direct','indirect']:
                r=run([compiler,'--eval',source,f'{mode}_{n}',seed]);assert r.returncode==0 and int(r.stdout)==expected(gp,fp,seed),(n,seed,mode,r.stdout,r.stderr)
    obj=case/'caller.o'
    if execute:
        r=run([cc,'-std=c11','-O2','-c',caller,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',None)]:
        if mode=='qbe' and not(qbe and execute):continue
        asm,exe=case/(mode+'.s'),case/mode
        r=run([qbe,'-t',qtarget,'-o',asm,source] if mode=='qbe' else [compiler,'--target',target,*flags,source,'-o',asm],mode=='qbe');assert r.returncode==0,(mode,r.stderr)
        modes[mode]='emitted'
        if execute:
            r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True)
            if mode == 'qbe':
                # Pinned QBE aliases its environment flag with bit zero of the
                # vastart overflow offset: env + stack varargs reads at +1 byte.
                assert r.returncode == 1, ('expected pinned QBE overflow discrepancy', r.returncode,r.stderr)
                profile_source,profile_c=case/'qbe-register-profile.ssa',case/'qbe-register-profile.c'
                profile_ir,profile_c_text=inputs([SIGNATURES[0]])
                profile_source.write_text(profile_ir);profile_c.write_text(profile_c_text)
                asm,exe=case/'qbe-register-profile.s',case/'qbe-register-profile'
                r=run([qbe,'-t',qtarget,'-o',asm,profile_source],True);assert r.returncode==0,r.stderr
                r=run([cc,profile_c,asm,'-o',exe],True);assert r.returncode==0,r.stderr
                r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr)
                modes[mode]='register-only signature passed (45 calls); unchanged full input fails known overflow-pointer discrepancy'
            else:
                assert r.returncode==0,(mode,r.returncode,r.stderr)
                modes[mode]='passed'
    if execute:
        mutant=case/'mutant.ssa';mutant.write_text(ir.replace(' ret %h6\n',' ret 0\n',1));assert mutant.read_text()!=ir
        asm,exe=case/'mutant.s',case/'mutant'
        r=run([compiler,'--target',target,mutant,'-o',asm]);assert r.returncode==0,r.stderr
        r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==1,'corrupt return escaped C oracle'
    report={'target':target,'compiler_identity':run([compiler,'--build-identity']).stdout.strip(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'caller_sha256':hashlib.sha256(caller.read_bytes()).hexdigest(),'signatures':SIGNATURES,'modes':modes,'interpreter_cases':126,'c_calls_per_mode':315,'explicit_environment_calls':'rejected in all LCB modes and original QBE','used_environment_definitions':'rejected in all LCB modes','corruption_detected':execute}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: unused-env variadic definitions, seven GP/FP boundary signatures, 126 interpreter and 315 C calls per mode; {modes}; explicit-env calls and used-env definitions remain rejected',flush=True)
    return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    target=native_target();execute=target in ['x86_64-linux','x86_64-macos']
    if args.require_native:assert execute,'AMD64 native target required'
    target=target if execute else 'x86_64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-unused-env-var-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,target,execute,qbe,'amd64_apple' if target.endswith('macos') else 'amd64_sysv')


if __name__=='__main__':main()
