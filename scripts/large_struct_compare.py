#!/usr/bin/env python3
"""Qualify frontend-generated large struct assignments against GCC and original QBE."""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import time
from cjson_benchmark import CPROC, ROOT, command, fetch
from docker_sync import host_file

SOURCE=r'''
#include <stdint.h>
#include <stdio.h>
struct payload { unsigned char bytes[65537]; uint64_t tail; };
struct guarded { uint64_t before; struct payload value; uint64_t after; };
static struct guarded source,destination,third;
static uint64_t copy_and_check(struct payload *out,const struct payload *in) {
 struct payload temporary;
 temporary=*in;
 *out=temporary;
 uint64_t h=UINT64_C(1469598103934665603);
 for(unsigned i=0;i<65537;i++){if(out->bytes[i]!=in->bytes[i])return 0;h=(h^out->bytes[i])*UINT64_C(1099511628211);}
 if(out->tail!=in->tail)return 0;
 return h^out->tail;
}
int main(void) {
 uint64_t total=0;
 for(unsigned round=0;round<16;round++){
  source.before=destination.before=third.before=UINT64_C(0x123456789abcdef0);
  source.after=destination.after=third.after=UINT64_C(0xfedcba9876543210);
  for(unsigned i=0;i<65537;i++){source.value.bytes[i]=(unsigned char)(i*131u+(i>>7)+round*17u);destination.value.bytes[i]=0;third.value.bytes[i]=99;}
  source.value.tail=UINT64_C(0xdeadbeef01234567)^round;
  uint64_t expected=UINT64_C(1469598103934665603);
  for(unsigned i=0;i<65537;i++)expected=(expected^source.value.bytes[i])*UINT64_C(1099511628211);
  expected^=source.value.tail;
  if(copy_and_check(&destination.value,&source.value)!=expected)return 1;
  third.value=destination.value;
  if(copy_and_check(&third.value,&third.value)!=expected)return 2;
  for(unsigned i=0;i<65537;i++)if(third.value.bytes[i]!=source.value.bytes[i])return 3;
  if(source.before!=UINT64_C(0x123456789abcdef0)||destination.before!=source.before||third.before!=source.before)return 4;
  if(source.after!=UINT64_C(0xfedcba9876543210)||destination.after!=source.after||third.after!=source.after)return 5;
  total=total*257+expected;
 }
 printf("%016llx\n",(unsigned long long)total);
 return 0;
}
'''


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container',default='lcb-parity-linux')
    ap.add_argument('--compiler',type=Path,default=ROOT/'.lake/build/bin/lcb')
    ap.add_argument('--report',type=Path)
    ap.add_argument('--payload-bytes',type=int,default=8193)
    ap.add_argument('--allow-resource-refusal',action='store_true',help='retain the known 500000-token admission refusal as unqualified')
    args=ap.parse_args()
    base=ROOT/'.build/linux-arm64';work=base/'large-struct';work.mkdir(exist_ok=True)
    def inside(path):return '/work/'+str(Path(path).relative_to(base))
    def docker(cmd,cwd=None,check=True):
        return command(['docker','exec',*(['-w',inside(cwd)] if cwd else []),args.docker_container,*map(str,cmd)],check=check)
    def guest_file(path):
        digest=docker(['sha256sum',inside(path)]).stdout.split()[0]
        for _ in range(100):
            if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==digest:return
            time.sleep(.05)
        raise AssertionError(f'guest-authored input did not synchronize: {path}')
    cproc=base/'cjson-benchmark/cproc'
    fetch(cproc,'https://github.com/michaelforney/cproc.git',CPROC)
    docker(['./configure'],cproc);docker(['make','-j4'],cproc)
    compiler=work/'lcb-snapshot';shutil.copy2(args.compiler,compiler)
    source,ir=work/'input.c',work/'input.ssa';source.write_text(SOURCE.replace('65537',str(args.payload_bytes)))
    host_file(source,base,args.docker_container)
    docker([inside(cproc/'cproc'),'-emit-qbe',inside(source),'-o',inside(ir)])
    guest_file(ir)
    sizes=[int(x) for x in re.findall(r'\bblit [^\n]*,\s*([0-9]+)',ir.read_text())]
    assert not sizes,'re-audit the comparison if this pinned frontend begins emitting blit'
    qbesrc=work/'qbe-host'
    if not qbesrc.exists():shutil.copytree(ROOT/'third_party/qbe',qbesrc)
    pinned=ROOT/'third_party/qbe'
    qbe_sources={str(p.relative_to(pinned)):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in pinned.rglob('*') if p.suffix in ('.c','.h') and p.name!='config.h'}
    def check_qbe_sources():
        assert all(hashlib.sha256((qbesrc/name).read_bytes()).hexdigest()==digest
            for name,digest in qbe_sources.items()),'private QBE source differs from pinned original'
    check_qbe_sources()
    command(['make','-C',qbesrc,'clean'])
    command(['make','-C',qbesrc,'-j4','CC='+os.environ.get('LCB_CC','cc'),'CFLAGS=-std=c99 -O2'])
    check_qbe_sources()
    report={'schema':1,'program':'generated large-struct C assignment regression','target':'aarch64-linux',
        'execution':docker(['uname','-a']).stdout.strip(),'compiler_identity':command([compiler,'--build-identity']).stdout.strip(),
        'compiler_sha256':hashlib.sha256(compiler.read_bytes()).hexdigest(),
        'harness_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'host_platform':platform.platform(),'host_machine':platform.machine(),
        'c_compiler':docker(['gcc','--version']).stdout.strip(),
        'qbe_version':'1.3 (unchanged pinned source)','qbe_source_sha256':qbe_sources,
        'qbe_binary_sha256':hashlib.sha256((qbesrc/'qbe').read_bytes()).hexdigest(),
        'cproc_commit':CPROC,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'ir_sha256':hashlib.sha256(ir.read_bytes()).hexdigest(),'ir_lines':len(ir.read_text().splitlines()),
        'payload_bytes':args.payload_bytes,'blit_sizes':sizes,'copy_strategy':'cproc scalar load/store expansion; this is not direct blit qualification','backends':{},'notes':['Same unchanged generated C source is compiled directly by GCC O0/O2.',
        'LCB baseline/allocated/optimized and original QBE consume byte-identical cproc IR.',
        'Pointer arguments remain scalar; this does not enlarge the aggregate-call ABI domain.',
        'Original QBE is retained unchanged; no corrected oracle is needed for this regression.',
        'seconds measures executable wall time. build_seconds measures per-backend compile plus link, including host/guest assembly synchronization; GCC combines C compilation and linking.',
        'emission_seconds measures only the QBE/LCB IR compiler invocation. Refused builds record time until refusal, without linking.',
        'Timing excludes frontend generation and toolchain builds; these are single observations under concurrent load, not benchmark distributions.']}
    expected=None
    for label in ['gcc-O0','gcc-O2','baseline','allocated','optimized','qbe']:
        exe=work/label
        build_start=time.monotonic();emission_seconds=None
        if label.startswith('gcc-'):
            docker(['gcc','-'+label.split('-')[1],inside(source),'-o',inside(exe)])
        else:
            asm=work/(label+'.s')
            emission_start=time.monotonic()
            compiled=command([qbesrc/'qbe','-t','arm64','-o',asm,ir] if label=='qbe' else
                [compiler,ir,'--target','aarch64-linux',*({'baseline':[],'allocated':['--allocate'],'optimized':['--optimize']}[label]),'-o',asm],check=False)
            emission_seconds=time.monotonic()-emission_start
            if compiled.returncode:
                assert args.allow_resource_refusal and label!='qbe' and '500000-token compatibility limit' in compiled.stderr,(label,compiled.stderr)
                report['backends'][label]={'qualified':False,'phase':'admission','diagnostic':compiled.stderr.strip(),
                    'build_seconds':time.monotonic()-build_start,'emission_seconds':emission_seconds}
                print(f'large struct {label}: token-budget refusal retained as unqualified',flush=True)
                continue
            host_file(asm,base,args.docker_container)
            docker(['gcc',inside(asm),'-o',inside(exe)])
        build_seconds=time.monotonic()-build_start
        start=time.monotonic();result=docker([inside(exe)]);elapsed=time.monotonic()-start
        if expected is None:expected=result.stdout
        assert result.stdout==expected,(label,result.stdout,expected)
        report['backends'][label]={'qualified':True,'stdout':result.stdout.strip(),'seconds':elapsed,'build_seconds':build_seconds,'size':docker(['size',inside(exe)]).stdout.strip(),
            'executable_sha256':docker(['sha256sum',inside(exe)]).stdout.split()[0]}
        if emission_seconds is not None: report['backends'][label]['emission_seconds']=emission_seconds
        print(f'large struct {label}: 16 patterned copies, local/global assignments and guards passed: {result.stdout.strip()}',flush=True)
    if args.allow_resource_refusal:
        assert any(not v['qualified'] for v in report['backends'].values()),'resource refusal no longer applies; update the qualification'
    path=args.report or work/'report.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'large struct: {args.payload_bytes}-byte payload, scalar-expanded frontend copies; report: {path}',flush=True)


if __name__=='__main__':main()
