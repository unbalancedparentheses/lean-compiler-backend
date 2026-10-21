#!/usr/bin/env python3
"""Independent arithmetic oracle for baseline and opt-in folded target output."""
import argparse
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
from fuzz import ROOT,LCB,native_host


def fixture():
    rng=random.Random(20261021);source=[];checks=[];declarations=[]
    for i in range(64):
        w='w' if i%2 else 'l';bits=32 if w=='w' else 64;mask=(1<<bits)-1
        a,b,c=[rng.getrandbits(bits) for _ in range(3)]
        shift=rng.randrange(0,128)
        value=(((a+b)&mask)*c)&mask
        value=(value << (shift%bits))&mask
        value^=a
        body=f'export function l $fold_{i}(l %x) {{\n@s\n %a ={w} add {a}, {b}\n %b ={w} mul %a, {c}\n %c ={w} shl %b, {shift}\n %d ={w} xor %c, {a}\n'
        if w=='w':body+=' %wide =l extuw %d\n'
        body+=f' %r =l xor {"%wide" if w=="w" else "%d"}, %x\n ret %r\n}}\n';source.append(body)
        declarations.append(f'extern uint64_t fold_{i}(uint64_t);')
        for x in [0,1,(1<<64)-1,rng.getrandbits(64)]:
            checks.append(f'if(fold_{i}(UINT64_C({x}))!=UINT64_C({value^x}))return 1;')
    return ''.join(source),'#include <stdint.h>\n'+'\n'.join(declarations)+'\nint main(void){\n'+'\n'.join(checks)+'\nreturn 0;}\n'


def exercise(compiler,work,run,cc,target,execute=True):
    case=Path(work)/'constant-fold';case.mkdir(exist_ok=True)
    source,caller=case/'input.ssa',case/'caller.c';text,c=fixture();source.write_text(text);caller.write_text(c)
    for optimized in [False,True]:
        label='folded' if optimized else 'baseline';assembly=case/(label+'.s')
        result=run([compiler,source,'--target',target,*(['--optimize'] if optimized else []),'-o',assembly]);assert result.returncode==0,result.stderr
        if execute:
            result=run([cc,caller,assembly,'-o',case/label],True);assert result.returncode==0,result.stderr
            result=run([case/label],True);assert result.returncode==0,(label,result.returncode,result.stderr)
    assert (case/'folded.s').read_text().count('mul') < (case/'baseline.s').read_text().count('mul'),'folded multiplication was retained'
    print(f'{target}: baseline/folded assembly and 256 independent integer-oracle cases; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-fold-') as directory:
        exercise(LCB,Path(directory),run,os.environ.get('LCB_CC','cc'),'aarch64-macos',native_host())

if __name__=='__main__':main()
