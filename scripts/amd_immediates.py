#!/usr/bin/env python3
"""AMD64 immediate selection checked against independent unsigned C arithmetic."""
import json
from pathlib import Path

CONSTANTS=[-(1<<63),-(1<<32)-1,-(1<<32),-4096,-2049,-2048,-2047,-65,-64,-33,-32,-1,0,1,7,31,32,33,63,64,65,255,1023,2047,2048,2049,4095,4096,(1<<31)-1,1<<31,(1<<32)-1,1<<32,(1<<32)+1,(1<<63)-1,1<<63,(1<<64)-1]
CONSTANTS=sorted(set(CONSTANTS+[-(1<<64)+1,-(1<<31)-1,-(1<<31),-(1<<31)+1,(1<<31)+1,(1<<32)+(1<<31)]))
OPS=['add','sub','and','or','xor','shl','shr','sar','mul']
SEEDS=sorted(set([0,1,(1<<64)-1]+[v for bit in range(64) for v in [(1<<bit)-1,1<<bit,((1<<bit)+1)&((1<<64)-1)]]))


def fixture(qbe_profile=False):
    ir=[];c=['#include <stdint.h>\n']
    checks=[]
    for width in [32,64]:
        for op in OPS:
            for n in CONSTANTS:
                if qbe_profile and op in ['shl','shr','sar'] and not 0<=n<width:continue
                name=f'case_{len(checks)}';kind='w' if width==32 else 'l'
                ir.append(f'export function l ${name}(l %x) {{\n@s\n %v ={kind} {op} %x,{n}\n'+(' %r =l extuw %v\n ret %r\n}\n' if width==32 else ' ret %v\n}\n'))
                c.append(f'extern uint64_t {name}(uint64_t);\n')
                checks.append(f'if({name}(x)!=reference(x,UINT64_C({n&((1<<64)-1)}),{width},{OPS.index(op)}))return 1;\n')
    ir.append('export thread data $tls_slot = { l 19 }\n')
    c.append('extern _Thread_local uint64_t tls_slot;\n')
    for width in [32,64]:
        kind='w' if width==32 else 'l'
        tail=' %r =l extuw %v\n ret %r\n}\n' if width==32 else ' ret %v\n}\n'
        for op in OPS:
            name=f'variable_{width}_{op}'
            ir.append(f'export function l ${name}(l %x,l %y) {{\n@s\n %v ={kind} {op} %x,%y\n'+tail)
            c.append(f'extern uint64_t {name}(uint64_t,uint64_t);\n')
            checks.append(f'if({name}(x,x^UINT64_C(0xdeadbeef01234567))!=reference(x,x^UINT64_C(0xdeadbeef01234567),{width},{OPS.index(op)}))return 1;\n')
            name=f'left_constant_{width}_{op}'
            ir.append(f'export function l ${name}(l %x) {{\n@s\n %v ={kind} {op} 123,%x\n'+tail)
            c.append(f'extern uint64_t {name}(uint64_t);\n')
            checks.append(f'if({name}(x)!=reference(123,x,{width},{OPS.index(op)}))return 1;\n')
            if qbe_profile:continue
            name=f'tls_{width}_{op}'
            ir.append(f'export function l ${name}() {{\n@s\n %v ={kind} {op} thread $tls_slot,1\n'+tail)
            c.append(f'extern uint64_t {name}(void);\n')
            checks.append(f'if({name}()!=reference((uintptr_t)&tls_slot,1,{width},{OPS.index(op)}))return 1;\n')
    c.append('''static uint64_t reference(uint64_t x,uint64_t y,unsigned width,unsigned op){
 uint64_t mask=width==32?UINT64_C(0xffffffff):UINT64_MAX;
 uint64_t a=x&mask,b=y&mask,r=0;unsigned shift=(unsigned)(y&(width-1));
 switch(op){case 0:r=a+b;break;case 1:r=a-b;break;case 2:r=a&b;break;
 case 3:r=a|b;break;case 4:r=a^b;break;case 5:r=a<<shift;break;
 case 6:r=a>>shift;break;case 7:r=a>>shift;
 if(shift && (a&(UINT64_C(1)<<(width-1))))r|=mask^(mask>>shift);break;case 8:r=a*b;break;}
 return r&mask;}
''')
    c.append('static const uint64_t seeds[]={'+','.join(f'UINT64_C({v})' for v in SEEDS)+'};\nint main(void){for(unsigned i=0;i<sizeof(seeds)/sizeof(*seeds);i++){uint64_t x=seeds[i];\n'+''.join(checks)+'}return 0;}\n')
    return ''.join(ir),''.join(c)


def exercise(compiler,work,run,cc,target='x86_64-linux',execute=True,qbe=None,qtarget='amd64_sysv'):
    assert target in ('x86_64-linux','x86_64-macos')
    cc=[cc] if isinstance(cc,(str,Path)) else list(cc)
    case=Path(work)/'amd-immediates';case.mkdir(parents=True,exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';ir,c=fixture();source.write_text(ir);caller.write_text(c)
    obj=case/'caller.o'
    if execute:
        r=run([*cc,'-O2','-c',caller,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',None)]:
        if mode=='qbe' and not(execute and qbe):continue
        asm,exe=case/(mode+'.s'),case/mode
        mode_source,mode_obj=source,obj
        if mode=='qbe':
            # Pinned AMD QBE emits invalid immediates for oversized constant shifts.
            # Keep all boundary cases mandatory for LCB; compare only legal counts.
            mode_source,qcaller=case/'qbe-profile.ssa',case/'qbe-profile.c'
            qi,qc=fixture(True);mode_source.write_text(qi);qcaller.write_text(qc)
            mode_obj=case/'qbe-profile.o'
            r=run([*cc,'-O2','-c',qcaller,'-o',mode_obj],True);assert r.returncode==0,r.stderr
        r=run([qbe,'-t',qtarget,'-o',asm,mode_source] if mode=='qbe' else [compiler,'--target',target,*flags,source,'-o',asm],mode=='qbe');assert r.returncode==0,(mode,r.stderr)
        if mode=='baseline':
            import re
            bodies={int(m.group(1)):m.group(2) for m in re.finditer(r'^_?case_(\d+):\n(.*?)(?=^_?case_\d+:|\Z)',asm.read_text(),re.M|re.S)}
            index=0
            for width in [32,64]:
                for op in OPS:
                    for n in CONSTANTS:
                        body=bodies[index];index+=1
                        value=n% (1<<width);value=value-(1<<width) if value>=(1<<(width-1)) else value
                        suffix='l' if width==32 else 'q';reg='%eax' if width==32 else '%rax'
                        if op in ('shl','shr','sar'):
                            assert f'\t{op}{suffix} ${n%(width)}, {reg}\n' in body,(width,op,n)
                            assert '%cl,' not in body,(width,op,n)
                        elif width==32 or -(1<<31)<=value<(1<<31):
                            instruction=(f'\timul{suffix} ${value}, {reg}, {reg}\n' if op=='mul' else f'\t{op}{suffix} ${value}, {reg}\n')
                            assert instruction in body,(width,op,n,instruction)
                        else:
                            assert f'\tmovabsq ${n% (1<<64)}, %rcx\n' in body,(width,op,n)
        modes[mode]='emitted'
        if execute:
            r=run([*cc,mode_obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr);modes[mode]='passed'
    if execute:
        original=(case/'baseline.s').read_text();mutated=original.replace('\taddl $1, %eax\n','\taddl $2, %eax\n',1);assert mutated!=original
        asm,exe=case/'wrong-immediate.s',case/'wrong-immediate';asm.write_text(mutated)
        r=run([*cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==1,'wrong immediate escaped independent C oracle'
    import hashlib
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    qbe_sha=None
    if execute and qbe:
        hashed=run(['python3','-c','import hashlib,sys; print(hashlib.sha256(open(sys.argv[1], \"rb\").read()).hexdigest())',qbe],True)
        assert hashed.returncode==0,hashed.stderr
        qbe_sha=hashed.stdout.strip()
    report={'compiler_identity':run([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(source),'caller_sha256':sha(caller),'qbe_sha256':qbe_sha,'target':target,'functions':fixture()[0].count('export function'),'seeds':len(SEEDS),'checks_per_mode':fixture()[0].count('export function')*len(SEEDS) if execute else 0,'generated_checks_per_mode':fixture()[0].count('export function')*len(SEEDS),'modes':modes,'wrong_immediate_detected':execute,'qbe_profile':'all arithmetic/bitwise/multiply constants, variable and LHS-constant operands; only 0 <= constant shift < width; TLS supplement LCB-only (original QBE failures retained separately)','qbe_functions':fixture(True)[0].count('export function'),'qbe_checks':fixture(True)[0].count('export function')*len(SEEDS) if execute and qbe else 0}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    import argparse,os,shlex,subprocess
    from fuzz import LCB
    from data_relocations import native_host
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--target',choices=['x86_64-linux','x86_64-macos'],default='x86_64-macos');ap.add_argument('--work',type=Path,default=Path('.build/amd-immediates'));ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='');ap.add_argument('--qbe',type=Path);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    execute=args.target==native_host() or bool(args.runner)
    if args.require_native:assert execute
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside and len(cmd)==1:cmd=shlex.split(args.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=180)
    exercise(args.compiler.resolve(),args.work.resolve(),run,shlex.split(args.cc),args.target,execute,args.qbe.resolve() if args.qbe else None,'amd64_apple' if args.target.endswith('macos') else 'amd64_sysv')

if __name__=='__main__':main()
