#!/usr/bin/env python3
"""QBE-style command-line protocol, stdin pipelines and multi-input linking."""
import argparse
import os
from pathlib import Path
import platform
import subprocess
import tempfile
from fuzz import LCB

ALIASES = {'arm64_apple':'aarch64-macos','arm64':'aarch64-linux','amd64_sysv':'x86_64-linux',
           'amd64_apple':'x86_64-macos','rv64':'riscv64-linux'}
SOURCE = '# Unicode pipeline comment: λπ\nexport data $value = { l 40 } export function l $get_value() { @s %x =l loadl $value ret %x }\n'
SECOND = 'export function l $combined() { @s %x =l call $get_value() %r =l add %x,2 ret %r }\n'


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    def run(cmd,**kwargs):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120,**kwargs)
    def compile(*args,input=None):
        result=run([LCB,*args],input=input);assert result.returncode==0,(args,result.stderr)
        return result.stdout
    with tempfile.TemporaryDirectory(prefix='lcb-cli-') as directory:
        work=Path(directory);first,second=work/'first.ssa',work/'second.ssa'
        first.write_text(SOURCE);second.write_text(SECOND)
        cases=0
        for alias,target in ALIASES.items():
            for flags in [[],['--allocate'],['--optimize']]:
                expected=compile(first,'--target',target,*flags)
                variants=[['-t',alias,*flags,str(first)],
                          [*flags,'-t'+alias,str(first)],
                          ['-o','-','-t',alias,*flags,str(first)],
                          [str(first),*flags,'-t',alias],
                          ['--target',alias,*flags,'-'],
                          ['-t',alias,*flags]]
                for options in variants:
                    assert compile(*options,input=SOURCE)==expected,(alias,options);cases+=1
                output=work/'result with spaces.s'
                assert compile('-t',alias,'-o'+str(output),*flags,first)==''
                assert output.read_text()==expected;cases+=1
                expected+=compile(second,'--target',target,*flags)
                assert compile('-t',alias,*flags,first,second)==expected;cases+=1
                assert compile('-t',alias,*flags,first,'-',input=SECOND)==expected;cases+=1
        # '--' makes leading-dash filenames literal, not options.
        unusual=work/'--optimize';unusual.write_text(SOURCE)
        result=run([LCB,'-t','arm64_apple','--','--optimize'],cwd=work)
        assert result.returncode==0 and result.stdout==compile(first),result.stderr
        assert compile(input=SOURCE)==compile(first)
        assert compile('--check','-',input=SOURCE)==compile('--check',first)
        assert compile('--eval','-','get_value',input=SOURCE).strip()=='40'
        assert 'Usage:' in compile('-h') and 'Usage:' in compile('--help')
        for options,diagnostic in [(['-t'],'incomplete option'),(['-o'],'incomplete option'),
                                  (['-t','amd64_win'],'unsupported target'),
                                  (['-t','rv64','--target','riscv64-linux'],'target specified more than once'),
                                  (['-o','one','-o','two'],'output specified more than once'),
                                  (['-d','A'],'unknown or incomplete option')]:
            result=run([LCB,*options],input=SOURCE);assert result.returncode and diagnostic in result.stderr,(options,result.stderr)
        result=run([LCB,'-t','arm64'],input=' '*(8*1024*1024+1));assert result.returncode and '8 MiB' in result.stderr,result.stderr
        # A failed later input must not truncate an existing output artifact.
        bad=work/'bad.ssa';bad.write_text('not valid IL')
        output=work/'preserved.s';output.write_text('sentinel')
        result=run([LCB,'-t','arm64',first,bad,'-o',output]);assert result.returncode and output.read_text()=='sentinel'
        system,machine=platform.system(),platform.machine().lower()
        target=({'arm64':'arm64_apple','aarch64':'arm64_apple','x86_64':'amd64_apple'}.get(machine) if system=='Darwin' else
                {'arm64':'arm64','aarch64':'arm64','x86_64':'amd64_sysv','amd64':'amd64_sysv','riscv64':'rv64'}.get(machine) if system=='Linux' else None)
        if args.require_native:assert target,'no native target available'
        if target:
            asm=work/'combined.s';compile('-t',target,'--optimize','-o',asm,first,second)
            c=work/'caller.c';c.write_text('#include <stdint.h>\nextern uint64_t value,combined(void);int main(void){return value!=40||combined()!=42;}\n')
            exe=work/'combined';result=run([os.environ.get('LCB_CC','cc'),c,asm,'-o',exe]);assert result.returncode==0,result.stderr
            result=run([exe]);assert result.returncode==0,result.stderr
        print(f'CLI: {cases} target/option/stdin/multi-input equivalences, interpreter stdin, refusal/artifact controls; native multi-module execution={bool(target)}',flush=True)


if __name__=='__main__':main()
