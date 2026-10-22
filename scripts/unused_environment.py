#!/usr/bin/env python3
"""Omit only unused env arguments: C ABI, interpreter and unchanged-QBE checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB

TARGETS = {'aarch64-macos':'arm64_apple', 'x86_64-macos':'amd64_apple',
           'aarch64-linux':'arm64', 'x86_64-linux':'amd64_sysv', 'riscv64-linux':'rv64'}
COUNTS = (0, 1, 8, 9, 16)
SEEDS = (0, 1, 7, 17, 255, 65535, 0xffffffff, 0x80000000, 1 << 63, (1 << 64)-1)
MASK = (1 << 64)-1


def kinds(count): return ['w' if i % 3 == 0 else 'l' for i in range(count)]


def expected(count, seed):
    return (33 + sum(((seed+i+1) & (0xffffffff if k=='w' else MASK))*(2*i+1)
                     for i,k in enumerate(kinds(count)))) & MASK


def inputs():
    ir, c = [], ['#include <stdint.h>\n']
    checks=[]
    for count in COUNTS:
        ks=kinds(count)
        params=','.join(f'{k} %a{i}' for i,k in enumerate(ks))
        ir.append(f'export function l $target_{count}(env %unused'+(','+params if params else '')+') {\n@s\n')
        acc='33'
        for i,k in enumerate(ks):
            v=f'%a{i}'
            if k=='w':ir.append(f' %wide{i} =l extuw {v}\n');v=f'%wide{i}'
            ir.append(f' %m{i} =l mul {v}, {2*i+1}\n %s{i+1} =l add {acc}, %m{i}\n');acc=f'%s{i+1}'
        ir.append(f' ret {acc}\n}}\n')
        cp=','.join(f'uint{32 if k=="w" else 64}_t a{i}' for i,k in enumerate(ks)) or 'void'
        c.append(f'extern uint64_t target_{count}({cp});\nuint64_t c_target_{count}({cp}) {{ uint64_t r=33;\n')
        c.extend(f'r+=(uint64_t)a{i}*UINT64_C({2*i+1});\n' for i in range(count));c.append('return r;}\n')
        for mode in ['direct','indirect','explicit','indirect_explicit','external','callback']:
            args=[]
            ir.append(f'export function l ${mode}_{count}('+('l %fn,' if mode=='callback' else '')+'l %seed) {\n@s\n')
            for i,k in enumerate(ks):
                ir.append(f' %v{i} ={k} add %seed, {i+1}\n');args.append(f'{k} %v{i}')
            target=f'$target_{count}'
            if mode in ['indirect','indirect_explicit']:
                ir.append(f' %fn =l copy {target}\n');target='%fn'
            if mode=='external':target=f'$c_target_{count}'
            if mode=='callback':target='%fn'
            if mode in ['explicit','indirect_explicit']:args.insert(0,'env 123')
            ir.append(f' %r =l call {target}('+','.join(args)+')\n ret %r\n}\n')
            c.append(f'extern uint64_t {mode}_{count}('+('uintptr_t,' if mode=='callback' else '')+'uint64_t);\n')
        actual_args=','.join(f'(uint{32 if k=="w" else 64}_t)(seed+UINT64_C({i+1}))' for i,k in enumerate(ks))
        checks.append(f'uint64_t want_{count}=UINT64_C(33);\n')
        checks.extend(f'want_{count}+=(uint64_t)(uint{32 if k=="w" else 64}_t)(seed+UINT64_C({i+1}))*UINT64_C({2*i+1});\n' for i,k in enumerate(ks))
        checks.append(f'if(target_{count}({actual_args})!=want_{count})return 1;\n')
        for mode in ['direct','indirect','explicit','indirect_explicit','external']:
            checks.append(f'if({mode}_{count}(seed)!=want_{count})return 2;\n')
        checks.append(f'if(callback_{count}((uintptr_t)c_target_{count},seed)!=want_{count})return 3;\n')
    ir.append('''data $saved = { l 0 }
function $set(env %unused,l %v) {
@s
 storel %v,$saved
 ret
}
export function l $void_root(l %v) {
@s
 %fn =l copy $set
 call %fn(l %v)
 %r =l loadl $saved
 ret %r
}
function l $recursive(env %unused,l %n) {
@s
 %done =w ceql %n,0
 jnz %done,@base,@step
@base
 ret 0
@step
 %next =l sub %n,1
 %r =l call $recursive(l %next)
 %sum =l add %r,%n
 ret %sum
}
export function l $recursive_root(l %v) {
@s
 %n =l and %v,15
 %r =l call $recursive(l %n)
 ret %r
}
function l $used(env %e,l %v) {
@s
 %r =l xor %e,%v
 ret %r
}
export function l $explicit_used(l %v) {
@s
 %r =l call $used(env 123,l %v)
 ret %r
}
function l $plain(l %v) {
@s
 ret %v
}
export function l $extra_ignored(l %v) {
@s
 %r =l call $plain(env 99,l %v)
 ret %r
}
type :pair = { l 2 }
export function :pair $pair_target(env %unused,:pair %p,l %salt) {
@s
 %first =l loadl %p
 %p8 =l add %p,8
 %second =l loadl %p8
 %out =l alloc8 16
 %sum =l add %first,%salt
 %bits =l xor %second,%salt
 storel %sum,%out
 %out8 =l add %out,8
 storel %bits,%out8
 ret %out
}
export function l $pair_root(l %v) {
@s
 %p =l alloc8 16
 storel %v,%p
 %p8 =l add %p,8
 storel 91,%p8
 %fn =l copy $pair_target
 %r =:pair call %fn(:pair %p,l 17)
 %a =l loadl %r
 %r8 =l add %r,8
 %b =l loadl %r8
 %sum =l add %a,%b
 ret %sum
}
''')
    c.append('struct pair {uint64_t a,b;}; extern struct pair pair_target(struct pair,uint64_t);\n')
    c.append('extern uint64_t void_root(uint64_t),recursive_root(uint64_t),explicit_used(uint64_t),extra_ignored(uint64_t),pair_root(uint64_t);\n')
    c.append('static const uint64_t seeds[]={'+','.join(f'UINT64_C({n})' for n in SEEDS)+'};\nint main(void){for(unsigned i=0;i<sizeof(seeds)/sizeof(*seeds);i++){uint64_t seed=seeds[i];\n')
    c.extend(checks)
    c.append('if(void_root(seed)!=seed||explicit_used(seed)!=(seed^123)||extra_ignored(seed)!=seed)return 4;\n')
    c.append('uint64_t n=seed&15;if(recursive_root(seed)!=n*(n+1)/2)return 5;\n')
    c.append('struct pair p={seed,91},r=pair_target(p,17);if(r.a!=seed+17||r.b!=(91^17)||pair_root(seed)!=seed+17+(91^17))return 6;\n')
    c.append('}return 0;}\n')
    return ''.join(ir),''.join(c)


def controls(compiler,case,run):
    def rejected(name,text,needle,entry=None):
        path=case/(name+'.ssa');path.write_text(text)
        cmd=[compiler,'--eval',path,entry] if entry else [compiler,'--check',path]
        r=run(cmd);assert r.returncode!=0 and needle in r.stderr,(name,r.returncode,r.stderr)
    # Every operand position is conservative, including untaken constant branches and phi edges.
    bodies=[
        '@s\n ret %e',
        '@s\n %r =l add %e,1\n ret %r',
        '@s\n jnz %e,@a,@b\n@a\n ret 1\n@b\n ret 2',
        '@s\n jmp @p\n@p\n %r =l phi @s %e\n ret %r',
        '@s\n storel %e,$sink\n ret 0',
        '@s\n %r =l call %e()\n ret %r',
        '@s\n call $external(l %e)\n ret 0',
        '@s\n jnz 0,@dead,@end\n@dead\n ret %e\n@end\n ret 0',
    ]
    for i,body in enumerate(bodies):
        text='data $sink = { l 0 }\nfunction l $f(env %e) {\n'+body+'\n}\nexport function l $root() {\n@s\n %r =l call $f()\n ret %r\n}\n'
        rejected('used-'+str(i),text,'missing environment argument')
    used='function l $f(env %e) {\n@s\n ret %e\n}\nexport function l $root() {\n@s\n %fn =l copy $f\n %r =l call %fn()\n ret %r\n}\n'
    # Native unresolved indirect signatures remain an ABI assumption; resolution in
    # the interpreter must reject a missing used environment, never supply zero.
    path=case/'indirect-used.ssa';path.write_text(used);r=run([compiler,'--check',path]);assert r.returncode==0,r.stderr
    rejected('indirect-used',used,'missing environment argument','root')
    base='function l $f(env %unused,l %x) {\n@s\n ret %x\n}\n'
    for name,args in [('missing',''),('width','w 1'),('extra','l 1,l 2')]:
        rejected('signature-'+name,base+'function l $root() {\n@s\n %r =l call $f('+args+')\n ret %r\n}\n','call $f:')
    rejected('external','export function l $root() {\n@s\n %r =l call $unknown(l 1)\n ret %r\n}\n','no interpreter model','root')
    rejected('unknown-pointer','export function l $root() {\n@s\n %fn =l copy 0\n %r =l call %fn()\n ret %r\n}\n','no interpreter model','root')
    # Variadic signature matching can omit an unused env without inventing a
    # binding. Native AMD64 variadic+env remains separately unsupported.
    var=case/'variadic.ssa';var.write_text('function l $f(env %unused,l %x,...) {\n@s\n ret %x\n}\nfunction l $root() {\n@s\n %r =l call $f(l 42,...,l 99)\n ret %r\n}\n')
    r=run([compiler,'--eval',var,'root']);assert r.returncode==0 and r.stdout.strip()=='42',r.stderr
    return len(bodies)+6


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None):
    case=Path(work)/'unused-environment';case.mkdir(parents=True,exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';ir,c=inputs();source.write_text(ir);caller.write_text(c)
    controls_count=controls(compiler,case,run)
    for count in COUNTS:
        for seed in SEEDS:
            for mode in ['direct','indirect','explicit','indirect_explicit']:
                r=run([compiler,'--eval',source,f'{mode}_{count}',seed]);assert r.returncode==0 and int(r.stdout)==expected(count,seed),(count,seed,mode,r.stderr,r.stdout)
    for seed in SEEDS:
        for name,want in [('void_root',seed),('explicit_used',seed^123),('extra_ignored',seed),('recursive_root',(seed&15)*((seed&15)+1)//2),('pair_root',(seed+17+(91^17))&MASK)]:
            r=run([compiler,'--eval',source,name,seed]);assert r.returncode==0 and int(r.stdout)==want,(name,seed,r.stderr,r.stdout)
    obj=case/'caller.o'
    if execute:
        r=run([cc,'-std=c11','-O2','-c',caller,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',None)]:
        if mode=='qbe' and not (qbe and execute):continue
        asm,exe=case/(mode+'.s'),case/mode
        cmd=[qbe,'-t',qtarget or TARGETS[target],'-o',asm,source] if mode=='qbe' else [compiler,'--target',target,*flags,source,'-o',asm]
        r=run(cmd,mode=='qbe');assert r.returncode==0,(mode,r.stderr)
        modes[mode]='emitted'
        if execute:
            r=run([cc,obj,asm,'-o',exe]+(['-no-pie'] if mode=='qbe' and target=='riscv64-linux' else []),True);assert r.returncode==0,(mode,r.stderr)
            r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr)
            modes[mode]='passed'
    if execute:
        damaged=case/'damaged.ssa';damaged.write_text(ir.replace(' ret %s16\n',' ret 0\n',1));assert damaged.read_text()!=ir
        asm,exe=case/'damaged.s',case/'damaged'
        r=run([compiler,'--target',target,damaged,'-o',asm]);assert r.returncode==0,r.stderr
        r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==1,'wrong callee return escaped independent C'
    report={'target':target,'compiler_identity':run([compiler,'--build-identity']).stdout.strip(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'caller_sha256':hashlib.sha256(caller.read_bytes()).hexdigest(),'modes':modes,'interpreter_cases':250,'negative_cases':controls_count,'native_checks_per_mode':410,'execution':execute,'corruption_detected':execute,'qbe_link_flags':['-no-pie'] if target=='riscv64-linux' else []}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: unused environment omission, scalar/stack/aggregate/void/recursive calls; 250 interpreter and 410 C checks per mode; {modes}; used-env/signature/external controls passed',flush=True)
    return report


def native_target():
    isa={'arm64':'aarch64','aarch64':'aarch64','amd64':'x86_64','x86_64':'x86_64','riscv64':'riscv64'}.get(platform.machine().lower())
    os_name={'Darwin':'macos','Linux':'linux'}.get(platform.system());target=f'{isa}-{os_name}'
    return target if target in TARGETS else None


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    target=native_target()
    if args.require_native:assert target,'native target unavailable'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-unused-env-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=None
        if target:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,target or 'aarch64-macos',bool(target),qbe)


if __name__=='__main__':main()
