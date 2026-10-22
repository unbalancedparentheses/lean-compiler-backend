#!/usr/bin/env python3
"""Pinned unmodified libyaml library and all 13 upstream drivers via cproc.

Compare complete executable stdout/stderr/exit against GCC O0/O2, plus upstream
reader/version assertions and scanner/parser/emitter/loader/dumper roundtrips.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import traceback
from cjson_benchmark import ROOT, CPROC, command, fetch
from docker_sync import host_file

LIBYAML = '2c891fc7a770e8ba2fec34fc6b545c672beb37e6'  # 0.2.5
LIBRARY = 'api reader scanner parser loader writer emitter dumper'.split()
DRIVERS = 'test-version test-reader run-scanner run-parser run-loader run-emitter run-dumper example-reformatter example-reformatter-alt example-deconstructor example-deconstructor-alt run-parser-test-suite run-emitter-test-suite'.split()
DEFINES = ['-DYAML_VERSION_MAJOR=0', '-DYAML_VERSION_MINOR=2', '-DYAML_VERSION_PATCH=5',
           '-DYAML_VERSION_STRING="0.2.5"', '-DYAML_DECLARE_STATIC', '-D__CHAR_BIT__=8',
           '-D__SCHAR_MAX__=127', '-D__SHRT_MAX__=32767', '-D__LONG_MAX__=9223372036854775807L']


def digest(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--target', choices=['aarch64-linux', 'x86_64-linux', 'riscv64-linux'], default='aarch64-linux')
    ap.add_argument('--compiler', type=Path, default=ROOT/'.lake/build/bin/lcb')
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--report', type=Path)
    args = ap.parse_args()
    isa = args.target.removesuffix('-linux'); arm = isa == 'aarch64'
    qtarget = {'aarch64': 'arm64', 'x86_64': 'amd64_sysv', 'riscv64': 'rv64'}[isa]
    cc = 'gcc' if arm else isa+'-linux-gnu-gcc'
    prefix = [] if arm else ['qemu-'+isa, '-L', '/usr/'+isa+'-linux-gnu']
    base = ROOT/'.build/linux-arm64'; work = base/('libyaml-benchmark-'+isa)
    work.mkdir(parents=True, exist_ok=True)
    source, cproc = work/'source', work/'cproc'
    fetch(source, 'https://github.com/yaml/libyaml.git', LIBYAML)
    fetch(cproc, 'https://github.com/michaelforney/cproc.git', CPROC)
    def inside(p): return '/work/'+str(Path(p).relative_to(base))
    def docker(cmd, cwd=None, check=True):
        return command(['docker', 'exec', *(['-w', inside(cwd)] if cwd else []), args.docker_container, *cmd], check=check, timeout=600)
    def sync(p): host_file(p, base, args.docker_container)
    def sync_guest(p):
        expected = docker(['sha256sum', inside(p)]).stdout.split()[0]
        for _ in range(100):
            if p.exists() and digest(p) == expected: return
            time.sleep(.05)
        raise AssertionError('guest artifact did not synchronize: '+str(p))
    assert docker(['uname', '-m']).stdout.strip() == 'aarch64'
    configure = ['./configure']
    if not arm:
        libdir = str(Path(docker([cc, '-print-file-name=crtbegin.o']).stdout.strip()).parent)
        configure += ['--target='+isa+'-linux-gnu', '--with-gcc-libdir='+libdir]
    docker(configure, cproc); docker(['make', '-j4'], cproc)
    compiler = work/'lcb-snapshot'; shutil.copy2(args.compiler, compiler)
    source_hashes = {str(p.relative_to(source)): digest(p) for p in source.rglob('*') if p.suffix in ['.c', '.h'] and '.git' not in p.parts}
    for name in source_hashes: sync(source/name)
    # These are exactly the four constants in upstream cmake/config.h.in.
    template = (source/'cmake/config.h.in').read_text()
    assert template.count('#define YAML_VERSION_') == 4 and '@YAML_VERSION_STRING@' in template
    flags = [*DEFINES, '-I'+inside(source/'include')]
    oracles = {}
    qbe_sources = {str(p.relative_to(ROOT/'third_party/qbe')): digest(p) for p in (ROOT/'third_party/qbe').rglob('*') if p.suffix in ['.c', '.h'] and p.name != 'config.h'}
    patch_file = ROOT/('tests/upstream/qbe-1.3-amd64-extern-flags.json' if isa == 'x86_64' else 'tests/upstream/qbe-1.3-'+('arm64' if arm else 'rv64')+'-extern-offset.json')
    patch = json.loads(patch_file.read_text())
    for label in ['qbe', 'qbe-corrected']:
        dest = work/(label+'-host')
        if dest.exists(): shutil.rmtree(dest)
        shutil.copytree(ROOT/'third_party/qbe', dest)
        assert all(digest(dest/n) == h for n, h in qbe_sources.items())
        if label == 'qbe-corrected':
            p = dest/patch['source']; text = p.read_text(); assert text.count(patch['before']) == 1
            p.write_text(text.replace(patch['before'], patch['after']))
        command(['make', '-j4', 'CC='+os.environ.get('LCB_CC', 'cc'), 'CFLAGS=-std=c99 -O2'], cwd=dest)
        oracles[label] = dest/'qbe'
    report_path = args.report or work/'report.json'
    report = {'schema': 1, 'status': 'running', 'program': 'libyaml 0.2.5 and all 13 upstream drivers',
        'target': args.target, 'execution_mode': 'native Linux ARM64 VM' if arm else 'QEMU user emulation',
        'source_commit': LIBYAML, 'cproc_commit': CPROC, 'source_hashes': source_hashes,
        'compiler_identity': command([compiler, '--build-identity']).stdout.strip(), 'compiler_sha256': digest(compiler),
        'harness_sha256': digest(__file__), 'frontend_defines': DEFINES, 'work': str(work),
        'qbe_source_sha256': qbe_sources, 'qbe_binary_sha256': {n: digest(p) for n, p in oracles.items()},
        'oracle_patch_sha256': digest(patch_file), 'translation_units': {}, 'backends': {},
        'notes': ['Upstream C/header sources and frontend IR are unmodified.',
            'Version defines substitute the four constants of upstream cmake/config.h.in; no upstream build system or full upstream test-suite claim.',
            'All eight library units and all thirteen original driver units use identical target-specific cproc IR for LCB/QBE; GCC compiles the same original C directly.',
            'Original QBE and separately corrected reference remain distinct. Only RV QBE references use explicit non-PIE linking.',
            'Generated fixture and upstream assertion checks are finite qualification, not a formal proof. Runtime speed is not measured.']}
    def save(): report_path.parent.mkdir(parents=True, exist_ok=True); report_path.write_text(json.dumps(report, indent=2)+'\n')
    save()
    try:
        ir_dir = work/'ir'; ir_dir.mkdir(exist_ok=True)
        units = {n: source/('src' if n in LIBRARY else 'tests')/(n+'.c') for n in LIBRARY+DRIVERS}
        for n, src in units.items():
            ir = ir_dir/(n+'.ssa')
            docker([inside(cproc/'cproc'), *flags, '-emit-qbe', inside(src), '-o', inside(ir)])
            sync_guest(ir); text = ir.read_text()
            report['translation_units'][n] = {'sha256': digest(ir), 'lines': len(text.splitlines()), 'functions': len(re.findall(r'^(?:export )?function\b', text, re.M))}
        save()
        for label in ['gcc-O0', 'gcc-O2', 'baseline', 'allocated', 'optimized', 'qbe', 'qbe-corrected']:
            dest = work/label
            if dest.exists(): shutil.rmtree(dest)
            dest.mkdir()
            entry = {'status': 'building', 'link_flags': ['-no-pie'] if isa == 'riscv64' and label.startswith('qbe') else [], 'compile_seconds': {}, 'objects': {}}
            report['backends'][label] = entry; save()
            for n, src in units.items():
                obj = dest/(n+'.o'); start = time.perf_counter()
                if label.startswith('gcc'):
                    docker([cc, '-'+label.split('-')[1], *flags, '-c', inside(src), '-o', inside(obj)])
                else:
                    asm = dest/(n+'.s'); ir = ir_dir/(n+'.ssa')
                    cmd = [oracles[label], '-t', qtarget, '-o', asm, ir] if label.startswith('qbe') else [compiler, ir, '--target', args.target, *({'baseline': [], 'allocated': ['--allocate'], 'optimized': ['--optimize']}[label]), '-o', asm]
                    emitted = command(cmd, check=False)
                    if emitted.returncode:
                        entry.update(status='compile_failed', failure={'unit': n, 'exit': emitted.returncode, 'stderr': emitted.stderr})
                        assert label == 'qbe', entry
                        break
                    sync(asm)
                    assembled = docker([cc, '-c', inside(asm), '-o', inside(obj)], check=False)
                    if assembled.returncode:
                        entry.update(status='assemble_failed', failure={'unit': n, 'exit': assembled.returncode, 'stderr': assembled.stderr})
                        assert label == 'qbe', entry
                        break
                entry['compile_seconds'][n] = time.perf_counter()-start
                entry['objects'][n] = docker(['size', inside(obj)]).stdout.strip()
            if entry['status'] in ['compile_failed', 'assemble_failed']: save(); continue
            for n in DRIVERS:
                linked = docker([cc, *entry['link_flags'], *[inside(dest/(u+'.o')) for u in LIBRARY], inside(dest/(n+'.o')), '-o', inside(dest/n)], check=False)
                if linked.returncode:
                    entry.update(status='link_failed', failure={'driver': n, 'exit': linked.returncode, 'stderr': linked.stderr})
                    assert label == 'qbe', entry
                    break
            if entry['status'] == 'building': entry['status'] = 'built'
            save(); print(args.target, label, entry['status'], flush=True)
        # Mutation of the compiled driver must be detected by executable assertions.
        damaged_dir = work/'corrupted'; damaged_dir.mkdir(exist_ok=True)
        original = (work/'optimized/test-version.s').read_text()
        increment = {'aarch64': '\tadd x0, x0, #1', 'x86_64': '\taddl $1, %eax', 'riscv64': '\taddi a0, a0, 1'}[isa]
        damaged = original.replace('\tret', increment+'\n\tret')
        assert damaged != original
        bad_asm = damaged_dir/'test-version.s'; bad_asm.write_text(damaged); sync(bad_asm)
        docker([cc, *[inside(work/'optimized'/(n+'.o')) for n in LIBRARY], inside(bad_asm), '-o', inside(damaged_dir/'test-version')])
        bad = docker([*prefix, inside(damaged_dir/'test-version')], check=False)
        assert bad.returncode != 0, 'corrupted driver exit escaped oracle'
        report['negative_control'] = {'status': 'detected', 'mutation': 'Increment integer return register at every return in compiled test-version driver', 'exit': bad.returncode, 'assembly_sha256': digest(bad_asm)}
        fixtures = {
            'mapping': 'name: compiler\nitems: [1, 2, {key: value}]\n',
            'aliases': 'base: &defaults {one: 1, two: [yes, no]}\ncopy: *defaults\n',
            'unicode': 'language: "Español 日本語 Ελληνικά"\nescape: "a\\tb\\n\\u263A"\n',
            'documents': '%YAML 1.1\n---\nfirst: !!str 123\n...\n---\n- second\n- null\n',
            'blocks': 'literal: |\n  first\n  second\nfolded: >-\n  long\n  line\n',
            'nested': 'root: '+('[{key: '*12)+'value'+('}]'*12)+'\n',
            'sequence': ''.join(f'- {{id: {i}, label: "row {i}", enabled: true}}\n' for i in range(60))}
        fixture_dir = work/'fixtures'
        if fixture_dir.exists(): shutil.rmtree(fixture_dir)
        fixture_dir.mkdir()
        for n, value in fixtures.items(): p = fixture_dir/(n+'.yaml'); p.write_text(value); sync(p)
        report['fixtures'] = {n: {'bytes': len(v.encode()), 'sha256': hashlib.sha256(v.encode()).hexdigest()} for n, v in fixtures.items()}
        probe = work/'probe.py'
        built = [n for n, e in report['backends'].items() if e['status'] == 'built']
        required = {'gcc-O0', 'gcc-O2', 'baseline', 'allocated', 'optimized', 'qbe-corrected'}
        assert required.issubset(built)
        probe.write_text(PROBE.replace('WORK_LITERAL', repr(inside(work))).replace('PREFIX_LITERAL', repr(prefix)).replace('LABELS_LITERAL', repr(built)))
        sync(probe); tested = docker(['python3', inside(probe)], check=False)
        (work/'probe.log').write_text(tested.stdout+tested.stderr)
        sync_guest(work/'execution.json'); execution = json.loads((work/'execution.json').read_text())
        report['execution'] = execution
        assert tested.returncode == 0, tested.stderr
        assert set(execution['backends']) == set(built)
        assert all(execution['backends'][n]['status'] == 'passed' for n in required)
        for label, entry in execution['backends'].items(): report['backends'][label]['execution_status'] = entry['status']
        assert source_hashes == {n: digest(source/n) for n in source_hashes}
        report['status'] = 'passed' if report['backends']['qbe']['status'] == 'built' and report['backends']['qbe'].get('execution_status') == 'passed' else 'lcb_passed_with_original_qbe_failure'
    except BaseException:
        report['status'] = 'failed'; report['diagnostic'] = traceback.format_exc(); raise
    finally: save()
    print(args.target, report['status'], report_path, flush=True)


PROBE = r'''from pathlib import Path
import hashlib,json,subprocess
root=Path(WORK_LITERAL);prefix=PREFIX_LITERAL
result={'backends':{}}
def save(): (root/'execution.json').write_text(json.dumps(result,indent=2)+'\n')
def run(label,driver,args=(),data=None):
 p=subprocess.run([*prefix,str(root/label/driver),*args],input=data,capture_output=True,timeout=60)
 return (p.returncode,p.stdout,p.stderr)
def record(r):return {'exit':r[0],'stdout_sha256':hashlib.sha256(r[1]).hexdigest(),'stderr_sha256':hashlib.sha256(r[2]).hexdigest(),'stdout_bytes':len(r[1]),'stderr_bytes':len(r[2])}
fixtures=sorted((root/'fixtures').glob('*.yaml'));reference={}
for label in LABELS_LITERAL:
 assert (root/label/'test-version').exists(),label
 rows={};result['backends'][label]={'status':'running','checks':rows};save()
 try:
  def check(name,driver,args=(),data=None,success=True):
   r=run(label,driver,args,data);rows[name]=record(r);save()
   if label=='gcc-O0':
    assert (r[0]==0)==success,(label,name,r)
    reference[name]=r
   else:assert r==reference[name],(label,name,r,reference[name])
   return r[1]
  check('version','test-version');check('reader','test-reader')
  for driver in ['run-scanner','run-parser','run-loader','run-emitter','run-dumper']:
   check(driver,driver,[str(p) for p in fixtures])
  for p in fixtures:
   data=p.read_bytes()
   events=check(p.stem+'-parse','run-parser-test-suite',data=data)
   check(p.stem+'-emit','run-emitter-test-suite',data=events)
   for driver in ['example-reformatter','example-reformatter-alt','example-deconstructor','example-deconstructor-alt']:
    check(p.stem+'-'+driver,driver,data=data)
  for i,data in enumerate([b'key: [unterminated',b'key: "\xff"',b'key: [one,,two]']):
   check('invalid-'+str(i),'run-parser-test-suite',data=data,success=False)
  result['backends'][label]['status']='passed'
 except BaseException as e:
  result['backends'][label].update(status='failed',diagnostic=repr(e));save()
  if label!='qbe':raise
 save()
'''

if __name__ == '__main__': main()
