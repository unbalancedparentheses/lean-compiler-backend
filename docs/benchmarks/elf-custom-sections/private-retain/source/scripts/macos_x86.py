#!/usr/bin/env python3
"""Qualify macOS AMD64 natively or through explicitly labelled Rosetta execution."""
import argparse
import json
import os
import shlex
from pathlib import Path
import platform
import shutil
import subprocess
from fuzz import ROOT, LCB
from upstream_suite import extract


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-execution', action='store_true')
    ap.add_argument('--optimize', action='store_true')
    ap.add_argument('--compiler', type=Path, default=LCB)
    args = ap.parse_args()
    work = ROOT/'.build/macos-x86'
    if args.optimize:
        work = work/'optimized'
    work.mkdir(parents=True, exist_ok=True)
    def selected_run(command, *positional, **keywords):
        command = list(map(str, command))
        if args.optimize and command[0] == str(compiler) and '-o' in command:
            command += ['--optimize']
        return run(command, *positional, **keywords)
    compiler = work/'lcb-snapshot'
    shutil.copy2(args.compiler, compiler)
    emission_modes = {'baseline': 0, 'allocated': 0, 'optimized': 0}
    def run(command, inside=False):
        command = list(map(str, command))
        if command[0] == str(compiler) and '-o' in command:
            mode = 'optimized' if '--optimize' in command else ('allocated' if '--allocate' in command else 'baseline')
            emission_modes[mode] += 1
        return subprocess.run(command, text=True, capture_output=True, timeout=120)
    darwin = platform.system() == 'Darwin'
    native = darwin and platform.machine() == 'x86_64'
    execute = native or (darwin and run(['/usr/bin/arch', '-x86_64', '/usr/bin/true']).returncode == 0)
    if args.require_execution:
        assert execute, 'macOS x86-64 execution unavailable'
    host_cc = os.environ.get('LCB_CC', 'cc')
    cc = work/'cc'
    cc.write_text(f'#!/bin/sh\nexec {shlex.quote(host_cc)} -arch x86_64 "$@"\n')
    cc.chmod(0o755)
    qbe = work/'oracle/qbe'
    if execute:
        if not qbe.parent.exists():
            shutil.copytree(ROOT/'third_party/qbe', qbe.parent)
        result = run(['make', '-C', qbe.parent, '-j2', f'CC={host_cc}'])
        assert result.returncode == 0, result.stderr
    rows, failures = [], []
    for fixture in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
        case = work/fixture.stem
        case.mkdir(exist_ok=True)
        assembly = case/'lean.s'
        result = selected_run([compiler, fixture, '--target', 'x86_64-macos', '-o', assembly])
        row = {'fixture': fixture.name, 'emitted': result.returncode == 0, 'diagnostic': result.stderr.strip(), 'execution': 'unmeasured'}
        rows.append(row)
        if result.returncode:
            if fixture.name != 'dark.ssa':
                failures.append((fixture.name, 'unexpected rejection', result.stderr))
            continue
        if not execute:
            continue
        qasm = case/'qbe.s'
        result = run([qbe, '-t', 'amd64_apple', '-o', qasm, fixture])
        assert result.returncode == 0, result.stderr
        driver, expected = extract(fixture.read_text(), 'driver'), extract(fixture.read_text(), 'output')
        caller = case/'driver.c'
        caller.write_text(driver)
        statuses = []
        for label, asm in [('lean', assembly), ('qbe', qasm)]:
            exe = case/label
            private = fixture.name.startswith('_')
            command = [cc, '-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int']
            command += ['-c', asm, '-o', exe] if private else ([caller, asm, '-o', exe] if driver else [asm, '-o', exe])
            result = run(command)
            if result.returncode:
                failures.append((fixture.name, label+' assembly/link', result.stderr))
                statuses.append('failed')
                continue
            if private:
                statuses.append('assembled')
                continue
            result = run([exe, 'a', 'b', 'c'])
            passed = (result.returncode >= 0 and result.stdout.replace('\r', '') == expected) if expected else result.returncode == 0
            statuses.append('passed' if passed else 'failed')
            if not passed:
                failures.append((fixture.name, label+' execution', result.returncode, result.stdout, result.stderr))
        row['execution'] = statuses[0] if len(set(statuses)) == 1 else 'failed'
    # Always retain/report original fixture failures before extended qualification.
    mode = 'native' if native else ('rosetta' if execute else 'not measured')
    report = {'target': 'x86_64-macos', 'optimized': args.optimize, 'compiler_identity': run([compiler, '--build-identity']).stdout.strip(), 'execution_mode': mode, 'fixtures': rows, 'failures': failures}
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'macOS AMD64: {sum(x["emitted"] for x in rows)}/76 emitted; {sum(x["execution"] == "passed" for x in rows)} executable and {sum(x["execution"] == "assembled" for x in rows)} assembly-only passes; execution={mode}', flush=True)
    for failure in failures:
        print(str(failure)[:3000], flush=True)
    assert not failures, f'{len(failures)} target failures'
    if execute:
        from target_scalar import exercise as scalar
        from target_aggregate import exercise as aggregate
        from target_tls import exercise as tls
        scalar(compiler, work, selected_run, cc, qbe, 'x86_64-macos', 'amd64_apple', 24)
        aggregate(compiler, work, selected_run, cc, qbe, 'x86_64-macos', 'amd64_apple')
        tls(compiler, work, selected_run, cc, 'x86_64-macos')
        from macho_objects import exercise as objects
        objects(compiler, work, selected_run, cc, qbe, 'x86_64-macos', 'amd64_apple')
    from quoted_names import exercise as quoted
    from zero_alloc import exercise as zero
    from section_names import exercise as section_name_tests
    section_name_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe)
    from large_aggregate_abi import exercise as aggregate_copy_tests
    aggregate_copy_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe)
    from elf_retain import exercise as elf_retain_tests
    elf_retain_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe)
    from integer_patterns import exercise as integer_pattern_tests
    integer_pattern_tests(compiler,work/"integer-patterns",run,[cc],'x86_64-macos',execute)
    from syntax_edges import exercise as syntax_edge_tests
    syntax_edge_tests(compiler,work/"syntax-edges",run,[cc],'x86_64-macos',execute)
    from data_relocations import exercise as data_relocation_tests
    data_relocation_tests(compiler,work/"data-relocations",run,[cc],'x86_64-macos',execute)
    from large_data import exercise as large_data_tests
    large_data_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from large_objects import exercise as large_object_tests
    large_object_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from memory_promotion import exercise as memory_tests
    memory_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from prefix_collisions import exercise as prefix_collision_tests
    prefix_collision_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from promotion_bindings import exercise as promotion_binding_tests
    promotion_binding_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from dynamic_outgoing import exercise as dynamic_outgoing_tests
    dynamic_outgoing_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from unused_environment import exercise as unused_environment_tests
    unused_environment_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    from branch_fallthrough import exercise as fallthrough_tests
    fallthrough_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    from signed_division_one import exercise as signed_one_tests
    signed_one_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    from amd_leaf_bank import exercise as amd_leaf_tests
    amd_leaf_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from amd_word_normalization import exercise as amd_word_tests
    amd_word_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    from amd_immediates import exercise as amd_immediate_tests
    amd_immediate_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    from empty_variadic_calls import exercise as empty_variadic_tests
    from unused_environment_variadic import exercise as unused_env_variadic_tests
    empty_variadic_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    unused_env_variadic_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple')
    from argument_limits import exercise as argument_limit_tests, original_qbe_profiles
    argument_limit_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe,'amd64_apple',original_qbe_profiles('x86_64-macos'))
    from extern_flags import exercise as flags_tests
    flags_tests(compiler,work,run,cc,qbe,'x86_64-macos','amd64_apple',execute)
    from allocation import exercise as allocation_tests
    allocation_tests(compiler, work, run, cc, 'x86_64-macos', execute)
    from control_flow import exercise as cfg
    from large_blit import exercise as large_blit_tests
    large_blit_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe if execute else None,'amd64_apple')
    from blit_guard_pages import exercise as guard_page_tests
    guard_page_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from address_selection import exercise as address_selection_tests
    address_selection_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from branch_selection import exercise as branch_selection_tests
    branch_selection_tests(compiler,work,run,cc,'x86_64-macos',execute)
    from memory_forward import exercise as memory_forward_tests
    memory_forward_tests(compiler, work, run, cc, 'x86_64-macos', execute)
    from redundant_extensions import exercise as extension_tests
    extension_tests(compiler, work, run, cc, 'x86_64-macos', execute)
    from unsigned_strength import exercise as unsigned_tests
    unsigned_tests(compiler, work, run, cc, 'x86_64-macos', execute)
    from global_addresses import exercise as global_addresses
    global_addresses(compiler, work, run, cc, 'x86_64-macos', execute)
    from module_scale import exercise as modules
    quoted(compiler, work, selected_run, cc, qbe, 'x86_64-macos', 'amd64_apple', execute)
    zero(compiler, work, selected_run, cc, qbe, 'x86_64-macos', 'amd64_apple', execute)
    cfg(compiler, work, run, cc, 'x86_64-macos', execute, optimized_only=args.optimize)
    modules(compiler, work, selected_run, cc, 'x86_64-macos', execute)
    if not args.optimize:
        from constant_fold import exercise as fold
        fold(compiler, work, run, cc, 'x86_64-macos', execute)

    from upstream_development import exercise as development_tests
    development_tests(compiler,work,run,cc,'x86_64-macos',execute,qbe)

    from symbol_address_pressure import exercise as symbol_pressure
    symbol_pressure(compiler,work,run,cc,'x86_64-macos',execute,qbe)

    from scalar_result_discard import exercise as scalar_discard
    scalar_discard(compiler,work,run,cc,'x86_64-macos',execute,qbe)

    from unused_call_results import exercise as unused_results
    unused_results(compiler,work,run,cc,'x86_64-macos',execute,qbe)

    assert all(emission_modes.values()), ('missing actual lowering mode', emission_modes)
    print('Actual compiler emission modes:', emission_modes, flush=True)
    report['emission_mode_counts'] = emission_modes
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
