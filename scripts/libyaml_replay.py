#!/usr/bin/env python3
"""Replay retained libyaml IR against historical and freshly rerun GCC checks.

Never fetch, rebuild cproc, rewrite retained inputs, or rebuild reference binaries.
New compiler output goes into a new directory under the Docker-mounted build base.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
import traceback
from libyaml_compare import ROOT, LIBYAML, LIBRARY, DRIVERS
from docker_sync import host_file


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def verify_inputs(reference, original):
    source = original/'source'
    actual = {str(p.relative_to(source)): digest(p) for p in source.rglob('*')
              if p.suffix in ['.c', '.h'] and '.git' not in p.parts}
    assert actual == reference['source_hashes'], 'retained source hashes differ'
    assert set(reference['translation_units']) == set(LIBRARY+DRIVERS), 'expected 21 IR units'
    for name, entry in reference['translation_units'].items():
        assert digest(original/'ir'/(name+'.ssa')) == entry['sha256'], 'retained IR hash differs: '+name
    assert {p.stem for p in (original/'fixtures').glob('*.yaml')} == set(reference['fixtures'])
    for name, entry in reference['fixtures'].items():
        p = original/'fixtures'/(name+'.yaml')
        assert digest(p) == entry['sha256'] and p.stat().st_size == entry['bytes'], 'fixture differs: '+name


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference-report', type=Path, required=True)
    ap.add_argument('--compiler', type=Path, required=True)
    ap.add_argument('--work', type=Path, required=True)
    ap.add_argument('--report', type=Path)
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    args = ap.parse_args()
    reference_path = args.reference_report.resolve()
    reference = json.loads(reference_path.read_text())
    original = Path(reference['work']).resolve()
    base = (ROOT/'.build/linux-arm64').resolve()
    work = args.work.resolve()
    assert work.is_relative_to(base) and work != base, 'work must be below mounted build base'
    assert not work.is_relative_to(original) and not original.is_relative_to(work), 'work overlaps reference'
    assert not work.exists(), 'work must be a fresh output directory'
    work.mkdir(parents=True)
    report_path = args.report.resolve() if args.report else work/'report.json'
    assert not report_path.is_relative_to(original), 'report would overwrite reference'
    assert report_path not in [reference_path, args.compiler.resolve()], 'report would overwrite an input'
    harness_snapshot = work/'replay-harness.py'
    shutil.copy2(__file__, harness_snapshot)
    report = {'schema': 1, 'status': 'running', 'work': str(work), 'reference_work': str(original),
              'reference_report': str(reference_path), 'reference_report_sha256': digest(reference_path),
              'harness_sha256': digest(harness_snapshot), 'harness_snapshot': str(harness_snapshot),
              'helper_sha256': {n: digest(ROOT/'scripts'/n) for n in ['libyaml_compare.py', 'docker_sync.py']}, 'commands': [], 'backends': {}, 'negative_controls': {},
              'notes': ['Retained IR, source, fixtures and old GCC executables are read-only.',
                        'All 52 historical exit/stdout/stderr records must match rerun GCC O0 and O2 before LCB comparison.',
                        'Original/corrected QBE results are historical provenance only; neither oracle is rerun.',
                        'Native Linux ARM VM or QEMU execution; no runtime speed measurement.']}
    def save():
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2)+'\n')
    save()
    def run(cmd, check=True):
        cmd = list(map(str, cmd)); start = time.perf_counter()
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        report['commands'].append({'command': cmd, 'exit': p.returncode, 'stdout': p.stdout,
                                   'stderr': p.stderr, 'seconds': time.perf_counter()-start})
        save()
        if check: assert p.returncode == 0, (cmd, p.stdout, p.stderr)
        return p
    def inside(p): return '/work/'+str(Path(p).relative_to(base))
    def docker(cmd, check=True): return run(['docker', 'exec', args.docker_container, *cmd], check)
    def sync(p): host_file(p, base, args.docker_container)
    def guest_hash(p): return docker(['sha256sum', inside(p)]).stdout.split()[0]
    def read_guest_json(path):
        expected = guest_hash(path)
        for _ in range(100):
            try: payload = path.read_bytes()
            except FileNotFoundError: payload = None
            if payload is not None and hashlib.sha256(payload).hexdigest() == expected:
                report.setdefault('guest_json_sha256', {})[str(path)] = expected
                return json.loads(payload)
            time.sleep(.05)
        raise AssertionError('guest JSON did not synchronize: '+str(path))
    try:
        assert original.is_relative_to(base), 'reference outside mounted base'
        assert reference['status'] in ['passed', 'lcb_passed_with_original_qbe_failure']
        assert reference['source_commit'] == LIBYAML
        assert reference['target'] in ['aarch64-linux', 'x86_64-linux', 'riscv64-linux']
        target = reference['target']; isa = target.removesuffix('-linux')
        cc = 'gcc' if isa == 'aarch64' else isa+'-linux-gnu-gcc'
        prefix = [] if isa == 'aarch64' else ['qemu-'+isa, '-L', '/usr/'+isa+'-linux-gnu']
        report.update(target=target, source_commit=reference['source_commit'], cproc_commit=reference['cproc_commit'],
                      execution_mode='native Linux ARM64 VM' if not prefix else 'QEMU user emulation',
                      original_qbe_historical_status=reference['backends'].get('qbe'),
                      corrected_qbe_historical_status=reference['backends'].get('qbe-corrected'))
        assert docker(['uname', '-m']).stdout.strip() == 'aarch64'
        verify_inputs(reference, original)
        # Exercise the same preflight validator without modifying any retained file.
        damaged = json.loads(json.dumps(reference))
        first = sorted(damaged['translation_units'])[0]
        damaged['translation_units'][first]['sha256'] = '0'*64
        try: verify_inputs(damaged, original)
        except AssertionError as e:
            assert str(e) == 'retained IR hash differs: '+first
            report['negative_controls']['wrong_ir_hash'] = {'status': 'detected', 'unit': first, 'diagnostic': str(e)}
        else: raise AssertionError('wrong IR hash escaped preflight')
        report['source_hashes'] = reference['source_hashes']
        report['translation_units'] = reference['translation_units']
        report['fixtures'] = reference['fixtures']
        compiler = work/'lcb-snapshot'; shutil.copy2(args.compiler.resolve(), compiler)
        compiler_hash = digest(compiler)
        report.update(compiler_identity=run([compiler, '--build-identity']).stdout.strip(), compiler_sha256=compiler_hash)
        historical = reference['execution']['backends']
        assert all(historical[n]['status'] == 'passed' and len(historical[n]['checks']) == 52
                   for n in ['gcc-O0', 'gcc-O2'])
        assert historical['gcc-O0']['checks'] == historical['gcc-O2']['checks']
        retained = {str(original/'ir'/(n+'.ssa')): reference['translation_units'][n]['sha256'] for n in LIBRARY+DRIVERS}
        retained.update({str(original/'fixtures'/(n+'.yaml')): v['sha256'] for n,v in reference['fixtures'].items()})
        executables = {}
        for label in ['gcc-O0', 'gcc-O2']:
            for driver in DRIVERS:
                exe = original/label/driver
                # The original reports did not hash executables; bind them now and
                # require their behavior to match the historical records exactly.
                executables[str(exe)] = guest_hash(exe)
        retained.update(executables)
        report['reference_executable_sha256'] = executables
        for path, expected in retained.items(): assert guest_hash(Path(path)) == expected, path
        config = {'original': inside(original), 'work': inside(work), 'prefix': prefix,
                  'historical': {n: historical[n]['checks'] for n in ['gcc-O0', 'gcc-O2']},
                  'retained_hashes': {inside(Path(n)): h for n,h in retained.items()}}
        config_path = work/'config.json'; config_path.write_text(json.dumps(config, indent=2)+'\n'); sync(config_path)
        probe = work/'probe.py'; probe.write_text(PROBE); sync(probe)
        # Reference qualification precedes any candidate compilation.
        docker(['python3', inside(probe), inside(config_path), 'references'])
        report['reference_execution'] = read_guest_json(work/'reference-execution.json'); save()
        for mode, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize'])]:
            dest = work/mode; dest.mkdir()
            entry = {'status': 'building', 'assembly_sha256': {}, 'object_sha256': {}, 'executable_sha256': {}}
            report['backends'][mode] = entry; save()
            for n in LIBRARY+DRIVERS:
                asm = dest/(n+'.s'); obj = dest/(n+'.o')
                run([compiler, original/'ir'/(n+'.ssa'), '--target', target, *flags, '-o', asm]); sync(asm)
                docker([cc, '-c', inside(asm), '-o', inside(obj)])
                entry['assembly_sha256'][n] = digest(asm); entry['object_sha256'][n] = guest_hash(obj)
            for n in DRIVERS:
                exe = dest/n
                docker([cc, *[inside(dest/(u+'.o')) for u in LIBRARY], inside(dest/(n+'.o')), '-o', inside(exe)])
                entry['executable_sha256'][n] = guest_hash(exe)
            docker(['python3', inside(probe), inside(config_path), mode])
            entry['execution'] = read_guest_json(work/(mode+'-execution.json'))
            assert entry['execution']['checks'] == historical['gcc-O0']['checks']
            entry['status'] = 'passed'; save(); print(target, mode, '52 historical checks passed', flush=True)
        damaged_dir = work/'corrupted'; damaged_dir.mkdir()
        original_assembly = (work/'optimized/test-version.s').read_text()
        increment = {'aarch64': '\tadd x0, x0, #1', 'x86_64': '\taddl $1, %eax', 'riscv64': '\taddi a0, a0, 1'}[isa]
        bad_asm = damaged_dir/'test-version.s'
        damaged_assembly = original_assembly.replace('\tret', increment+'\n\tret')
        assert damaged_assembly != original_assembly
        bad_asm.write_text(damaged_assembly); sync(bad_asm)
        bad_exe = damaged_dir/'test-version'
        docker([cc, *[inside(work/'optimized'/(u+'.o')) for u in LIBRARY], inside(bad_asm), '-o', inside(bad_exe)])
        bad = docker([*prefix, inside(bad_exe)], check=False)
        assert bad.returncode != 0, 'corrupted driver escaped oracle'
        report['negative_controls']['corrupted_driver'] = {'status': 'detected', 'exit': bad.returncode, 'assembly_sha256': digest(bad_asm)}
        verify_inputs(reference, original)
        assert digest(compiler) == compiler_hash and digest(reference_path) == report['reference_report_sha256']
        for path, expected in retained.items(): assert guest_hash(Path(path)) == expected, path
        for mode, entry in report['backends'].items():
            for n,h in entry['executable_sha256'].items(): assert guest_hash(work/mode/n) == h
        report['bindings_checked_after_execution'] = True
        report['status'] = 'passed'
    except BaseException:
        report['status'] = 'failed'; report['diagnostic'] = traceback.format_exc(); raise
    finally: save()
    print(report_path, flush=True)


PROBE = r'''from pathlib import Path
import hashlib,json,subprocess,sys
config=json.loads(Path(sys.argv[1]).read_text());phase=sys.argv[2]
original=Path(config['original']);work=Path(config['work']);prefix=config['prefix']
for p,h in config['retained_hashes'].items():assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
result={'status':'running','checks':{}}
output=work/('reference-execution.json' if phase=='references' else phase+'-execution.json')
def save():output.write_text(json.dumps(result,indent=2)+'\n')
def record(r):return {'exit':r.returncode,'stdout_sha256':hashlib.sha256(r.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(r.stderr).hexdigest(),'stdout_bytes':len(r.stdout),'stderr_bytes':len(r.stderr)}
fixtures=sorted((original/'fixtures').glob('*.yaml'))
try:
 for label in (['gcc-O0','gcc-O2'] if phase=='references' else [phase]):
  directory=original/label if phase=='references' else work/label
  expected=config['historical'][label if phase=='references' else 'gcc-O0'];rows={}
  def check(name,driver,args=(),data=None):
   p=subprocess.run([*prefix,str(directory/driver),*args],input=data,capture_output=True,timeout=60)
   rows[name]=record(p);result['checks']=rows;save()
   assert rows[name]==expected[name],(label,name,rows[name],expected[name],p.stdout,p.stderr)
   return p.stdout
  check('version','test-version');check('reader','test-reader')
  for driver in ['run-scanner','run-parser','run-loader','run-emitter','run-dumper']:
   check(driver,driver,[str(p) for p in fixtures])
  for p in fixtures:
   data=p.read_bytes();events=check(p.stem+'-parse','run-parser-test-suite',data=data)
   check(p.stem+'-emit','run-emitter-test-suite',data=events)
   for driver in ['example-reformatter','example-reformatter-alt','example-deconstructor','example-deconstructor-alt']:
    check(p.stem+'-'+driver,driver,data=data)
  for i,data in enumerate([b'key: [unterminated',b'key: "\xff"',b'key: [one,,two]']):
   check('invalid-'+str(i),'run-parser-test-suite',data=data)
  assert rows==expected and len(rows)==52
  if phase=='references':result.setdefault('backends',{})[label]={'status':'passed','checks':rows}
 result['status']='passed'
except BaseException as e:result.update(status='failed',diagnostic=repr(e));raise
finally:save()
'''

if __name__ == '__main__': main()
