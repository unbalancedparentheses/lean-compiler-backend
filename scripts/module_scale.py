#!/usr/bin/env python3
"""Exercise the 4096-function boundary and forward calls across a large module."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host


def exercise(compiler, work, run, cc, target, execute=True):
    case = Path(work)/'module-scale'
    case.mkdir(exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    functions = []
    for i in range(4096):
        body = f'%v =l call $scale_{i+1}()\n %r =l add %v, 1\n ret %r' if i < 4095 else 'ret 1'
        functions.append(f'export function l $scale_{i}() {{\n@s\n {body}\n}}\n')
    text = ''.join(functions)
    source.write_text(text)
    caller.write_text('#include <stdint.h>\nextern uint64_t scale_0(void),scale_4095(void);\nint main(void){return scale_0()!=4096 || scale_4095()!=1;}\n')
    assembly = case/'lean.s'
    result = run([compiler, source, '--target', target, '-o', assembly])
    assert result.returncode == 0, result.stderr
    if execute:
        result = run([cc, caller, assembly, '-o', case/'driver'], True)
        assert result.returncode == 0, result.stderr
        result = run([case/'driver'], True)
        assert result.returncode == 0, (result.returncode, result.stderr)
    for label, bad, diagnostic in [
        ('overflow', text+'function l $extra() { @s ret 0 }', '4096-function'),
        ('duplicate', text.replace('$scale_4095() {', '$scale_0() {'), 'duplicate function'),
        ('signature', text.replace('$scale_4095() {', '$scale_4095(l %unused) {'), 'argument count'),
    ]:
        invalid = case/(label+'.ssa')
        invalid.write_text(bad)
        result = run([compiler, '--check', invalid])
        assert result.returncode != 0 and diagnostic in result.stderr, (label, result.stderr)
    print(f'{target}: 4096-function forward-call chain, boundary/duplicate/signature diagnostics; execution={execute}', flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true')
    args = ap.parse_args()
    if args.require_native:
        assert native_host()
    def run(cmd, inside=False):
        return subprocess.run(list(map(str, cmd)), text=True, capture_output=True, timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-modules-') as directory:
        exercise(LCB, Path(directory), run, os.environ.get('LCB_CC', 'cc'), 'aarch64-macos', native_host())


if __name__ == '__main__':
    main()
