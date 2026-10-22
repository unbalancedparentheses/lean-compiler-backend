#!/usr/bin/env python3
"""Independent C checks of large dynamic outgoing areas, HFA tails, env and TLS."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import subprocess
import tempfile
from fuzz import LCB

TARGETS={'aarch64-macos':'arm64_apple','x86_64-macos':'amd64_apple',
         'aarch64-linux':'arm64','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}
HFA_COUNT=515


def native_host():
    machine={'arm64':'aarch64','AMD64':'x86_64'}.get(platform.machine(),platform.machine())
    target=machine+'-'+{'Darwin':'macos','Linux':'linux'}.get(platform.system(),'unknown')
    return target if target in TARGETS else None


def fixture(tls=True):
    kinds=['l']*8+[':hfa']*HFA_COUNT+['l','sb','ub','sh','uh','w']
    names=[f'g{i}' for i in range(8)]+[f'h{i}' for i in range(HFA_COUNT)]+['pointer','sb','ub','sh','uh','word']
    ctypes={'l':'uint64_t',':hfa':'struct hfa','sb':'int8_t','ub':'uint8_t','sh':'int16_t','uh':'uint16_t','w':'uint32_t'}
    params=','.join(f'{k} %{n}' for k,n in zip(kinds,names))
    forwarded=','.join(f'{k} %{n}' for k,n in zip(kinds,names))
    cparams=','.join(f'{ctypes[k]} {n}' for k,n in zip(kinds,names))
    storage='thread ' if tls else ''
    source=[f'type :hfa = {{ d 4 }}\nexport {storage}data $outgoing_value = align 8 {{ l 7 }}',
            f'''export function l $outgoing_env(env %environment,{params}) {{
@start
 %result =l call $outgoing_target({forwarded})
 %combined =l xor %result,%environment
 ret %combined
}}''']
    for label,indirect,environment in [('direct',False,False),('indirect',True,False),('env',False,True),('env_indirect',True,True)]:
        wrapper_params=('l %fn,' if indirect else '')+'l %n,l %seed'
        lines=[f'export function l $outgoing_{label}({wrapper_params}) {{','@start',
               ' %object =l alloc8 32',' stored d_1.25,%object']
        for i,value in [(1,'2.5'),(2,'-3.75'),(3,'4.0')]:
            lines += [f' %field{i} =l add %object,{8*i}',f' stored d_{value},%field{i}']
        lines += [' %dynamic =l alloc16 %n',' %end =l add %dynamic,%n',' %last =l sub %end,8',
                  ' storel 123456789,%dynamic',' storel 987654321,%last',' %narrow =w copy %seed']
        for i in range(1,8):lines += [f' %g{i} =l add %seed,{i}']
        args=['l %seed']+[f'l %g{i}' for i in range(1,8)]+[':hfa %object']*HFA_COUNT
        args += ['l '+('thread ' if tls else '')+'$outgoing_value']+[f'{k} %narrow' for k in ['sb','ub','sh','uh','w']]
        if environment:args.insert(0,'env %seed')
        target='%fn' if indirect else ('$outgoing_env' if environment else '$outgoing_target')
        lines += [f' %result =l call {target}('+','.join(args)+')',
                  ' %first =l loadl %dynamic',' %final =l loadl %last',
                  ' %a =l xor %result,%first',' %b =l xor %a,%final',' ret %b','}']
        source.append('\n'.join(lines))
    checks=[f'if(g{i}!=g0+UINT64_C({i}))error=1;' for i in range(1,8)]
    checks += [f'if(h{i}.a!=1.25||h{i}.b!=2.5||h{i}.c!=-3.75||h{i}.d!=4.0)error=2;' for i in range(HFA_COUNT)]
    checks += ['if(pointer!=(uintptr_t)&outgoing_value||*(uint64_t *)(uintptr_t)pointer!=outgoing_value)error=3;',
               'if(sb!=(int8_t)g0||ub!=(uint8_t)g0||sh!=(int16_t)g0||uh!=(uint16_t)g0||word!=(uint32_t)g0)error=4;']
    caller='''#include <stdint.h>
struct hfa {double a,b,c,d;};
'''+('extern _Thread_local uint64_t outgoing_value;\n' if tls else 'extern uint64_t outgoing_value;\n')+'''
static int error;
extern uint64_t outgoing_direct(uint64_t,uint64_t),outgoing_env(uint64_t);
extern uint64_t outgoing_indirect(uintptr_t,uint64_t,uint64_t),outgoing_env_indirect(uintptr_t,uint64_t,uint64_t);
extern uint64_t outgoing_env_wrapper(uint64_t,uint64_t);
'''+f'uint64_t outgoing_target({cparams}) {{\n'+'\n'.join(checks)+'''
 return g0 ^ outgoing_value ^ UINT64_C(0x123456789abcdef);
}
int main(void){
 const uint64_t seeds[]={0,1,127,128,255,32767,32768,65535,UINT64_C(0x100000080),UINT64_MAX};
 const uint64_t sizes[]={16,8192};
 for(unsigned i=0;i<10;i++)for(unsigned j=0;j<2;j++){
  uint64_t seed=seeds[i],n=sizes[j];outgoing_value=seed^UINT64_C(0xf123456789abcdef);
  uint64_t wanted=seed^outgoing_value^UINT64_C(0x123456789abcdef)^UINT64_C(123456789)^UINT64_C(987654321);
  error=0;if(outgoing_direct(n,seed)!=wanted||error)return 1;
  error=0;if(outgoing_indirect((uintptr_t)outgoing_target,n,seed)!=wanted||error)return 2;
  error=0;if(outgoing_env_wrapper(n,seed)!=(wanted^seed)||error)return 3;
  error=0;if(outgoing_env_indirect((uintptr_t)outgoing_env,n,seed)!=(wanted^seed)||error)return 4;
 }return 0;
}
'''
    # Keep the environment callee and the normal-ABI wrapper names distinct.
    ir='\n'.join(source)+'\n'
    ir=ir.replace('export function l $outgoing_env(l %n,l %seed)',
                  'export function l $outgoing_env_wrapper(l %n,l %seed)')
    return ir,caller,len(kinds),80



def direct_body(text,target):
    prefix='_' if target.endswith('macos') else ''
    start=text.index('\n'+prefix+'outgoing_direct:\n')
    end=text.index('\n'+prefix+'outgoing_indirect:\n',start)
    return text[start:end]


def corrupt_dynamic_offset(text,target):
    body=direct_body(text,target)
    damaged=body.replace('\tstrb w9, [x15]','\tstrb w9, [x15, #1]',1)
    assert damaged!=body
    return text.replace(body,damaged,1)


def check_arm_offsets(text,target):
    # Eight GPs and eight FP registers are already occupied. 513 stack HFAs
    # occupy 16416 bytes, then the TLS pointer occupies eight more bytes.
    body=direct_body(text,target)
    assert 'x29' in body, 'runtime allocation must retain stable frame base'
    offsets=[16424,16425,16426,16428,16432] if target.endswith('macos') else [16424,16432,16440,16448,16456]
    for instruction,offset in zip(['strb','strb','strh','strh','str'],offsets):
        sequence=f'\tadd x15, sp, #4, lsl #12\n\tadd x15, x15, #{offset-16384}\n\t{instruction} w9, [x15]'
        assert sequence in body,(target,instruction,offset)
    assert 'blr x16' in text
    return offsets


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,tls=True):
    case=Path(work)/('dynamic-outgoing-tls' if tls else 'dynamic-outgoing-global');case.mkdir(parents=True,exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';ir,c,arguments,count=fixture(tls);source.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        r=run(cmd,inside);assert r.returncode==0,(cmd,r.returncode,r.stdout,r.stderr);return r
    report={'target':target,'execution':execute,'tls':tls,'hfa_arguments':HFA_COUNT,'arguments':arguments,
            'calls_per_mode':count,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),
            'compiler_sha256':hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'caller_sha256':hashlib.sha256(caller.read_bytes()).hexdigest(),'modes':{},'original_qbe':None}
    obj=case/'caller.o'
    if execute:checked([cc,'-std=c11','-O1','-c',caller,'-o',obj],True)
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label;checked([compiler,source,'--target',target,*flags,'-o',asm])
        if target.startswith('aarch64'):
            report['arm_tail_offsets']=check_arm_offsets(asm.read_text(),target)
        report['modes'][label]='emitted'
        if execute:
            checked([cc,obj,asm,'-o',exe],True);checked([exe],True);report['modes'][label]='passed'
            if target.startswith('aarch64') and label=='optimized':
                damaged=corrupt_dynamic_offset(asm.read_text(),target)
                bad,badexe=case/'wrong-offset.s',case/'wrong-offset';bad.write_text(damaged)
                checked([cc,obj,bad,'-o',badexe],True);r=run([badexe],True);assert r.returncode==1,('offset corruption escaped C oracle',r.returncode,r.stderr)
                report['negative_control']={'mutation':'dynamic direct-call byte store shifted by1','exit':r.returncode,'status':'detected'}
    if qbe:
        asm,exe=case/'original-qbe.s',case/'original-qbe';cmd=[qbe,'-t',TARGETS[target],'-o',asm,source];r=run(cmd)
        oracle={'command':list(map(str,cmd)),'emit_exit':r.returncode,'emit_stdout':r.stdout,'emit_stderr':r.stderr,'status':'emission-failed' if r.returncode else 'emitted'}
        if Path(qbe).is_file():oracle['binary_sha256']=hashlib.sha256(Path(qbe).read_bytes()).hexdigest()
        if r.returncode==0 and execute:
            r=run([cc,obj,asm,'-o',exe],True);oracle.update(link_exit=r.returncode,link_stderr=r.stderr,status='link-failed' if r.returncode else 'linked')
            if r.returncode==0:
                r=run([exe],True);oracle.update(run_exit=r.returncode,run_stdout=r.stdout,run_stderr=r.stderr,status='passed' if r.returncode==0 else 'execution-failed')
        report['original_qbe']=oracle
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: dynamic outgoing {arguments} args ({HFA_COUNT} HFAs), {count} calls/mode; TLS={tls}; {report["modes"]}; originalQBE={report["original_qbe"] and report["original_qbe"]["status"]}',flush=True)
    return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--work',type=Path);ap.add_argument('--qbe',type=Path)
    ap.add_argument('--target',choices=TARGETS,default=native_host() or 'aarch64-macos');ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='');ap.add_argument('--no-tls',action='store_true');ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    execute=args.target==native_host() or bool(args.runner)
    if args.require_native:assert execute,'target execution unavailable'
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(args.cc)+cmd[1:] if cmd[0]==args.cc else shlex.split(args.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
    def run_case(work):return exercise(args.compiler.resolve(),work,run,args.cc,args.target,execute,args.qbe.resolve() if args.qbe else None,not args.no_tls)
    if args.work:run_case(args.work.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-dynamic-outgoing-') as work:run_case(Path(work))


if __name__=='__main__':main()
