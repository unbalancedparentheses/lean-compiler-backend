#!/usr/bin/env python3
"""Bounded 1024-argument ABI profile, with independent C checks in both directions."""
import argparse
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB

TARGETS = {'aarch64-macos':'arm64_apple', 'x86_64-macos':'amd64_apple',
           'aarch64-linux':'arm64', 'x86_64-linux':'amd64_sysv', 'riscv64-linux':'rv64'}
COUNTS = (64, 65, 128, 1024)
PROFILES = [(n, False, False) for n in COUNTS] + [(65, True, False), (1024, True, False), (1024, False, True)]
CT = {'w':'uint32_t', 'l':'uint64_t', 's':'float', 'd':'double',
      'ub':'uint8_t', 'sb':'int8_t', 'uh':'uint16_t', 'sh':'int16_t',
      ':pair':'struct pair', ':big':'struct big'}


def inputs(count, edges=False, aggregates=False):
    pattern = ['w','l','s','d'] if not edges else ['l','d',':pair','ub','sb','uh','sh',':big']
    if aggregates: pattern = [':pair', ':big']
    kinds = [pattern[i % len(pattern)] for i in range(count)]
    params = ','.join(f'{k} %a{i}' for i,k in enumerate(kinds))
    cparams = ','.join(f'{CT[k]} a{i}' for i,k in enumerate(kinds))
    ir = ['type :pair = { l 2 }\ntype :big = { l 3 }\n',
          f'export function l $target({params}) {{\n@s\n']
    c = ['#include <stdint.h>\n#include <stdio.h>\nstruct pair {uint64_t a,b;}; struct big {uint64_t a,b,c;};\n',
         f'extern uint64_t target({cparams});\nuint64_t c_target({cparams}) {{ uint64_t h=0;\n']
    acc='0'
    for i,k in enumerate(kinds):
        v=f'%a{i}'
        if k in ['s','d']:
            ir.append(f' %v{i} =l {"stosi" if k=="s" else "dtosi"} {v}\n');v=f'%v{i}'
        elif k=='w' or k in ['ub','sb','uh','sh']:
            op={'w':'extuw','ub':'extub','sb':'extsb','uh':'extuh','sh':'extsh'}[k]
            ir.append(f' %v{i} =l {op} {v}\n');v=f'%v{i}'
        elif k.startswith(':'):
            fields=2 if k==':pair' else 3
            for j in range(fields):
                ir.append(f' %p{i}_{j} =l add %a{i}, {j*8}\n %v{i}_{j} =l loadl %p{i}_{j}\n')
            ir.append(f' %v{i} =l add %v{i}_0, %v{i}_1\n');v=f'%v{i}'
            if fields==3:ir.append(f' %vv{i} =l add {v}, %v{i}_2\n');v=f'%vv{i}'
        ir.append(f' %m{i} =l mul {v}, {2*i+1}\n %h{i} =l add {acc}, %m{i}\n');acc=f'%h{i}'
        cv=f'a{i}' if not k.startswith(':') else f'(a{i}.a+a{i}.b'+(f'+a{i}.c' if k==':big' else '')+')'
        c.append(f'h += (uint64_t)({cv}) * UINT64_C({2*i+1});\n')
    ir.append(f' ret {acc}\n}}\n');c.append('return h;}\n')
    for mode in ['direct','indirect','external','callback']:
        ir.append(f'export function l ${mode}('+('l %fn, ' if mode=='callback' else '')+'l %seed) {\n@s\n')
        args=[]
        for i,k in enumerate(kinds):
            v=f'%v{i}'
            w='w' if k in ['w','s','d','ub','sb','uh','sh'] else 'l'
            ir.append(f' {v} ={w} add %seed, {i+1}\n')
            if k in ['s','d']:
                ir.append(f' %f{i} ={k} swtof {v}\n');v=f'%f{i}'
            elif k.startswith(':'):
                fields=2 if k==':pair' else 3
                ir.append(f' %obj{i} =l alloc8 {fields*8}\n')
                for j in range(fields):
                    ir.append(f' %p{i}_{j} =l add %obj{i}, {j*8}\n %v{i}_{j} =l add {v}, {j}\n storel %v{i}_{j}, %p{i}_{j}\n')
                v=f'%obj{i}'
            args.append(f'{k} {v}')
        target='$target'
        if mode=='indirect': ir.append(' %fn =l copy $target\n');target='%fn'
        if mode=='external':target='$c_target'
        if mode=='callback':target='%fn'
        ir.append(f' %r =l call {target}('+','.join(args)+')\n ret %r\n}\n')
    c.append('extern uint64_t direct(uint64_t),indirect(uint64_t),external(uint64_t),callback(uintptr_t,uint64_t);\n')
    c.append('int main(void) { for(unsigned seed=0;seed<=255;seed+=17) { uint64_t expected=0;\n')
    args=[]
    for i,k in enumerate(kinds):
        expr=f'(seed+{i+1})'
        if k.startswith(':'):
            fields=2 if k==':pair' else 3
            vals=','.join(f'{expr}+{j}' for j in range(fields))
            c.append(f'{CT[k]} v{i}={{{vals}}};\n')
            term=f'(v{i}.a+v{i}.b'+(f'+v{i}.c' if fields==3 else '')+')'
        else:
            c.append(f'{CT[k]} v{i}=({CT[k]}){expr};\n');term=f'v{i}'
        c.append(f'expected+=(uint64_t){term}*UINT64_C({2*i+1});\n');args.append(f'v{i}')
    c.append('if(target('+','.join(args)+')!=expected)return 1;\n')
    c.append('if(direct(seed)!=expected)return 2; if(indirect(seed)!=expected)return 3; if(external(seed)!=expected)return 4; if(callback((uintptr_t)c_target,seed)!=expected)return 5;\n')
    c.append('} return 0;}\n')
    return ''.join(ir),''.join(c)


def original_qbe_profiles(target):
    """Qualify independent C profiles separately from known upstream failures."""
    if target in ['riscv64-linux', 'x86_64-macos']:
        profiles = [(n, False, False) for n in COUNTS]
        if target == 'x86_64-macos': profiles.append((1024, False, True))
        return profiles
    return list(PROFILES)


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None,qbe_profiles=None):
    root=Path(work)/'argument-limits';root.mkdir(exist_ok=True)
    # Parse enough entries to report the explicit resource bound, for both declarations and calls.
    for kind in ['parameters','direct','indirect']:
        source=root/(kind+'-1025.ssa')
        params=','.join(f'l %p{i}' for i in range(1025))
        args=','.join('l 1' for _ in range(1025))
        text=f'function l $bad({params}) {{ @s ret 0 }}' if kind=='parameters' else (
            'function l $bad(l %fn) { @s %r =l call '+('$external' if kind=='direct' else '%fn')+f'({args}) ret %r }}')
        source.write_text(text)
        r=run([compiler,'--check',source]);assert r.returncode!=0 and '1024-integer-' in r.stderr,(kind,r.stderr)
    # The certified profile remains eight parameters even though compatibility admits more.
    restricted=root/'certified-nine.ssa';restricted.write_text('function l $f('+','.join(f'l %p{i}' for i in range(9))+') { @s ret %p8 }')
    r=run([compiler,'--first-path',restricted]);assert r.returncode!=0,r.stderr
    # Existing fixed-frame bounds also apply when large aggregate arguments create
    # a separate outgoing area (including calls below a dynamic allocation).
    huge_params=','.join(f':huge %p{i}' for i in range(1024))
    huge_args=','.join(':huge %p' for _ in range(1024))
    for name,text in [
        ('incoming-frame',f'function l $f({huge_params}) {{ @s ret 0 }}'),
        ('outgoing-frame',f'function l $f() {{ @s %p =l alloc8 4096 %r =l call $external({huge_args}) ret %r }}'),
        ('dynamic-outgoing-frame',f'function l $f(l %n) {{ @s %p =l alloc8 %n %r =l call $external({huge_args}) ret %r }}'),
    ]:
        source=root/(name+'.ssa');source.write_text('type :huge = { l 512 }\n'+text)
        for flags in [[],['--allocate'],['--optimize']]:
            r=run([compiler,'--target',target,*flags,source,'-o',root/(name+'.s')])
            assert r.returncode!=0 and '1 MiB' in r.stderr,(name,flags,r.stderr)
    results=[]
    for count,edges,aggregates in PROFILES:
        case=root/(str(count)+('-aggregates' if aggregates else '-edges' if edges else '-scalar'));case.mkdir(exist_ok=True)
        source,caller=case/'input.ssa',case/'caller.c'
        ir,c=inputs(count,edges,aggregates);source.write_text(ir);caller.write_text(c)
        obj=case/'caller.o'
        if execute:
            r=run([cc,'-std=c11','-O1','-c',caller,'-o',obj],True);assert r.returncode==0,r.stderr
        for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',None)]:
            if mode=='qbe' and (not (execute and qbe) or
                                (qbe_profiles is not None and (count,edges,aggregates) not in qbe_profiles)):continue
            asm,exe=case/(mode+'.s'),case/mode
            cmd=[qbe,'-t',qtarget,'-o',asm,source] if mode=='qbe' else [compiler,'--target',target,*flags,source,'-o',asm]
            r=run(cmd,mode=='qbe');assert r.returncode==0,(count,edges,mode,r.stderr)
            if execute:
                link=[cc,obj,asm,'-o',exe]+(['-no-pie'] if mode=='qbe' and target=='riscv64-linux' else [])
                r=run(link,True);assert r.returncode==0,(count,edges,mode,r.stderr)
                r=run([exe],True);assert r.returncode==0,(count,edges,mode,r.returncode,r.stderr)
            results.append({'count':count,'edges':edges,'aggregates':aggregates,'mode':mode,'executed':execute})
        # Mutate the program's returned weighted sum, retaining ABI shape.
        if count==65 and not edges and execute:
            mutant=case/'mutant.ssa';mutant.write_text(ir.replace(' ret %h64\n',' ret 0\n',1))
            assert mutant.read_text()!=ir
            asm,exe=case/'mutant.s',case/'mutant'
            r=run([compiler,'--target',target,mutant,'-o',asm]);assert r.returncode==0,r.stderr
            r=run([cc,obj,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==1,'wrong target return escaped C checks'
    print(f'{target}: argument boundaries 64/65/128/1024 and rejection 1025; {len(PROFILES)} signatures, 16 seeds, five call paths, three LCB modes; narrow/aggregate edges and corruption control; execution={execute}; original QBE profiles={sum(row['mode']=='qbe' for row in results)}',flush=True)
    excluded = [profile for profile in PROFILES if qbe_profiles is not None and profile not in qbe_profiles]
    if excluded: print(f'{target}: original QBE exclusions {excluded}; signed-byte outbound-call defect and, on RV, large positive aggregate-frame offset defect', flush=True)
    identity = run([compiler, '--build-identity']); assert identity.returncode == 0, identity.stderr
    (root/'report.json').write_text(json.dumps({'target':target, 'compiler_identity':identity.stdout.strip(),
        'profiles':results, 'original_qbe_excluded_profiles':excluded,
        'independent_C_cases_per_LCB_mode':560 if execute else 0,
        'corruption_control':'detected' if execute else 'not executed',
        'bounds':'1025 parameters/direct/indirect arguments rejected; nine certified parameters rejected; incoming/fixed/dynamic outgoing areas above 1 MiB rejected'}, indent=2)+'\n')
    return results


def native_target():
    system, machine = platform.system(), platform.machine().lower()
    isa = {'arm64':'aarch64', 'aarch64':'aarch64', 'x86_64':'x86_64',
           'amd64':'x86_64', 'riscv64':'riscv64'}.get(machine)
    os_name = {'Darwin':'macos', 'Linux':'linux'}.get(system)
    target = f'{isa}-{os_name}'
    return target if target in TARGETS else None


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    native=native_target()
    if args.require_native:assert native is not None, 'supported native target unavailable'
    target=native or 'aarch64-macos'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=240)
    with tempfile.TemporaryDirectory(prefix='lcb-argument-limits-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=None
        if native:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        # Original RV QBE has signed-byte argument and large aggregate address
        # defects; Apple AMD64 QBE also fails signed-byte outbound C calls.
        # Keep the oracle exclusions explicit. Every LCB profile still runs
        # independently against C in all three modes.
        qbe_profiles=original_qbe_profiles(target)
        exercise(LCB,work,run,cc,target,native is not None,qbe,TARGETS[target],qbe_profiles)


if __name__=='__main__':main()
