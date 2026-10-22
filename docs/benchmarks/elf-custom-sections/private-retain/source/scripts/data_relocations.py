#!/usr/bin/env python3
"""Width-aware relocation grammar/layout and independently checked native addresses.

Native linking is a separate qualification: absolute narrow relocations may be
unsupported or overflow, and default PIE and explicit non-PIE are never merged.
"""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import shlex
import subprocess
from fuzz import LCB

KINDS = {'b': (1, 'loadub'), 'h': (2, 'loaduh'), 'w': (4, 'loaduw'),
         's': (4, 'loaduw'), 'l': (8, 'loadl'), 'd': (8, 'loadl')}
QBE_TARGET = {'aarch64-macos': 'arm64_apple', 'x86_64-macos': 'amd64_apple',
              'aarch64-linux': 'arm64', 'x86_64-linux': 'amd64_sysv', 'riscv64-linux': 'rv64'}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def interpreter_source():
    lines = ['data $target = { z 32 }']
    checks = []
    for kind, (width, load) in KINDS.items():
        for label, addend in [('positive', 8), ('negative', -8), ('wrap', -65537)]:
            name = f'{kind}_{label}'
            lines.append(f'data ${name} = {{ b 93, {kind} $target + {addend}, b 167 }}')
            mask = (1 << (width * 8)) - 1
            lines.append(f'''export function w ${name}_check() {{
@start
 %p =l add ${name}, 1
 %got =l {load} %p
 %sum =l add $target, {addend}
 %want =l and %sum, {mask}
 %ok =w ceql %got, %want
 %tail =l add ${name}, {width + 1}
 %last =w loadub %tail
 %lastok =w ceqw %last, 167
 %first =w loadub ${name}
 %firstok =w ceqw %first, 93
 %both =w and %ok, %lastok
 %all =w and %both, %firstok
 ret %all
}}''')
            checks.append(name + '_check')
    return '\n'.join(lines) + '\n', checks

def native_source(kind):
    return f'''export data $value = {{ z 32 }}
data $local = {{ z 32 }}
export data $"quoted.value" = {{ z 32 }}
export data $packed = align 8 {{ b 93, z 7, {kind} $value + 8 $local + -8 $external + 8 $"quoted.value" + 8 $function, b 167 }}
export function l $local_address() {{
@start
 ret $local
}}
export function l $quoted_address() {{
@start
 ret $"quoted.value"
}}
export function l $function() {{
@start
 ret 42
}}
'''

CALLER = '''#include <stdint.h>
#include <stdio.h>
unsigned char external[32];
extern unsigned char value[], packed[];
extern uintptr_t local_address(void), quoted_address(void), function(void);
int main(void) {
 uintptr_t expected[] = {(uintptr_t)value+8, local_address()-8,
   (uintptr_t)external+8, quoted_address()+8, (uintptr_t)function};
 if (packed[0] != 93 || packed[8+5*WIDTH] != 167) return 1;
 for (unsigned i=0;i<5;i++) for(unsigned j=0;j<WIDTH;j++)
   if (packed[8+i*WIDTH+j] != ((expected[i] >> (8*j)) & 255)) return 2;
 puts("relocation bytes passed"); return 0;
}
'''

def exercise(compiler, work, run, cc, target, execute=True, qbe=None):
    """run(command, inside=False) returns a CompletedProcess; never hides failures."""
    work = Path(work); work.mkdir(parents=True, exist_ok=True)
    source = work/'interpreter.ssa'; text, checks = interpreter_source(); source.write_text(text)
    records = []
    def invoke(command, inside=False):
        p = run([str(x) for x in command], inside=inside)
        row = {'command': [str(x) for x in command], 'inside': inside,
               'returncode': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}
        records.append(row)
        return p
    assert invoke([compiler, '--check', source]).returncode == 0
    for name in checks:
        p = invoke([compiler, '--eval', source, name]); assert p.returncode == 0 and p.stdout.strip() == '1', records[-1]
    results = []
    controls = []
    for kind, (width, _) in KINDS.items():
        ir = work/f'{kind}.ssa'; ir.write_text(native_source(kind))
        caller = work/f'{kind}.c'; caller.write_text(f'#define WIDTH {width}\n' + CALLER)
        for backend, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize'])] + ([('original-qbe', None)] if qbe else []):
            asm = work/f'{kind}-{backend}.s'
            command = [qbe, '-t', QBE_TARGET[target], '-o', asm, ir] if flags is None else [compiler, '--target', target, *flags, ir, '-o', asm]
            p = invoke(command); assert p.returncode == 0, records[-1]
            directive = {1: '.byte', 2: '.short', 4: '.long', 8: '.quad'}[width]
            if flags is not None:
                if target.endswith('linux'):
                    assert f'.size packed, {9 + 5*width}' in asm.read_text()
                assert sum(directive + ' ' in line and ('value' in line or 'local' in line or 'external' in line or 'function' in line) for line in asm.read_text().splitlines()) == 5
            if not execute: continue
            for profile, linkflags in [('default', []), ('explicit-no-pie', ['-Wl,-no_pie'] if target.endswith('macos') else ['-no-pie'])]:
                exe = work/f'{kind}-{backend}-{profile}'
                linked = invoke([*cc, '-std=c11', '-O2', caller, asm, *linkflags, '-o', exe], True)
                row = {'kind': kind, 'width': width, 'backend': backend, 'profile': profile,
                       'ir_sha256': sha(ir), 'assembly_sha256': sha(asm), 'link': records[-1], 'qualified': False}
                if linked.returncode == 0:
                    executed = invoke([exe], True); row['execution'] = records[-1]
                    assert executed.returncode == 0 and executed.stdout.strip() == 'relocation bytes passed', row
                    row['qualified'] = True
                    if kind == 'l' and backend == 'baseline' and profile == 'default':
                        mutant = work/'corrupt.s'
                        content = asm.read_text(); changed = content.replace('value+8', 'value+9', 1)
                        assert changed != content; mutant.write_text(changed)
                        badexe = work/'corrupt'
                        assert invoke([*cc, caller, mutant, '-o', badexe], True).returncode == 0
                        assert invoke([badexe], True).returncode != 0
                        controls.append(records[-1])
                # All three Linux toolchains must execute word/long explicit non-PIE.
                if ((target.endswith('linux') and width >= 4 and profile == 'explicit-no-pie') or
                    (width == 8 and (backend != 'original-qbe' or target != 'riscv64-linux' or profile == 'explicit-no-pie'))):
                    assert row['qualified'], row
                results.append(row)
    report = {'target': target, 'compiler_sha256': sha(compiler),
              'compiler_identity': invoke([compiler, '--build-identity']).stdout.strip(),
              'qbe_sha256': sha(qbe) if qbe else None, 'interpreter_checks': len(checks),
              'interpreter_source_sha256': sha(source), 'caller_sha256': hashlib.sha256(CALLER.encode()).hexdigest(),
              'results': results, 'commands': records, 'corruption_controls': controls,
              'note': 'Unchanged original QBE; default and explicit non-PIE link qualifications are separate. Link failures are retained and are not executable passes.'}
    (work/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'{target}: {len(checks)} interpreter relocation checks; {sum(row["qualified"] for row in results)}/{len(results)} link/execution profiles qualified; failures retained separately',flush=True)
    return report

def native_host():
    isa={'arm64':'aarch64','aarch64':'aarch64','amd64':'x86_64','x86_64':'x86_64','riscv64':'riscv64'}.get(platform.machine().lower())
    system={'Darwin':'macos','Linux':'linux'}.get(platform.system())
    target=f'{isa}-{system}'
    return target if target in QBE_TARGET else None


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler', type=Path, default=LCB); p.add_argument('--work', type=Path, default=Path('.build/data-relocations'))
    p.add_argument('--target', choices=QBE_TARGET, default=native_host() or 'aarch64-macos')
    p.add_argument('--cc', default=os.environ.get('LCB_CC', os.environ.get('CC', 'cc'))); p.add_argument('--runner', default='')
    p.add_argument('--qbe', type=Path); p.add_argument('--require-native', action='store_true')
    p.add_argument('--no-execute', action='store_true'); a=p.parse_args()
    execute=not a.no_execute and (a.target==native_host() or bool(a.runner))
    if a.require_native: assert execute, "target execution unavailable; supply --runner"
    cc=shlex.split(a.cc); runner=shlex.split(a.runner)
    def run(cmd, inside=False):
        if inside and len(cmd)==1: cmd=runner+cmd
        return subprocess.run(cmd, text=True, capture_output=True, timeout=120)
    report=exercise(a.compiler.resolve(), a.work.resolve(), run, cc, a.target, execute, a.qbe.resolve() if a.qbe else None)
    print(json.dumps({'interpreter_checks': report['interpreter_checks'], 'qualified': sum(r['qualified'] for r in report['results']), 'attempts': len(report['results'])}))
if __name__ == '__main__': main()
