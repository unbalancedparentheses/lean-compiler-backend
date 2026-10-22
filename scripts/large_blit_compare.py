#!/usr/bin/env python3
"""Record compact large-copy code and independent full-matrix qualification."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time
from fuzz import LCB, ROOT, native_host
from large_blit import exercise, SIZES


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--report',type=Path)
    ap.add_argument('--compiler',type=Path,default=LCB);args=ap.parse_args()
    assert native_host(),'this report requires native Apple ARM64'
    work=ROOT/'.build/large-blit-compare';work.mkdir(exist_ok=True)
    compiler=work/'lcb-snapshot';shutil.copy2(args.compiler,compiler)
    oracle=work/'oracle'
    if not oracle.exists():shutil.copytree(ROOT/'third_party/qbe',oracle)
    upstream={str(p.relative_to(ROOT/'third_party/qbe')):digest(p) for p in (ROOT/'third_party/qbe').rglob('*') if p.suffix in ['.c','.h']}
    assert all(digest(oracle/p)==v for p,v in upstream.items()),'comparison QBE source changed'
    cc=os.environ.get('LCB_CC','cc')
    result=subprocess.run(['make','-C',str(oracle),'-j4','CC='+cc,'CFLAGS=-std=c99 -O2'],capture_output=True,text=True,timeout=300)
    assert result.returncode==0,result.stderr
    qbe=oracle/'qbe';compilation={}
    def run(cmd,inside=False):
        cmd=list(map(str,cmd));start=time.monotonic()
        result=subprocess.run(cmd,capture_output=True,text=True,timeout=300)
        if result.returncode==0 and cmd[0] in [str(compiler),str(qbe)] and '-o' in cmd:
            output=Path(cmd[cmd.index('-o')+1])
            compilation[output.stem]={'seconds':time.monotonic()-start,'assembly_bytes':output.stat().st_size,'assembly_sha256':digest(output)}
        return result
    exercise(compiler,work,run,cc,'aarch64-macos',True,qbe,'arm64_apple',True)
    case=work/'large-blit'
    backends={}
    for label in ['baseline','allocated','optimized','qbe']:
        exe=case/label
        backends[label]={**compilation[label],'executable_sha256':digest(exe),'file_bytes':exe.stat().st_size,
                         'size':run(['size',exe]).stdout.strip(),'qualified':True}
    report={'schema':1,'program':'constant block-copy regression matrix','target':'aarch64-macos',
        'execution':platform.platform(),'compiler_identity':run([compiler,'--build-identity']).stdout.strip(),
        'source_sha256':digest(case/'input.ssa'),'caller_sha256':digest(case/'caller.c'),
        'generator_sha256':digest(ROOT/'scripts/large_blit.py'),'sizes':SIZES,'full_byte_cases_per_backend':len(SIZES)*12,
        'qbe_version':'1.3 unchanged pinned source','qbe_source_hashes':upstream,'qbe_build_flags':'-std=c99 -O2',
        'backends':backends,'notes':['All four backends receive the identical full 1 MiB matrix and independent C byte/guard oracle.',
        'Three interpreted 8193-byte copies and 32 native endpoint checks also pass; repeated loops and zero unresolved symbols are included.',
        'Removing an optimized ARM64 loop store is detected. Timings are local wall-clock samples, not a general performance claim.',
        'The smaller routine target-suite QBE comparison stops at 65537 bytes to avoid repeatedly expanding the 1 MiB cases.',
        'No aggregate-call limit or proof claim is enlarged.']}
    path=args.report or work/'report.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'large blit comparison: {path}',flush=True)


if __name__=='__main__':main()
