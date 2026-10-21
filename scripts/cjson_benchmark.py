#!/usr/bin/env python3
"""Pinned real-world cJSON comparison: identical cproc IR through LCB and QBE.

Requires a running ARM64 Linux container with .build/linux-arm64 mounted at
/work, plus gcc/make in the container and a host C compiler for pinned QBE.
Sources are fetched at fixed commits into ignored build storage, never patched.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
CPROC = 'd1c53ddf56571573a7025324c8dd5c6d547a4d1f'
CJSON = 'c859b25da02955fef659d658b8f324b5cde87be3'  # v1.7.19
TESTS = 'parse_examples parse_number parse_hex4 parse_string parse_array parse_object parse_value print_string print_number print_array print_object print_value misc_tests parse_with_opts compare_tests cjson_add readme_examples minify_tests'.split()
DEFINES = ['-D__DBL_EPSILON__=2.2204460492503131e-16', '-DUNITY_LONG_WIDTH=64', '-DUNITY_POINTER_WIDTH=64', '-DUNITY_INT_WIDTH=32']

BENCH = r'''
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cJSON.h"
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec*1e-9; }
int main(int argc,char **argv) {
 unsigned iterations=argc>1?strtoul(argv[1],0,10):1000;
 char input[65536]; size_t n=0;
 n+=snprintf(input+n,sizeof(input)-n,"{\"title\":\"compiler benchmark\",\"items\":[");
 for(unsigned i=0;i<200;i++) n+=snprintf(input+n,sizeof(input)-n,
  "%s{\"id\":%u,\"name\":\"item-%u\\n\\u03bb\",\"score\":%.6f,\"active\":%s,\"extra\":null}",
  i?",":"",i,i,(i*37-1700.0)/13.0,i%2?"true":"false");
 n+=snprintf(input+n,sizeof(input)-n,"]}");
 uint64_t hash=UINT64_C(1469598103934665603); size_t bytes=0;
 double start=now();
 for(unsigned k=0;k<iterations;k++) {
  cJSON *root=cJSON_Parse(input); if(!root)return 1;
  cJSON *items=cJSON_GetObjectItemCaseSensitive(root,"items");
  if(cJSON_GetArraySize(items)!=200)return 2;
  cJSON *last=cJSON_GetArrayItem(items,199);
  if(cJSON_GetObjectItemCaseSensitive(last,"id")->valueint!=199)return 3;
  char *printed=cJSON_PrintUnformatted(root); if(!printed)return 4;
  for(const unsigned char *p=(const unsigned char*)printed;*p;p++) { hash^=*p;hash*=UINT64_C(1099511628211);bytes++; }
  cJSON_free(printed);cJSON_Delete(root);
 }
 double elapsed=now()-start;
 printf("{\"iterations\":%u,\"input_bytes\":%zu,\"output_bytes\":%zu,\"checksum\":\"%016llx\",\"seconds\":%.9f}\n",iterations,n,bytes,(unsigned long long)hash,elapsed);
 return 0;
}
'''


def command(args, cwd=None, timeout=300, check=True):
    result = subprocess.run(list(map(str,args)), cwd=cwd, text=True, capture_output=True, timeout=timeout)
    if result.returncode and check:
        raise RuntimeError(f'{args}: exit {result.returncode}\n{result.stdout}\n{result.stderr}')
    return result


def fetch(path, url, commit):
    if not (path/'.git').exists():
        path.mkdir(parents=True,exist_ok=True)
        command(['git','init',path])
        command(['git','-C',path,'remote','add','origin',url])
        command(['git','-C',path,'fetch','--depth','1','origin',commit])
        command(['git','-C',path,'checkout','--detach',commit])
    assert command(['git','-C',path,'rev-parse','HEAD']).stdout.strip()==commit
    assert not command(['git','-C',path,'diff','--name-only','HEAD']).stdout.strip(), 'upstream source modified'


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container',default='lcb-parity-linux')
    ap.add_argument('--iterations',type=int,default=1000)
    ap.add_argument('--repetitions',type=int,default=5)
    ap.add_argument('--skip-tests',action='store_true')
    ap.add_argument('--report',type=Path)
    args=ap.parse_args()
    assert args.iterations>0 and args.repetitions>0
    work=ROOT/'.build/linux-arm64/cjson-benchmark'
    work.mkdir(parents=True,exist_ok=True)
    def inside(path): return '/work/'+str(Path(path).relative_to(ROOT/'.build/linux-arm64'))
    def docker(cmd,cwd=None,check=True):
        return command(['docker','exec',*(['-w',inside(cwd)] if cwd else []),args.docker_container,*cmd],check=check)
    assert docker(['uname','-m']).stdout.strip()=='aarch64', 'native ARM64 VM required'
    cproc,cjson=work/'cproc',work/'cJSON'
    fetch(cproc,'https://github.com/michaelforney/cproc.git',CPROC)
    fetch(cjson,'https://github.com/DaveGamble/cJSON.git',CJSON)
    docker(['./configure'],cproc)
    docker(['make','-j4'],cproc)
    qbesrc=work/'qbe-host'
    if not qbesrc.exists():shutil.copytree(ROOT/'third_party/qbe',qbesrc)
    command(['make','clean'],cwd=qbesrc)
    command(['make','-j4',f'CC={os.environ.get("LCB_CC","cc")}', 'CFLAGS=-std=c99 -O2'],cwd=qbesrc)
    def synchronize(path, to_guest=True):
        # Docker Desktop's shared filesystem can briefly expose an older or
        # partial host write. Check bytes before a consumer crosses the boundary.
        expected = hashlib.sha256(path.read_bytes()).hexdigest() if to_guest else docker(['sha256sum',inside(path)]).stdout.split()[0]
        if to_guest:
            with path.open('rb') as stream: os.fsync(stream.fileno())
        for _ in range(100):
            actual = docker(['sha256sum',inside(path)]).stdout.split()[0] if to_guest else hashlib.sha256(path.read_bytes()).hexdigest()
            if actual == expected: return
            time.sleep(0.05)
        raise AssertionError(f'shared-file digest did not synchronize: {path}')
    compiler=work/'lcb-snapshot'
    shutil.copy2(ROOT/'.lake/build/bin/lcb',compiler)
    def frontend(source,ir):
        docker([inside(cproc/'cproc'),*DEFINES,'-emit-qbe',inside(source),'-o',inside(ir)])
        synchronize(ir,False)
    def compile_ir(ir,label,out):
        cmd=([qbesrc/'qbe','-t','arm64','-o',out,ir] if label=='qbe' else
             [compiler,ir,'--target','aarch64-linux',*(['--optimize'] if label=='optimized' else []),'-o',out])
        start=time.perf_counter();command(cmd);elapsed=time.perf_counter()-start
        synchronize(out)
        return elapsed
    ir=work/'cJSON.ssa'
    frontend(cjson/'cJSON.c',ir)
    text=ir.read_text()
    report={'schema':1,'program':'cJSON 1.7.19','cjson_commit':CJSON,'cproc_commit':CPROC,
      'frontend_defines':DEFINES,'qbe_version':'1.3 (repository pinned source)', 'qbe_build_flags':'-std=c99 -O2',
      'compiler_identity':command([compiler,'--build-identity']).stdout.strip(),
      'compile_host':platform.platform(),'execution':docker(['uname','-a']).stdout.strip(),
      'target':'aarch64-linux','ir_sha256':hashlib.sha256(ir.read_bytes()).hexdigest(),
      'ir_bytes':ir.stat().st_size,'ir_lines':len(text.splitlines()),
      'ir_functions':len(re.findall(r'^(?:export )?function\b',text,re.M)),
      'compile_seconds':{},'objects':{},'tests':{},'runtime':{},'default_stack_failures':[],
      'default_stack_kib':int(docker(['sh','-c','ulimit -s']).stdout),
      'notes':['Both backends compile identical IR on the same host; frontend/assembler/linker time excluded.',
               'Runtime timing occurs inside the native ARM64 Linux VM, excluding docker launch overhead.',
               'Unity test support and benchmark driver use GCC; each test translation unit includes cJSON.c and goes through the compared backend.',
               'GCC -O2 is an additional C-source correctness reference, not an identical-IR backend.',
               'Defines supply cproc/GCC-header interoperability constants; upstream source and emitted IR are unchanged.']}
    objects={}
    for label in ['baseline','optimized','qbe']:
        out=work/f'cJSON-{label}.s'
        times=[compile_ir(ir,label,out) for _ in range(args.repetitions)]
        report['compile_seconds'][label]={'samples':times,'median':statistics.median(times)}
        obj=work/f'cJSON-{label}.o'
        docker(['gcc','-c',inside(out),'-o',inside(obj)])
        objects[label]=obj
        report['objects'][label]={'file_bytes':obj.stat().st_size,'size':docker(['size',inside(obj)]).stdout.strip(),'assembly_lines':len(out.read_text().splitlines())}
        print(f'cJSON {label}: compiled {report["ir_functions"]} functions / {report["ir_lines"]} IR lines; median {statistics.median(times):.4f}s',flush=True)
    if not args.skip_tests:
        unity=work/'unity.o'
        docker(['gcc','-O2','-c',inside(cjson/'tests/unity/src/unity.c'),'-o',inside(unity)])
        for test in TESTS:
            source=cjson/'tests'/f'{test}.c'
            test_ir=work/f'{test}.ssa'
            frontend(source,test_ir)
            row={}
            for label in ['baseline','optimized','qbe','gcc']:
                asm=work/f'{test}-{label}.s';exe=work/f'{test}-{label}'
                if label=='gcc': build=['gcc','-O2',inside(source)]
                else:
                    compile_ir(test_ir,label,asm)
                    build=['gcc',inside(asm)]
                docker([*build,inside(unity),'-lm','-o',inside(exe)])
                result=docker([inside(exe)],cjson/'tests',check=False)
                if result.returncode:
                    report['default_stack_failures'].append({'test':test,'backend':label,'exit':result.returncode})
                    # Preserve the default-limit failure; retry with the same
                    # explicit 64 MiB budget to distinguish stack use from wrong results.
                    import shlex
                    result=docker(['sh','-c','ulimit -s 65536; exec '+shlex.quote(inside(exe))],cjson/'tests')
                    print(f'cJSON {test}/{label}: default stack failed; 64 MiB retry passed',flush=True)
                (work/f'{test}-{label}.log').write_text(result.stdout+result.stderr)
                found=re.search(r'(\d+) Tests (\d+) Failures (\d+) Ignored',result.stdout)
                assert found and found[2]=='0',result.stdout
                row[label]=[int(x) for x in found.groups()]
            assert all(x==row['gcc'] for x in row.values()),row
            report['tests'][test]=row
            print(f'cJSON {test}: {row["gcc"][0]} tests pass in baseline / optimized / QBE / GCC (stack exceptions recorded)',flush=True)
    caller=work/'benchmark.c';caller.write_text(BENCH)
    synchronize(caller)
    reference=None
    for label in ['baseline','optimized','qbe','gcc']:
        exe=work/f'benchmark-{label}'
        obj=inside(cjson/'cJSON.c') if label=='gcc' else inside(objects[label])
        docker(['gcc','-O2','-I'+inside(cjson),inside(caller),obj,'-lm','-o',inside(exe)])
        # Warm-up separately; measure only the workload's internal monotonic clock.
        docker([inside(exe),'10'])
        samples=[]
        for _ in range(args.repetitions):
            row=json.loads(docker([inside(exe),str(args.iterations)]).stdout)
            signature={k:v for k,v in row.items() if k!='seconds'}
            if reference is None:reference=signature
            assert signature==reference,(label,row,reference)
            samples.append(row['seconds'])
        report['runtime'][label]={'seconds':samples,'median_seconds':statistics.median(samples),'executable_bytes':exe.stat().st_size,**signature}
        print(f'cJSON {label}: identical checksum {signature["checksum"]}, median {statistics.median(samples):.4f}s',flush=True)
    report_path=args.report or work/'report.json'
    report_path.parent.mkdir(parents=True,exist_ok=True)
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'report: {report_path}',flush=True)


if __name__=='__main__':main()
