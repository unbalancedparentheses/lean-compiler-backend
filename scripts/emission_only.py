#!/usr/bin/env python3
"""Target regression helpers must emit without invoking unavailable target tools."""
from pathlib import Path
import subprocess
import tempfile
from fuzz import ROOT, LCB
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
            normalization(LCB, case, run, cc, target, False, qbe, qtarget)
            empty_variadic(LCB, case, run, cc, target, False, qbe, qtarget)
            environment_variadic(LCB, case, run, cc, target, False, qbe, qtarget)
        for target in ['aarch64-linux', 'aarch64-macos']:
            extuw = arm_extuw(LCB,work/target,run,cc,target,False,qbe)
            assert extuw['checks_per_mode'] == 0 and extuw['negative_control'] == 'not-run'
            arm = arm_extensions(LCB, work/target, run, cc, target, False)
            assert arm['checks_per_mode'] == 0 and arm['negative_control'] == 'not-run'
            branches = arm_branches(LCB, work/target, run, cc, target, False, qbe, 'arm64', large=False)
            assert branches['c_checks_per_mode'] == 0 and branches['original_qbe'] == 'not_executed'
        for target in ['aarch64-linux','aarch64-macos','x86_64-linux','x86_64-macos','riscv64-linux']:
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
