#!/usr/bin/env python3
"""Qualify non-ARM Linux targets natively or via QEMU in the development container.

The optional ARM64 Docker container uses /work for .build/linux-arm64 and contains
pinned QBE plus cross-GCC and qemu-user. Emulated runs are labelled separately.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
from fuzz import ROOT, LCB
from upstream_suite import extract


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', choices=['x86_64-linux','riscv64-linux'], default='x86_64-linux')
    ap.add_argument('--docker-container')
    ap.add_argument('--optimize',action='store_true',help='qualify the optional compatibility optimizer')
    ap.add_argument('--require-execution', action='store_true')
    args=ap.parse_args()
    isa, qtarget = ('x86_64','amd64_sysv') if args.target=='x86_64-linux' else ('riscv64','rv64')
    docker_root=ROOT/'.build/linux-arm64'; work=docker_root/isa
    if args.optimize:work=work/'optimized'
    work.mkdir(parents=True,exist_ok=True)
    native=platform.system()=='Linux' and platform.machine() in ([isa,'amd64'] if isa=='x86_64' else [isa])
    execute=native or bool(args.docker_container)
    if args.require_execution:assert execute, 'target execution unavailable'
    emission_modes = {'baseline': 0, 'allocated': 0, 'optimized': 0}
    def run(command,inside=False,executable=False):
        command=[str(x) for x in command]
        if command[0] == str(compiler) and '-o' in command:
            mode = 'optimized' if '--optimize' in command else ('allocated' if '--allocate' in command else 'baseline')
            emission_modes[mode] += 1
        if inside and args.docker_container:
            from docker_sync import sources
            sources(command,docker_root,args.docker_container)
            if executable or command[0].startswith(str(work)+"/"):command=[f'qemu-{isa}','-L',f'/usr/{isa}-linux-gnu']+command
            command=['docker','exec',args.docker_container]+[x.replace(str(docker_root),'/work') for x in command]
        result=subprocess.run(command,text=True,capture_output=True,timeout=120)
        if args.docker_container and not inside and command[0]==str(compiler) and result.returncode==0 and '-o' in command:
            from docker_sync import host_file
            host_file(command[command.index('-o')+1],docker_root,args.docker_container)
        return result
    def selected_run(command, *positional, **keywords):
        command = list(map(str, command))
        if args.optimize and command[0] == str(compiler) and '-o' in command:
            command += ['--optimize']
        return run(command, *positional, **keywords)
    compiler=work/'lcb-snapshot';shutil.copy2(LCB,compiler)
    identity=run([compiler,'--build-identity']).stdout.strip()
    cc=os.environ.get('LCB_CROSS_CC',f'{isa}-linux-gnu-gcc') if args.docker_container else os.environ.get('LCB_CC','cc')
    qbe='/tmp/qbe/qbe'
    if native and not args.docker_container:
        oracle=work/'oracle'
        if not oracle.exists():shutil.copytree(ROOT/'third_party/qbe',oracle)
        result=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert result.returncode==0,result.stderr
        qbe=oracle/'qbe'
    rows=[];failures=[]
    for fixture in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
        case=work/fixture.stem;case.mkdir(exist_ok=True)
        source,assembly=case/'input.ssa',case/'lean.s';shutil.copy2(fixture,source)
        result=selected_run([compiler,source,'--target',args.target,'-o',assembly])
        row={'fixture':fixture.name,'emitted':result.returncode==0,'diagnostic':result.stderr.strip(),'execution':'unmeasured'};rows.append(row)
        if result.returncode:
            if 'not yet implemented' not in result.stderr and fixture.name!='dark.ssa':failures.append((fixture.name,'unexpected rejection',result.stderr))
            continue
        if not execute:continue
        text=source.read_text();driver,expected=extract(text,'driver'),extract(text,'output')
        cfile=case/'driver.c';cfile.write_text(driver)
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,source],True)
        if result.returncode:failures.append((fixture.name,'QBE emission',result.stderr));continue
        statuses=[]
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label;private=fixture.name.startswith('_')
            command=[cc,'-Wno-error=implicit-function-declaration','-Wno-error=implicit-int']
            if isa=='riscv64' and label=='qbe':command+=['-no-pie']
            command+=['-c',asm,'-o',exe] if private else ([cfile,asm,'-o',exe] if driver else [asm,'-o',exe])
            result=run(command,True)
            if result.returncode:
                failures.append((fixture.name,label+' assembly/link',result.stderr));statuses.append('failed');continue
            if private:statuses.append('assembled');continue
            result=run([exe,'a','b','c'],True,True)
            passed=(result.returncode>=0 and result.stdout.replace('\r','')==expected) if expected else result.returncode==0
            statuses.append('passed' if passed else 'failed')
            if not passed:failures.append((fixture.name,label+' execution',result.returncode,result.stdout,result.stderr,expected))
        row['execution']=statuses[0] if len(statuses)==2 and len(set(statuses))==1 else 'failed'
    if execute:
        from target_scalar import exercise
        exercise(compiler,work, selected_run,cc,qbe,args.target,qtarget,24 if isa=='x86_64' else 8)
        from target_aggregate import exercise as aggregate_tests
        aggregate_tests(compiler,work, selected_run,cc,qbe,args.target,qtarget)
        if isa=='riscv64':
            from riscv_abi import exercise as riscv_tests
            riscv_tests(compiler,work, selected_run,cc,qbe)
        from target_tls import exercise as tls_tests
        tls_tests(compiler,work, selected_run,cc,args.target)
    from quoted_names import exercise as quoted_tests
    quoted_tests(compiler,work, selected_run,cc,qbe,args.target,qtarget,execute)
    from global_addresses import exercise as global_address_tests
    global_address_tests(compiler,work,run,cc,args.target,execute)
    from large_blit import exercise as large_blit_tests
    large_blit_tests(compiler,work,run,cc,args.target,execute,qbe if execute else None,qtarget)
    from blit_guard_pages import exercise as guard_page_tests
    guard_page_tests(compiler,work,run,cc,args.target,execute)
    from address_selection import exercise as address_selection_tests
    address_selection_tests(compiler,work,run,cc,args.target,execute)
    from branch_selection import exercise as branch_selection_tests
    branch_selection_tests(compiler,work,run,cc,args.target,execute)
    from memory_forward import exercise as memory_forward_tests
    memory_forward_tests(compiler,work,run,cc,args.target,execute)
    from redundant_extensions import exercise as extension_tests
    extension_tests(compiler,work,run,cc,args.target,execute)
    from unsigned_strength import exercise as unsigned_tests
    unsigned_tests(compiler,work,run,cc,args.target,execute)
    from module_scale import exercise as module_tests
    module_tests(compiler,work, selected_run,cc,args.target,execute)
    from extern_offsets import exercise as extern_offset_tests
    extern_offset_tests(compiler,work,run,cc,qbe,execute,args.target)
    from integer_patterns import exercise as integer_pattern_tests
    integer_pattern_tests(compiler,work/"integer-patterns",run,[cc],args.target,execute)
    from syntax_edges import exercise as syntax_edge_tests
    syntax_edge_tests(compiler,work/"syntax-edges",run,[cc],args.target,execute)
    from data_relocations import exercise as data_relocation_tests
    data_relocation_tests(compiler,work/"data-relocations",run,[cc],args.target,execute)
    from large_data import exercise as large_data_tests
    large_data_tests(compiler,work,run,cc,args.target,execute)
    from large_objects import exercise as large_object_tests
    large_object_tests(compiler,work,run,cc,args.target,execute)
    from memory_promotion import exercise as memory_tests
    memory_tests(compiler,work,run,cc,args.target,execute)
    from prefix_collisions import exercise as prefix_collision_tests
    prefix_collision_tests(compiler,work,run,cc,args.target,execute)
    from promotion_bindings import exercise as promotion_binding_tests
    promotion_binding_tests(compiler,work,run,cc,args.target,execute)
    from dynamic_outgoing import exercise as dynamic_outgoing_tests
    dynamic_outgoing_tests(compiler,work,run,cc,args.target,execute)
    from unused_environment import exercise as unused_environment_tests
    unused_environment_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
    from branch_fallthrough import exercise as fallthrough_tests
    fallthrough_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
    from signed_division_one import exercise as signed_one_tests
    signed_one_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
    if args.target == 'x86_64-linux':
        from amd_word_normalization import exercise as amd_word_tests
        amd_word_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
        from amd_immediates import exercise as amd_immediate_tests
        amd_immediate_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
        from empty_variadic_calls import exercise as empty_variadic_tests
        from unused_environment_variadic import exercise as unused_env_variadic_tests
        empty_variadic_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
        unused_env_variadic_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget)
    from argument_limits import exercise as argument_limit_tests, original_qbe_profiles
    argument_limit_tests(compiler,work,run,cc,args.target,execute,qbe,qtarget,original_qbe_profiles(args.target))
    if args.target == 'riscv64-linux':
        from rv_load_normalization import exercise as rv_load_tests
        rv_load_tests(compiler,work,run,cc,execute=execute)
        from rv_immediates import exercise as rv_immediate_tests
        rv_immediate_tests(compiler,work,run,cc,execute=execute,qbe=qbe,qtarget=qtarget)
        from rv_result_normalization import exercise as rv_result_tests
        rv_result_tests(compiler,work,run,cc,execute=execute)
    if args.target == 'x86_64-linux':
        from extern_flags import exercise as flags_tests
        flags_tests(compiler,work,run,cc,qbe,args.target,qtarget,execute)
    from allocation import exercise as allocation_tests
    allocation_tests(compiler,work,run,cc,args.target,execute)
    from control_flow import exercise as cfg_tests
    cfg_tests(compiler,work,run,cc,args.target,execute,optimized_only=args.optimize)
    from constant_fold import exercise as fold_tests
    if not args.optimize:fold_tests(compiler,work,run,cc,args.target,execute)
    from zero_alloc import exercise as zero_tests
    zero_tests(compiler,work, selected_run,cc,qbe,args.target,qtarget,execute)
    baseline=ROOT/f'tests/upstream-{isa}-coverage.json'
    if baseline.exists():
        missing=set(json.loads(baseline.read_text())['emitted'])-{x['fixture'] for x in rows if x['emitted']}
        failures.extend((x,'emission regression') for x in sorted(missing))
    mode='emulated' if args.docker_container else ('native' if native else 'not measured')
    report={'target':args.target,'optimized':args.optimize,'compiler_identity':identity,'execution_mode':mode,'fixtures':rows,'failures':failures}
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{args.target}: {sum(x["emitted"] for x in rows)}/76 emitted; {sum(x["execution"]=="passed" for x in rows)} executable drivers and {sum(x["execution"]=="assembled" for x in rows)} assembly-only passes per Lean/QBE backend; execution={mode}',flush=True)
    for failure in failures:print(str(failure)[:3000],flush=True)
    assert not failures, f'{len(failures)} target failures'

    assert all(emission_modes.values()), ('missing actual lowering mode', emission_modes)
    print('Actual compiler emission modes:', emission_modes, flush=True)
    report['emission_mode_counts'] = emission_modes
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__=='__main__':main()
