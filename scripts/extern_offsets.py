#!/usr/bin/env python3
"""Retain the pinned QBE ARM64 ELF external-GOT-addend discrepancy."""
from pathlib import Path
import shutil
from fuzz import ROOT


def exercise(compiler, work, run, cc, qbe, execute=True):
    case = Path(work)/'extern-offset'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    shutil.copy2(ROOT/'tests/regressions/qbe-arm64-extern-offset.ssa', source)
    shutil.copy2(ROOT/'tests/regressions/qbe-arm64-extern-offset.c', caller)
    for label in ['baseline', 'optimized', 'qbe']:
        if label == 'qbe' and not execute: continue
        asm, exe = case/(label+'.s'), case/label
        cmd = ([qbe, '-t', 'arm64', '-o', asm, source] if label == 'qbe' else
               [compiler, source, '--target', 'aarch64-linux', *(['--optimize'] if label == 'optimized' else []), '-o', asm])
        result = run(cmd, label == 'qbe')
        assert result.returncode == 0, result.stderr
        if execute:
            result = run([cc, caller, asm, '-o', exe], True)
            assert result.returncode == 0, result.stderr
            result = run([exe], True)
            assert result.returncode == (1 if label == 'qbe' else 0), (label, result.returncode, 're-audit pinned GOT offset discrepancy')
    print(f'Linux ARM64: external symbol +32 matches C in baseline/optimized; original QBE wrong-pointer control retained; execution={execute}', flush=True)
