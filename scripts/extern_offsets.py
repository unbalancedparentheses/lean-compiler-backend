#!/usr/bin/env python3
"""Retain pinned QBE external-GOT-addend discrepancies and C pointer checks."""
from pathlib import Path
import shutil
from fuzz import ROOT


def exercise(compiler, work, run, cc, qbe, execute=True, target="aarch64-linux"):
    qtarget = {"aarch64-linux":"arm64", "x86_64-linux":"amd64_sysv", "riscv64-linux":"rv64"}[target]
    case = Path(work)/'extern-offset'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    shutil.copy2(ROOT/'tests/regressions/qbe-arm64-extern-offset.ssa', source)
    shutil.copy2(ROOT/'tests/regressions/qbe-arm64-extern-offset.c', caller)
    for label in ['baseline', 'optimized', 'qbe']:
        if label == 'qbe' and not execute: continue
        asm, exe = case/(label+'.s'), case/label
        cmd = ([qbe, '-t', qtarget, '-o', asm, source] if label == 'qbe' else
               [compiler, source, '--target', target, *(['--optimize'] if label == 'optimized' else []), '-o', asm])
        result = run(cmd, label == 'qbe')
        assert result.returncode == 0, result.stderr
        if execute:
            result = run([cc, caller, asm, '-o', exe], True)
            if target == 'riscv64-linux' and label == 'qbe':
                assert result.returncode and "addend isn't allowed for R_RISCV_GOT_HI20" in result.stderr, result.stderr
                continue
            assert result.returncode == 0, result.stderr
            result = run([exe], True)
            assert result.returncode == (1 if target == 'aarch64-linux' and label == 'qbe' else 0), (label, result.returncode, 're-audit pinned GOT offset discrepancy')
    print(f'{target}: external symbol +32 matches C in baseline/optimized; original QBE '+('matches C' if target == 'x86_64-linux' else 'discrepancy retained')+f'; execution={execute}', flush=True)
