#!/usr/bin/env python3
"""Independent C oracle for mutable binding replacement and generated-name collisions."""
import argparse
import hashlib
import json
import os
import platform
import re
import shlex
import tempfile
from fuzz import LCB
from pathlib import Path
import subprocess


def fixture():
    functions=[];decl=[];checks=[]
    for kind in ['mutable','memory']:
        for depth in [0,1,4,16]:
            for filler in [0,64,1024]:
                name=f'{kind}_{depth}_{filler}'
                prefix='lcb.ssa.' if kind=='mutable' else 'lcb.mem.'
                reserved=[prefix+'_'*i+'0' for i in range(depth)]
                code=[f'export function l ${name}(l %x,w %n) {{','@entry']
                code += [f' %{v} =l copy {i+101}' for i,v in enumerate(reserved)]
                code += [f' %filler{i} =l add %x,{i}' for i in range(filler)]
                if kind=='mutable':
                    code+=['%i =w copy 0','jmp @test','@test','%more =w cultw %i,%n','jnz %more,@body,@done','@body','%x =l add %x,7','%i =w add %i,1','jmp @test','@done']
                    value='%x'
                else:
                    code+=['%p =l alloc8 8','storel %x,%p','jmp @test','@test','%i =w phi @entry 0,@body %next','%more =w cultw %i,%n','jnz %more,@body,@done','@body','%old =l loadl %p','%updated =l add %old,7','storel %updated,%p','%next =w add %i,1','jmp @test','@done','%loaded =l loadl %p']
                    value='%loaded'
                for i,v in enumerate(reserved):code += [f'%mix{i} =l xor {value},%{v}'];value=f'%mix{i}'
                code += [f'ret {value}','}'];functions.append('\n'.join(code));decl.append(f'extern uint64_t {name}(uint64_t,uint32_t);')
                xor=0
                for i in range(depth):xor^=i+101
                checks.append(f'if({name}(x,n)!=((x+UINT64_C(7)*n)^UINT64_C({xor})))return 1;')
    caller='#include <stdint.h>\n'+'\n'.join(decl)+'''\nint main(void){
 const uint64_t xs[]={1,0,UINT64_C(0xffffffffffffffff),UINT64_C(0x8000000000000000),UINT64_C(0x123456789abcdef)};
 const unsigned ns[]={0,1,2,7,31};
 for(unsigned i=0;i<5;i++)for(unsigned j=0;j<5;j++){uint64_t x=xs[i];unsigned n=ns[j];
'''+ '\n'.join(checks)+'\n}return 0;}\n'
    return '\n'.join(functions)+'\n',caller,len(checks)*25


TARGETS = {'aarch64-macos': 'arm64_apple', 'x86_64-macos': 'amd64_apple',
           'aarch64-linux': 'arm64', 'x86_64-linux': 'amd64_sysv', 'riscv64-linux': 'rv64'}


def native_host():
    machine = {'arm64': 'aarch64', 'AMD64': 'x86_64'}.get(platform.machine(), platform.machine())
    system = {'Darwin': 'macos', 'Linux': 'linux'}.get(platform.system())
    target = f'{machine}-{system}'
    return target if target in TARGETS else None


def exercise(compiler, work, run, cc, target, execute=True, qbe=None):
    case = Path(work) / 'promotion-bindings'
    case.mkdir(parents=True, exist_ok=True)
    source, caller = case/'input.ssa', case/'caller.c'
    ir, c, count = fixture()
    source.write_text(ir); caller.write_text(c)
    def checked(command, inside=False):
        result = run(command, inside)
        assert result.returncode == 0, (command, result.stdout, result.stderr)
        return result
    report = {'target': target, 'execution': execute, 'checks_per_mode': count,
              'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'caller_sha256': hashlib.sha256(caller.read_bytes()).hexdigest(),
              'compiler_identity': checked([compiler, '--build-identity']).stdout.strip(),
              'compiler_sha256': hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
              'original_qbe': str(qbe) if qbe else None, 'modes': {},
              'negative_control': {'status': 'not-run'}}
    if qbe and Path(qbe).is_file():
        report['original_qbe_sha256'] = hashlib.sha256(Path(qbe).read_bytes()).hexdigest()
    modes = [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize'])]
    if qbe: modes.append(('original-qbe', []))
    for mode, flags in modes:
        asm, exe = case/(mode+'.s'), case/mode
        if mode == 'original-qbe':
            checked([qbe, '-t', TARGETS[target], '-o', asm, source])
        else:
            checked([compiler, source, '--target', target, *flags, '-o', asm])
        report['modes'][mode] = 'emitted'
        if not execute: continue
        checked([cc, caller, asm, '-o', exe], True)
        checked([exe], True)
        report['modes'][mode] = 'passed'
        if mode == 'optimized':
            original = asm.read_text()
            zero = ('mov x0, #0' if target.startswith('aarch64') else
                    'xor %eax, %eax' if target.startswith('x86_64') else 'li a0, 0')
            damaged, replacements = re.subn(r'(?m)^(\s*)ret\s*$',
                                            lambda m: f'{m[1]}{zero}\n\tret', original)
            assert replacements, 'no return instruction found for corruption control'
            bad, badexe = case/'corrupted.s', case/'corrupted'
            bad.write_text(damaged)
            checked([cc, caller, bad, '-o', badexe], True)
            result = run([badexe], True)
            assert result.returncode == 1, ('expected C oracle mismatch exit 1', result.returncode, result.stderr)
            report['negative_control'] = {'status': 'detected', 'exit': result.returncode,
                'mutation': zero+' before ret', 'replacements': replacements}
    (case/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'{target}: {count} independent C cases per mode; modes={report["modes"]}; corruption={report["negative_control"]["status"]}', flush=True)
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--compiler', type=Path, default=LCB)
    ap.add_argument('--qbe', type=Path, help='optional unchanged original QBE executable on the host')
    ap.add_argument('--work', type=Path, help='retain artifacts under this directory')
    ap.add_argument('--target', choices=TARGETS, default=native_host() or 'aarch64-macos')
    ap.add_argument('--cc', default=os.environ.get('LCB_CC', 'cc'), help='C compiler command, shell-style words')
    ap.add_argument('--runner', default='', help='target execution command, e.g. qemu-riscv64 -L /usr/riscv64-linux-gnu')
    ap.add_argument('--require-native', action='store_true', help='require target execution, natively or via the explicit runner')
    args = ap.parse_args()
    execute = args.target == native_host() or bool(args.runner)
    if args.require_native: assert execute, 'target execution unavailable; specify --runner for cross execution'
    cc_words, runner = shlex.split(args.cc), shlex.split(args.runner)
    assert cc_words, 'empty C compiler command'
    def run(command, inside=False):
        command = list(map(str, command))
        if inside:
            command = cc_words+command[1:] if command[0] == args.cc else runner+command
        return subprocess.run(command, capture_output=True, text=True, timeout=120)
    if args.work:
        exercise(args.compiler.resolve(), args.work.resolve(), run, args.cc, args.target, execute, args.qbe.resolve() if args.qbe else None)
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-bindings-') as directory:
            exercise(args.compiler.resolve(), Path(directory), run, args.cc, args.target, execute, args.qbe.resolve() if args.qbe else None)


if __name__ == '__main__': main()
