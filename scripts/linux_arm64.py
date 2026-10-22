#!/usr/bin/env python3
"""Qualify Linux ARM64 emission and optionally execute original QBE drivers.

For macOS development, --docker-container names an existing ARM64 Linux container
with this script's --work directory mounted at /work, gcc installed, and pinned
QBE built at /tmp/qbe/qbe. CI can run directly on an ARM64 Linux host.
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
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container')
    ap.add_argument('--optimize', action='store_true')
    ap.add_argument('--require-native', action='store_true')
    ap.add_argument('--work', type=Path, default=ROOT/'.build/linux-arm64')
    args = ap.parse_args()
    mount_root = args.work.resolve()
    work = mount_root/'optimized-arm64' if args.optimize else mount_root
    work.mkdir(parents=True, exist_ok=True)
    native = bool(args.docker_container) or (platform.system() == 'Linux' and platform.machine() in ['aarch64', 'arm64'])
    if args.require_native: assert native, 'Linux ARM64 execution unavailable'
    emission_modes = {'baseline': 0, 'allocated': 0, 'optimized': 0}
    def run(command, inside=False):
        command = [str(x) for x in command]
        if command[0] == str(compiler) and '-o' in command:
            mode = 'optimized' if '--optimize' in command else ('allocated' if '--allocate' in command else 'baseline')
            emission_modes[mode] += 1
        if inside and args.docker_container:
            from docker_sync import sources
            sources(command, mount_root, args.docker_container)
            command = ['docker', 'exec', args.docker_container] + [x.replace(str(mount_root), '/work') for x in command]
        result = subprocess.run(command, text=True, capture_output=True, timeout=120)
        if args.docker_container and not inside and command[0] == str(compiler) and result.returncode == 0 and '-o' in command:
            from docker_sync import host_file
            host_file(command[command.index('-o')+1], mount_root, args.docker_container)
        return result
    def selected_run(command, *positional, **keywords):
        command = list(map(str, command))
        if args.optimize and command[0] == str(compiler) and '-o' in command:
            command += ['--optimize']
        return run(command, *positional, **keywords)
    compiler = work/'lcb-snapshot'
    shutil.copy2(LCB, compiler)
    compiler_identity = run([compiler, '--build-identity']).stdout.strip()
    qbe = '/tmp/qbe/qbe'
    cc = 'gcc' if args.docker_container else os.environ.get('LCB_CC', 'cc')
    if native and not args.docker_container:
        oracle = work/'oracle'
        if not oracle.exists(): shutil.copytree(ROOT/'third_party/qbe', oracle)
        result = run(['make', '-C', oracle, '-j2', f'CC={cc}']); assert result.returncode == 0, result.stderr
        qbe = oracle/'qbe'
    rows, failures = [], []
    for fixture in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
        case = work/fixture.stem; case.mkdir(exist_ok=True)
        source, assembly = case/'input.ssa', case/'lean.s'
        shutil.copy2(fixture, source)
        result = selected_run([compiler, source, '--target', 'aarch64-linux', '-o', assembly])
        row = {'fixture': fixture.name, 'emitted': result.returncode == 0, 'diagnostic': result.stderr.strip(), 'native': 'unmeasured'}
        rows.append(row)
        if result.returncode:
            assert 'not yet implemented' in result.stderr or fixture.name == 'dark.ssa', result.stderr
            continue
        text = assembly.read_text()
        assert '@GOTPAGE' not in text and '.subsections_via_symbols' not in text
        if not native: continue
        source_text = source.read_text()
        driver, expected = extract(source_text, 'driver'), extract(source_text, 'output')
        cfile = case/'driver.c'; cfile.write_text(driver)
        qasm = case/'qbe.s'; result = run([qbe, '-t', 'arm64', '-o', qasm, source], True)
        if result.returncode:
            failures.append((fixture.name, 'QBE emission', result.stderr)); continue
        statuses = []
        for label, asm in [('lean', assembly), ('qbe', qasm)]:
            exe = case/label
            command = [cc, '-Wno-error=implicit-function-declaration', '-Wno-error=implicit-int']
            private = fixture.name.startswith('_')
            command += ['-c', asm, '-o', exe] if private else ([cfile, asm, '-o', exe] if driver else [asm, '-o', exe])
            result = run(command, True)
            if result.returncode:
                failures.append((fixture.name, label+' assembly/link', result.stderr)); statuses.append('failed'); continue
            if private: statuses.append('assembled'); continue
            result = run([exe, 'a', 'b', 'c'], True)
            passed = (result.returncode >= 0 and result.stdout.replace('\r', '') == expected) if expected else result.returncode == 0
            statuses.append('passed' if passed else 'failed')
            if not passed: failures.append((fixture.name, label+' execution', result.returncode, result.stdout, result.stderr, expected))
        row['native'] = statuses[0] if len(statuses) == 2 and len(set(statuses)) == 1 else 'failed'
    if native:
        from tls import SOURCE as tls_source, CALLER as tls_caller
        case = work/'tls-interop'; case.mkdir(exist_ok=True)
        source, assembly, caller = case/'input.ssa', case/'lean.s', case/'caller.c'
        source.write_text(tls_source); caller.write_text(tls_caller)
        result = selected_run([compiler, source, '--target', 'aarch64-linux', '-o', assembly])
        assert result.returncode == 0, result.stderr
        for shared in [False, True]:
            exe = case/('shared' if shared else 'static')
            if shared:
                library = case/'liblcb_tls.so'
                result = run([cc, '-fPIC', '-shared', assembly, '-o', library], True)
                assert result.returncode == 0, result.stderr
                command = [cc, '-pthread', caller, library, '-Wl,-rpath,$ORIGIN', '-o', exe]
            else:
                command = [cc, '-pthread', caller, assembly, '-o', exe]
            result = run(command, True); assert result.returncode == 0, result.stderr
            result = run([exe], True)
            assert result.returncode == 0 and result.stdout == 'TLS passed\n', (shared, result.returncode, result.stdout, result.stderr)
        print('Linux TLS: eight concurrent C threads, external TLS, mixed live arguments and executable/shared-library linkage passed', flush=True)
        from float_variadic import fixture as floating_variadics
        source_text, caller_text = floating_variadics(32)
        case = work/'variadic-interop'; case.mkdir(exist_ok=True)
        source, assembly, caller = case/'input.ssa', case/'lean.s', case/'caller.c'
        source.write_text(source_text); caller.write_text(caller_text)
        result = selected_run([compiler, source, '--target', 'aarch64-linux', '-o', assembly])
        assert result.returncode == 0, result.stderr
        qasm = case/'qbe.s'; result = run([qbe, '-t', 'arm64', '-o', qasm, source], True)
        assert result.returncode == 0, result.stderr
        for label, asm in [('lean', assembly), ('qbe', qasm)]:
            exe = case/label
            result = run([cc, caller, asm, '-o', exe], True); assert result.returncode == 0, result.stderr
            result = run([exe], True); assert result.returncode == 0, (label, result.returncode, result.stderr)
        print('Linux variadics: mixed GP/FP exhaustion, dynamic frames, direct/indirect calls and C interoperation passed against QBE', flush=True)

    if native:
        from target_scalar import exercise as scalar_tests
        scalar_tests(compiler,work, selected_run,cc,qbe,'aarch64-linux','arm64',32)

    from quoted_names import exercise as quoted_tests
    quoted_tests(compiler,work, selected_run,cc,qbe,'aarch64-linux','arm64',native)
    from global_addresses import exercise as global_address_tests
    global_address_tests(compiler,work,run,cc,'aarch64-linux',native)
    from large_blit import exercise as large_blit_tests
    large_blit_tests(compiler,work,run,cc,'aarch64-linux',native,qbe if native else None,'arm64')
    from blit_guard_pages import exercise as guard_page_tests
    guard_page_tests(compiler,work,run,cc,'aarch64-linux',native)
    from address_selection import exercise as address_selection_tests
    address_selection_tests(compiler,work,run,cc,'aarch64-linux',native)
    from branch_selection import exercise as branch_selection_tests
    branch_selection_tests(compiler,work,run,cc,'aarch64-linux',native)
    from memory_forward import exercise as memory_forward_tests
    memory_forward_tests(compiler,work,run,cc,'aarch64-linux',native)
    from redundant_extensions import exercise as extension_tests
    extension_tests(compiler,work,run,cc,'aarch64-linux',native)
    from arm_load_extensions import exercise as arm_load_extension_tests
    arm_load_extension_tests(compiler,work,run,cc,'aarch64-linux',native)
    from arm_leaf_bank import exercise as arm_leaf_bank_tests
    arm_leaf_bank_tests(compiler,work,run,cc,'aarch64-linux',native)
    from arm_indexed_load import exercise as arm_indexed_tests
    arm_indexed_tests(compiler,work,run,cc,'aarch64-linux',native,qbe=qbe)
    from arm_phi_identity import exercise as arm_phi_tests
    arm_phi_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from arm_extuw import exercise as arm_extuw_tests
    arm_extuw_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from arm_branch_layout import exercise as arm_branch_tests
    arm_branch_tests(compiler,work,run,cc,'aarch64-linux',native,qbe,'arm64')
    from signed_division_one import exercise as signed_one_tests
    signed_one_tests(compiler,work,run,cc,'aarch64-linux',native,qbe,'arm64')
    from unsigned_strength import exercise as unsigned_tests
    unsigned_tests(compiler,work,run,cc,'aarch64-linux',native)
    from module_scale import exercise as module_tests
    module_tests(compiler,work, selected_run,cc,'aarch64-linux',native)
    from extern_offsets import exercise as extern_offset_tests
    extern_offset_tests(compiler,work,run,cc,qbe,native)
    from section_names import exercise as section_name_tests
    section_name_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from elf_section_names import exercise as elf_name_tests
    elf_name_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from custom_tls_sections import exercise as custom_tls_tests
    custom_tls_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from aggregate_signature_aliases import exercise as aggregate_alias_tests
    aggregate_alias_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from mutable_integer_widths import exercise as mutable_width_tests
    mutable_width_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from large_aggregate_abi import exercise as aggregate_copy_tests
    aggregate_copy_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from elf_retain import exercise as elf_retain_tests
    elf_retain_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)
    from integer_patterns import exercise as integer_pattern_tests
    integer_pattern_tests(compiler,work/"integer-patterns",run,[cc],'aarch64-linux',native)
    from syntax_edges import exercise as syntax_edge_tests
    syntax_edge_tests(compiler,work/"syntax-edges",run,[cc],'aarch64-linux',native)
    from data_relocations import exercise as data_relocation_tests
    data_relocation_tests(compiler,work/"data-relocations",run,[cc],'aarch64-linux',native)
    from large_data import exercise as large_data_tests
    large_data_tests(compiler,work,run,cc,'aarch64-linux',native)
    from large_objects import exercise as large_object_tests
    large_object_tests(compiler,work,run,cc,'aarch64-linux',native)
    from memory_promotion import exercise as memory_tests
    memory_tests(compiler,work,run,cc,'aarch64-linux',native)
    from prefix_collisions import exercise as prefix_collision_tests
    prefix_collision_tests(compiler,work,run,cc,'aarch64-linux',native)
    from promotion_bindings import exercise as promotion_binding_tests
    promotion_binding_tests(compiler,work,run,cc,'aarch64-linux',native)
    from dynamic_outgoing import exercise as dynamic_outgoing_tests
    dynamic_outgoing_tests(compiler,work,run,cc,'aarch64-linux',native)
    from unused_environment import exercise as unused_environment_tests
    unused_environment_tests(compiler,work,run,cc,'aarch64-linux',native,qbe,'arm64')
    from argument_limits import exercise as argument_limit_tests, original_qbe_profiles
    argument_limit_tests(compiler,work,run,cc,'aarch64-linux',native,qbe,'arm64',original_qbe_profiles('aarch64-linux'))
    from allocation import exercise as allocation_tests
    allocation_tests(compiler,work,run,cc,'aarch64-linux',native,optimized_only=args.optimize)
    from instruction_selection import exercise as selection_tests
    selection_tests(compiler,work,run,cc,'aarch64-linux',native)
    from control_flow import exercise as cfg_tests
    cfg_tests(compiler,work,run,cc,'aarch64-linux',native,optimized_only=args.optimize)
    from constant_fold import exercise as fold_tests
    if not args.optimize:fold_tests(compiler,work,run,cc,'aarch64-linux',native)
    from zero_alloc import exercise as zero_tests
    zero_tests(compiler,work, selected_run,cc,qbe,'aarch64-linux','arm64',native)
    from elf_sections import exercise as section_tests
    section_tests(compiler, work, selected_run, cc, qbe, native)
    baseline = json.loads((ROOT/'tests/upstream-linux-arm64-coverage.json').read_text())['emitted']
    emitted_names = {row['fixture'] for row in rows if row['emitted']}
    for missing in sorted(set(baseline) - emitted_names): failures.append((missing, 'emission regression'))
    report = {'target': 'aarch64-linux', 'optimized': args.optimize, 'compiler_identity': compiler_identity, 'fixtures': rows, 'failures': failures}
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    emitted = sum(row['emitted'] for row in rows)
    executed = sum(row['native'] == 'passed' for row in rows)
    assembled = sum(row['native'] == 'assembled' for row in rows)
    print(f'Linux ARM64: {emitted}/{len(rows)} emitted; {executed} original executable drivers and {assembled} assembly-only fixtures passed per Lean/QBE backend; native={native}', flush=True)
    for failure in failures: print(failure, flush=True)
    assert not failures, f'{len(failures)} Linux ARM64 failures'

    from upstream_development import exercise as development_tests
    development_tests(compiler,work,run,cc,'aarch64-linux',native,qbe)

    from symbol_address_pressure import exercise as symbol_pressure
    symbol_pressure(compiler,work,run,cc,'aarch64-linux',native,qbe)

    from scalar_result_discard import exercise as scalar_discard
    scalar_discard(compiler,work,run,cc,'aarch64-linux',native,qbe)

    from unused_call_results import exercise as unused_results
    unused_results(compiler,work,run,cc,'aarch64-linux',native,qbe)

    assert all(emission_modes.values()), ('missing actual lowering mode', emission_modes)
    print('Actual compiler emission modes:', emission_modes, flush=True)
    report['emission_mode_counts'] = emission_modes
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__': main()
