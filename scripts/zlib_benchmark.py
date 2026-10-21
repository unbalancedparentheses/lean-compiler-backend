#!/usr/bin/env python3
"""Compile pinned zlib and its original example/minigzip programs through cproc.

Runs the upstream static test recipe and deterministic gzip/round-trip comparisons
inside the native ARM64 Linux qualification container. Upstream configure generates
Makefile/zconf.h; C sources and frontend IR are never patched.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import time
from cjson_benchmark import ROOT, CPROC, command, fetch

ZLIB = '51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf'  # v1.3.1
UNITS = 'adler32 crc32 deflate infback inffast inflate inftrees trees zutil compress uncompr gzclose gzlib gzread gzwrite'.split()
DEFINES = ['-D__CHAR_BIT__=8','-D__SCHAR_MAX__=127','-D__SHRT_MAX__=32767',
           '-D__LONG_MAX__=9223372036854775807L','-D_LARGEFILE64_SOURCE=1','-DHAVE_HIDDEN']


def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--docker-container',default='lcb-parity-linux')
    ap.add_argument('--compiler',type=Path,default=ROOT/'.lake/build/bin/lcb')
    ap.add_argument('--report',type=Path)
    args=ap.parse_args()
    base=ROOT/'.build/linux-arm64';work=base/'zlib-benchmark';work.mkdir(exist_ok=True)
    source,cproc=work/'zlib',work/'cproc'
    pristine=work/'upstream-zlib'
    fetch(pristine,'https://github.com/madler/zlib.git',ZLIB)
    if source.exists():shutil.rmtree(source)
    shutil.copytree(pristine,source,ignore=shutil.ignore_patterns('.git'))
    fetch(cproc,'https://github.com/michaelforney/cproc.git',CPROC)
    def inside(path):return '/work/'+str(Path(path).relative_to(base))
    def docker(cmd,cwd=None,check=True):
        return command(['docker','exec',*(['-w',inside(cwd)] if cwd else []),args.docker_container,*cmd],check=check,timeout=600)
    def sync(path,to_guest=True):
        expected=digest(path) if to_guest else docker(['sha256sum',inside(path)]).stdout.split()[0]
        if to_guest:
            with path.open('rb') as stream:os.fsync(stream.fileno())
        for _ in range(100):
            actual=docker(['sha256sum',inside(path)],check=False).stdout.split() if to_guest else [digest(path)] if path.exists() else []
            if actual and actual[0]==expected:return
            time.sleep(.05)
        raise AssertionError(f'file digest did not synchronize: {path}')
    assert docker(['uname','-m']).stdout.strip()=='aarch64'
    for path in source.rglob('*'):
        if path.is_file():sync(path)
    docker(['./configure'],cproc);docker(['make','-j4'],cproc)
    docker(['./configure','--static'],source);docker(['make','-j4'],source)
    for path in pristine.rglob('*.c'):
        assert digest(path)==digest(source/path.relative_to(pristine)), 'upstream C source changed'
    compiler=work/'lcb-snapshot';shutil.copy2(args.compiler,compiler)
    patch_path=ROOT/'tests/upstream/qbe-1.3-arm64-extern-offset.json';patch=json.loads(patch_path.read_text())
    lock=json.loads((ROOT/'upstream-lock.json').read_text());oracles={}
    for label in ['qbe','qbe-corrected']:
        oracle=work/(label+'-host')
        if oracle.exists():shutil.rmtree(oracle)
        shutil.copytree(ROOT/'third_party/qbe',oracle)
        if label=='qbe-corrected':
            original=ROOT/'third_party/qbe'/patch['source']
            assert digest(original)==lock['vendored_files'][str(original.relative_to(ROOT))]
            text=original.read_text();assert text.count(patch['before'])==1
            (oracle/patch['source']).write_text(text.replace(patch['before'],patch['after']))
        command(['make','-j4',f'CC={os.environ.get("LCB_CC","cc")}','CFLAGS=-std=c99 -O2'],cwd=oracle)
        oracles[label]=oracle/'qbe'
    report={'schema':1,'program':'zlib 1.3.1 library, example and minigzip','target':'aarch64-linux',
        'execution':docker(['uname','-a']).stdout.strip(),'compile_host':platform.platform(),
        'zlib_commit':ZLIB,'cproc_commit':CPROC,'compiler_identity':command([compiler,'--build-identity']).stdout.strip(),
        'frontend_defines':DEFINES,'configure':['./configure','--static'],
        'gcc_reference_flags':re.search(r'^CFLAGS=(.*)$',(source/'Makefile').read_text(),re.M)[1],
        'configuration_hashes':{n:digest(source/n) for n in ['Makefile','zconf.h']},
        'source_hashes':{str(p.relative_to(source)):digest(p) for p in source.rglob('*') if p.is_file() and p.suffix in ['.c','.h'] and '.git' not in p.parts},
        'translation_units':{},'backends':{},'oracle_patch_sha256':digest(patch_path),
        'notes':['Upstream configure generates Makefile/zconf.h; C sources and frontend IR are unmodified.',
                 'The library and both test programs are compiled by each backend from identical cproc IR.',
                 'All modes link all fifteen library objects with each test-program object; GCC uses the upstream configured CFLAGS.',
                 'GNU size includes read-only data in text; section placement can differ between backends.',
                 'The upstream teststatic recipe runs with static marked already built; no replacement source recipe.',
                 'Original QBE failures remain separate from the existing test-only external-address correction.',
                 'Gzip bytes match the GCC reference and decompression matches independently generated Python payloads.',
                 'Local runtime includes executable startup and pipe I/O; measurements are not universal speed claims.']}
    (work/'ir').mkdir(exist_ok=True)
    for name in UNITS+['test/example','test/minigzip']:
        ir=work/'ir'/(name.replace('/','-')+'.ssa')
        docker([inside(cproc/'cproc'),*DEFINES,'-I'+inside(source),'-emit-qbe',inside(source/(name+'.c')),'-o',inside(ir)])
        sync(ir,False);text=ir.read_text()
        report['translation_units'][name]={'sha256':digest(ir),'lines':len(text.splitlines()),'bytes':ir.stat().st_size,'functions':len(re.findall(r'^(?:export )?function\b',text,re.M))}
    reference=work/'gcc';reference.mkdir(exist_ok=True)
    for name in ['example','minigzip']:
        docker(['gcc',*[inside(source/(unit+'.o')) for unit in UNITS],inside(source/(name+'.o')),'-o',inside(reference/name)])
    for label in ['baseline','optimized','qbe','qbe-corrected','gcc']:
        case=work/label;case.mkdir(exist_ok=True);timings={};objects={}
        if label!='gcc':
            for name in UNITS+['test/example','test/minigzip']:
                stem=name.replace('/','-');ir=work/'ir'/(stem+'.ssa');asm,obj=case/(stem+'.s'),case/(stem+'.o')
                cmd=[oracles[label],'-t','arm64','-o',asm,ir] if label.startswith('qbe') else [compiler,ir,'--target','aarch64-linux',*(['--optimize'] if label=='optimized' else []),'-o',asm]
                start=time.perf_counter();command(cmd);timings[name]=time.perf_counter()-start
                sync(asm);docker(['gcc','-c',inside(asm),'-o',inside(obj)]);objects[name]=obj
            for name in ['example','minigzip']:
                docker(['gcc',*[inside(objects[n]) for n in UNITS],inside(objects['test/'+name]),'-o',inside(case/name)])
        entry={'compile_seconds':timings,'total_compile_seconds':sum(timings.values()),
            'minigzip_size':docker(['size',inside(case/'minigzip')]).stdout.strip()}
        report['backends'][label]=entry
        before={name:docker(['sha256sum',inside(case/name)]).stdout.split()[0] for name in ['example','minigzip']}
        tested=docker(['make','-s','-f',inside(source/'Makefile'),'-o','static','teststatic'],case,check=False)
        for name in before:assert docker(['sha256sum',inside(case/name)]).stdout.split()[0]==before[name], 'test recipe rebuilt executable'
        entry['upstream_teststatic']={'exit':tested.returncode,'stdout':tested.stdout,'stderr':tested.stderr}
        if tested.returncode:
            assert label=='qbe',(label,tested.stdout,tested.stderr)
            print(f'zlib {label}: original upstream test failure retained',flush=True)
        else:
            assert 'zlib test OK' in tested.stdout
            print(f'zlib {label}: upstream example and gzip static test passed',flush=True)
    probe=work/'probe.py'
    labels=[label for label,entry in report['backends'].items() if entry['upstream_teststatic']['exit']==0]
    probe.write_text('''from pathlib import Path
import gzip,hashlib,json,random,statistics,subprocess,time
root=Path('/work/zlib-benchmark');rng=random.Random(20261021)
payloads=[b'',bytes(range(256))*32,rng.randbytes(65536),(b'compiler-backend-zlib\\x00'*8192+rng.randbytes(4096))*8]
result={'payloads':[{'bytes':len(p),'sha256':hashlib.sha256(p).hexdigest()} for p in payloads],'backends':{}}
def run(label,args,data):
 p=subprocess.run([str(root/label/'minigzip'),*args],input=data,capture_output=True)
 assert p.returncode==0,(label,args,p.returncode,p.stderr)
 return p.stdout
for label in LABELS:
 checks=[]
 for i,data in enumerate(payloads):
  for level in [1,6,9]:
   expected=run('gcc',['-'+str(level)],data)
   actual=run(label,['-'+str(level)],data)
   assert actual==expected,(label,i,level,'compressed bytes')
   assert gzip.decompress(actual)==data,(label,i,level,'Python decompression')
   assert run(label,['-d'],expected)==data,(label,i,level,'decompression')
   checks.append({'payload':i,'level':level,'compressed_bytes':len(actual),'sha256':hashlib.sha256(actual).hexdigest()})
 samples=[]
 for _ in range(5):
  start=time.monotonic();packed=run(label,['-6'],payloads[-1]);unpacked=run(label,['-d'],packed)
  assert unpacked==payloads[-1]
  samples.append(time.monotonic()-start)
 result['backends'][label]={'gzip_checks':checks,'round_trip_seconds':samples,'median_seconds':statistics.median(samples)}
(root/'probe.json').write_text(json.dumps(result,indent=2)+'\\n')
'''.replace('LABELS',repr(labels)))
    sync(probe);docker(['python3',inside(probe)]);sync(work/'probe.json',False)
    report['payload_tests']=json.loads((work/'probe.json').read_text())
    destination=args.report or work/'report.json';destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(report,indent=2)+'\n')
    print(f'zlib: {len(report["translation_units"])} units; 12 exact gzip streams and independent round trips per qualified backend; report: {destination}',flush=True)


if __name__=='__main__':main()
