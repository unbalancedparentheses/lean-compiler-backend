#!/usr/bin/env python3
"""Target regression helpers must emit without invoking unavailable target tools."""
from pathlib import Path
import subprocess
import tempfile
from fuzz import ROOT, LCB
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
            arm = arm_extensions(LCB, work/target, run, cc, target, False)
            assert arm['checks_per_mode'] == 0 and arm['negative_control'] == 'not-run'
        rv = rv_normalization(LCB, work, run, cc, execute=False)
        assert rv['executed_checks_per_mode'] == 0 and rv['negative_control'] == 'not-run'
        assert all(v['execution'] == 'not-run' for v in rv['modes'].values())
        print('Emission-only target helpers passed with missing tools and an execution guard')


if __name__ == '__main__':
    main()
