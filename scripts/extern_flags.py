#!/usr/bin/env python3
"""Retain QBE AMD64 external-address materialization clobbering CMP/CMOV flags."""
from pathlib import Path
import shutil
from fuzz import ROOT


def exercise(compiler, work, run, cc, qbe, target, qtarget, execute=True):
    case = Path(work)/'extern-flags'
    case.mkdir(parents=True, exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    shutil.copy2(ROOT/'tests/regressions/qbe-amd64-extern-flags.ssa', source)
    shutil.copy2(ROOT/'tests/regressions/qbe-amd64-extern-flags.c', caller)
    for label, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize']), ('qbe', [])]:
        if label == 'qbe' and not execute: continue
        assembly, executable = case/(label+'.s'), case/label
        command = ([qbe, '-t', qtarget, '-o', assembly, source] if label == 'qbe' else
                   [compiler, source, '--target', target, *flags, '-o', assembly])
        result = run(command, label == 'qbe')
        assert result.returncode == 0, result.stderr
        if execute:
            result = run([cc, caller, assembly, '-o', executable], True)
            assert result.returncode == 0, result.stderr
            result = run([executable], True)
            assert result.returncode == (1 if label == 'qbe' else 0), (target,label,result.returncode,result.stderr)
    print(f'{target}: conditional external +140 pointer matches independent C in all lowering modes; original QBE flags discrepancy retained; execution={execute}', flush=True)
