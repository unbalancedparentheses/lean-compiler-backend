#!/usr/bin/env python3
"""Target regression helpers must emit without invoking unavailable target tools."""
from pathlib import Path
import subprocess
import tempfile
from fuzz import ROOT, LCB
from aggregate_signature_aliases import exercise as aggregate_signature_aliases
from mutable_integer_widths import exercise as mutable_integer_widths
from elf_section_names import exercise as elf_section_names
from retained_tls import exercise as retained_tls
from custom_tls_sections import exercise as custom_tls_sections
from elf_retain import exercise as elf_retain
from amd_leaf_bank import exercise as amd_leaf_bank
from upstream_development import exercise as upstream_development
from symbol_address_pressure import exercise as symbol_pressure
from scalar_result_discard import exercise as scalar_discard
from arm_indexed_load import exercise as arm_indexed_load
from arm_scaled_load import exercise as arm_scaled_load
from arm_phi_identity import exercise as arm_phi_identity
from arm_leaf_bank import exercise as arm_leaf_bank
from arm_extuw import exercise as arm_extuw
from branch_fallthrough import exercise as fallthrough
from signed_division_one import exercise as signed_one
from arm_branch_layout import exercise as arm_branches
from arm_load_extensions import exercise as arm_extensions
from rv_result_normalization import exercise as rv_normalization
from amd_immediates import exercise as immediates
from amd_word_normalization import exercise as normalization
from empty_variadic_calls import exercise as empty_variadic
from unused_environment_variadic import exercise as environment_variadic


def main():
    with tempfile.TemporaryDirectory(prefix='emission-only-', dir=ROOT/'.build') as directory:
        work = Path(directory)
        cc, qbe = work/'missing-cc', work/'missing-qbe'
        def run(command, inside=False):
            assert not inside, ('target execution attempted in emission-only mode', command)
            return subprocess.run(list(map(str, command)), capture_output=True, text=True, timeout=120)
        for target, qtarget in [('x86_64-linux', 'amd64_sysv'), ('x86_64-macos', 'amd64_apple')]:
            case = work/target
            case.mkdir()
            result = immediates(LCB, case, run, cc, target, False, qbe, qtarget)
            assert result['checks_per_mode'] == result['qbe_checks'] == 0
            assert result['qbe_sha256'] is None and not result['wrong_immediate_detected']
            assert all(status == 'emitted' for status in result['modes'].values())
            leaf = amd_leaf_bank(LCB,case,run,cc,target,False)
            assert leaf['executed_checks'] == 0
            normalization(LCB, case, run, cc, target, False, qbe, qtarget)
            empty_variadic(LCB, case, run, cc, target, False, qbe, qtarget)
            environment_variadic(LCB, case, run, cc, target, False, qbe, qtarget)
        for target in ['aarch64-linux', 'aarch64-macos']:
            scaled = arm_scaled_load(LCB,work/target,run,cc,target,False,qbe=qbe)
            assert all(v['execution'] == 'not-run' for p in scaled['profiles'].values() for v in p['backends'].values())
            assert 'qbe_sha256' not in scaled
            indexed = arm_indexed_load(LCB,work/target,run,cc,target,False,qbe=qbe)
            assert indexed['case_groups_per_mode'] == 0 and indexed['original_qbe'] == 'not-run'
            phi = arm_phi_identity(LCB,work/target,run,cc,target,False,qbe)
            assert phi['checks_per_mode'] == 0 and phi['original_qbe'] == 'not-run'
            leaf = arm_leaf_bank(LCB,work/target,run,cc,target,False)
            assert leaf['executed_checks'] == 0
            assert all(v['execution'] == 'not-run' for v in leaf['modes'].values())
            extuw = arm_extuw(LCB,work/target,run,cc,target,False,qbe)
            assert extuw['checks_per_mode'] == 0 and extuw['negative_control'] == 'not-run'
            arm = arm_extensions(LCB, work/target, run, cc, target, False)
            assert arm['checks_per_mode'] == 0 and arm['negative_control'] == 'not-run'
            branches = arm_branches(LCB, work/target, run, cc, target, False, qbe, 'arm64', large=False)
            assert branches['c_checks_per_mode'] == 0 and branches['original_qbe'] == 'not_executed'
        for target in ['aarch64-linux','aarch64-macos','x86_64-linux','x86_64-macos','riscv64-linux']:
            aliases = aggregate_signature_aliases(LCB,work/target,run,cc,target,False,qbe)
            assert aliases['checks_per_backend'] == 0 and 'qbe' not in aliases['backends']
            widths = mutable_integer_widths(LCB,work/target,run,cc,target,False,qbe)
            assert widths['checks_per_backend'] == 0 and 'qbe' not in widths['backends']
            elf_names = elf_section_names(LCB,work/target,run,cc,target,False,qbe)
            assert elf_names['executed_modes'] == 0 and elf_names['qbe_sha256'] is None
            retained = retained_tls(LCB,work/target,run,cc,target,False,qbe)
            assert retained['checks_per_backend'] == 0 and 'qbe_sha256' not in retained
            tls = custom_tls_sections(LCB,work/target,run,cc,target,False,qbe)
            assert tls['executed_round_groups'] == 0 and tls['qbe_sha256'] is None
            assert tls['ordinary_equivalence'] == 'skipped: no before snapshot supplied'
            retained = elf_retain(LCB,work/target,run,cc,target,False,qbe)
            assert retained['executed_modes'] == 0 and retained['qbe_sha256'] is None
            development = upstream_development(LCB,work/target,run,cc,target,False,qbe)
            assert development['checks_per_lcb_mode'] == 0 and development['original_qbe'] == 'not-run'
            discarded = scalar_discard(LCB,work/target,run,cc,target,False,qbe)
            assert discarded['checks_per_backend'] == 0 and discarded['original_qbe'] == 'not-run'
            assert all(row['execution'] == 'not-run' for row in discarded['backends'].values())
            pressure = symbol_pressure(LCB,work/target,run,cc,target,False,qbe)
            assert pressure['checks_per_backend'] == 0 and pressure['negative_control'] == 'not-run'
            assert all(row['execution'] == 'not-run' for row in pressure['backends'].values())
            signed = signed_one(LCB,work/target,run,cc,target,False,qbe,'missing-target')
            assert signed['executed_checks_per_mode'] == 0 and signed['qbe_sha256'] is None
        for target in ['x86_64-linux','x86_64-macos','riscv64-linux']:
            branch = fallthrough(LCB,work/target,run,cc,target,False,qbe)
            assert branch['c_checks_per_mode'] == 0 and not branch['wrong_target_detected']
        rv = rv_normalization(LCB, work, run, cc, execute=False)
        assert rv['executed_checks_per_mode'] == 0 and rv['negative_control'] == 'not-run'
        assert all(v['execution'] == 'not-run' for v in rv['modes'].values())
        print('Emission-only target helpers passed with missing tools and an execution guard')


if __name__ == '__main__':
    main()
