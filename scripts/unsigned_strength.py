#!/usr/bin/env python3
"""Independent unsigned division/remainder oracles across width and power boundaries."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
from fuzz import LCB, native_host


def fixture():
    sources,declarations,checks=[],[],[]
    inputs=[0,1,7,8,(1<<31)-1,1<<31,(1<<32)-1,1<<32,(1<<63)-1,1<<63,(1<<64)-1,0xfedcba9876543210]
    for width,bits in [('w',32),('l',64)]:
        mask=(1<<bits)-1
        divisors=[1<<bit for bit in range(bits)]+[3,7,31,-1,(1<<32)+1,-(1<<(bits-1))]
        for op in ['udiv','urem']:
            for divisor in divisors:
                name=f'unsigned_strength_{len(sources)}'
                sources.append(f'export function {width} ${name}(l %x) {{ @s %r ={width} {op} %x,{divisor} ret %r }}\n')
                declarations.append(f'extern uint{bits}_t {name}(uint64_t);')
                for x in inputs:
                    a,b=x&mask,divisor&mask
                    expected=a//b if op=='udiv' else a%b
                    checks.append(f'if({name}(UINT64_C({x}))!=UINT{bits}_C({expected})){{fprintf(stderr,"case {len(checks)}\\n");return 1;}}')
    caller='#include <stdint.h>\n#include <stdio.h>\n'+'\n'.join(declarations)+'\nint main(void){\n'+'\n'.join(checks)+'\nreturn 0;\n}\n'
    return ''.join(sources),caller,len(sources),len(checks)


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'unsigned-strength';case.mkdir(exist_ok=True)
    text,c,functions,count=fixture()
    source,caller=case/'input.ssa',case/'caller.c';source.write_text(text);caller.write_text(c)
    for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(label+'.s'),case/label
        result=run([compiler,source,'--target',target,*flags,'-o',asm]);assert result.returncode==0,result.stderr
        if execute:
            result=run([cc,caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(target,label,result.returncode,result.stderr)
            if label=='optimized' and target.startswith('aarch64'):
                damaged,n=re.subn(r'(\blsr [wx]\d+, [wx]\d+, )#1\b',r'\g<1>#2',asm.read_text(),count=1)
                assert n==1,'unsigned division by two did not produce the expected shift'
                bad,badexe=case/'wrong-divisor.s',case/'wrong-divisor';bad.write_text(damaged)
                result=run([cc,caller,bad,'-o',badexe],True);assert result.returncode==0,result.stderr
                result=run([badexe],True);assert result.returncode!=0,'wrong unsigned divisor escaped the independent oracle'
    print(f'{target}: unsigned division/remainder: {functions} functions, {count} independent cases per mode, all powers and truncation/nonpower boundaries; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-unsigned-strength-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())


if __name__=='__main__':main()
