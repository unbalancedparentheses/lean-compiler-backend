#!/usr/bin/env python3
"""AMD64 trailing variadic markers: independent AL probes, including void calls."""
import argparse
import os
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB
from unused_environment import native_target
import hashlib
import json
from pathlib import Path


def exercise(compiler, work, run, cc, target, execute=True, qbe=None, qtarget=None):
    assert target in ['x86_64-linux', 'x86_64-macos']
    case = Path(work)/'empty-variadic-calls'
    case.mkdir(parents=True, exist_ok=True)
    source, caller, probe = [case/name for name in ['input.ssa', 'caller.c', 'probe.s']]
    ir, c = [], ['#include <stdint.h>\nuint64_t seen;\nextern uint64_t probe(void);\nextern void probe_void(void);\n']
    checks = []
    for fp in [-1, 0, 1, 8, 9]:
        args = ','.join(([] if fp == -1 else ['l 123'])+[f'd d_{i+1.5}' for i in range(fp)]+['...'])
        for indirect in [False, True]:
            for void in [False, True]:
                name = f'call_{fp+1}_{int(indirect)}_{int(void)}'
                fn = 'probe_void' if void else 'probe'
                ir.append(f'export function l ${name}(l %fn) {{\n@s\n')
                call = f'call '+('%fn' if indirect else '$'+fn)+f'({args})\n'
                ir.append(' '+call+' ret 0\n}\n' if void else ' %r =l '+call+' ret %r\n}\n')
                c.append(f'extern uint64_t {name}(uintptr_t);\n')
                checks.append(f'seen=99; uint64_t r_{name}={name}((uintptr_t){fn}); if('+('seen' if void else f'r_{name}')+f'!={max(0,min(fp,8))}) return 1;\n')
    source.write_text(''.join(ir))
    caller.write_text(''.join(c)+'int main(void){\n'+''.join(checks)+'return 0;}\n')
    prefix = '_' if target.endswith('macos') else ''
    probe.write_text(f'.text\n.globl {prefix}probe\n{prefix}probe:\n movzbl %al,%eax\n ret\n.globl {prefix}probe_void\n{prefix}probe_void:\n movzbl %al,%eax\n movq %rax,{prefix}seen(%rip)\n ret\n')
    modes = {}
    for mode, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize']), ('qbe', None)]:
        if mode == 'qbe' and not(qbe and execute): continue
        asm, exe = case/(mode+'.s'), case/mode
        r = run([qbe,'-t',qtarget,'-o',asm,source] if mode == 'qbe' else [compiler,'--target',target,*flags,source,'-o',asm], mode == 'qbe')
        assert r.returncode == 0, (mode,r.stderr)
        modes[mode] = 'emitted'
        if execute:
            r = run([cc,caller,probe,asm,'-o',exe],True); assert r.returncode == 0,r.stderr
            r = run([exe],True); assert r.returncode == 0,(mode,r.returncode,r.stderr)
            modes[mode] = 'passed'
    # A zero-anonymous marker still conflicts with AMD64's environment register.
    rejected = 0
    for indirect in [False,True]:
        for void in [False,True]:
            bad = case/f'env-{indirect}-{void}.ssa'
            bad.write_text('export function l $bad(l %fn) {\n@s\n '+('' if void else '%r =l ')+ 'call '+('%fn' if indirect else '$external')+'(env 123,l 1,...)\n ret 0\n}\n')
            for flags in [[],['--allocate'],['--optimize']]:
                r=run([compiler,'--target',target,*flags,bad,'-o',case/'bad.s'])
                assert r.returncode != 0 and 'variadic environment calls' in r.stderr,r.stderr
                rejected += 1
            if qbe and execute:
                r=run([qbe,'-t',qtarget,'-o',case/'bad-qbe.s',bad],True)
                assert r.returncode != 0 and 'variadic env calls' in r.stderr,r.stderr
    if execute:
        # Independent negative control: lose precisely the metadata under test.
        mutant=case/'mutant.ssa'; mutant.write_text(source.read_text().replace(',...)',')'))
        asm,exe=case/'mutant.s',case/'mutant'
        r=run([compiler,'--target',target,mutant,'-o',asm]); assert r.returncode==0,r.stderr
        r=run([cc,caller,probe,asm,'-o',exe],True); assert r.returncode==0,r.stderr
        r=run([exe],True); assert r.returncode==1,'lost marker escaped independent AL probe'
    report={'target':target,'modes':modes,'calls_per_mode':20 if execute else 0,'negative_lcb_cases':rejected,'marker_loss_detected':execute,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: empty variadic markers: {report}',flush=True)
    return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    target=native_target();execute=target in ['x86_64-linux','x86_64-macos']
    if args.require_native:assert execute,'AMD64 native target required'
    target=target if execute else 'x86_64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-unused-env-var-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,target,execute,qbe,'amd64_apple' if target.endswith('macos') else 'amd64_sysv')


if __name__=='__main__':main()
