#!/usr/bin/env python3
"""Replay pinned YAML inputs through existing libyaml executables, without rebuilding.

This compares compiler behavior against GCC, not YAML specification goldens.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

PIN = '6ad3d2c62885d82fc349026c136ef560838fdf3d'
REQUIRED = ['gcc-O0', 'gcc-O2', 'baseline', 'allocated', 'optimized', 'qbe-corrected']
ROOT = Path(__file__).resolve().parents[1]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def record(r):
    return {'exit': r[0], 'stdout_sha256': hashlib.sha256(r[1]).hexdigest(),
            'stderr_sha256': hashlib.sha256(r[2]).hexdigest(),
            'stdout_bytes': len(r[1]), 'stderr_bytes': len(r[2])}


def guest(config_path):
    config = json.loads(config_path.read_text())
    work = Path(config['work']); corpus = Path(config['corpus'])
    output = Path(config['output']); prefix = config['prefix']
    report = config['report']; report['backends'] = {}
    def save(): output.write_text(json.dumps(report, indent=2)+'\n')
    def run(label, data):
        try:
            p = subprocess.run([*prefix, str(work/label/'run-parser-test-suite')],
                               input=data, capture_output=True, timeout=10)
            return p.returncode, p.stdout, p.stderr
        except subprocess.TimeoutExpired as e:
            return 'timeout', e.stdout or b'', e.stderr or b''
    save()
    try:
        for label, expected in config['executables'].items():
            assert sha(work/label/'run-parser-test-suite') == expected, ('executable mismatch', label)
        for name, expected in report['payload_manifest'].items():
            assert sha(corpus/name) == expected['sha256'], ('payload mismatch', name)
        for label in REQUIRED:
            for name, expected in config['preflight'][label].items():
                p = work/'fixtures'/(name.removesuffix('-parse')+'.yaml')
                assert record(run(label, p.read_bytes())) == expected, ('reference replay mismatch', label, name)
        reference = {}
        for label in config['executables']:
            entry = {'status': 'running', 'matched': 0, 'mismatched': 0,
                     'exit_counts': {}, 'first_failures': [], 'cases': {}}
            report['backends'][label] = entry
            for name in report['payload_manifest']:
                result = run(label, (corpus/name).read_bytes())
                entry['cases'][name] = record(result)
                code = str(result[0]); entry['exit_counts'][code] = entry['exit_counts'].get(code, 0)+1
                if label == 'gcc-O0': reference[name] = result
                matches = result == reference[name] and result[0] in (0, 1)
                entry['matched' if matches else 'mismatched'] += 1
                if not matches and len(entry['first_failures']) < 10:
                    entry['first_failures'].append({'case': name, 'actual': record(result),
                         'expected': record(reference[name]),
                         'stderr_prefix': result[2][:1000].decode(errors='replace')})
            entry['status'] = 'passed' if entry['mismatched'] == 0 else 'failed'
            save(); print(config['target'], label, entry['status'], entry['matched'], entry['mismatched'], flush=True)
        assert all(report['backends'][n]['status'] == 'passed' for n in REQUIRED)
        for label, expected in config['executables'].items():
            assert sha(work/label/'run-parser-test-suite') == expected, ('executable changed', label)
        report['status'] = 'passed' if all(e['status'] == 'passed' for e in report['backends'].values()) else 'lcb_passed_with_original_qbe_failure'
    except BaseException as e:
        report.update(status='failed', diagnostic=repr(e)); save(); raise
    save()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--reference', type=Path)
    ap.add_argument('--corpus', type=Path, default=ROOT/'.build/linux-arm64/yaml-test-suite-data')
    ap.add_argument('--output-dir', type=Path, default=ROOT/'.build/linux-arm64/libyaml-corpus')
    ap.add_argument('--docker-container', default='lcb-parity-linux')
    ap.add_argument('--guest', type=Path)
    a = ap.parse_args()
    if a.guest: return guest(a.guest)
    assert a.reference, '--reference is required'
    from docker_sync import host_file
    base = ROOT/'.build/linux-arm64'
    def inside(p): return '/work/'+str(p.resolve().relative_to(base.resolve()))
    ref_hash = sha(a.reference); ref = json.loads(a.reference.read_text())
    assert ref['status'] in ['passed', 'lcb_passed_with_original_qbe_failure'], ref['status']
    assert ref['harness_sha256'] == sha(ROOT/'scripts/libyaml_compare.py'), 'stale harness reference'
    assert subprocess.check_output(['git', '-C', str(a.corpus), 'rev-parse', 'HEAD'], text=True).strip() == PIN
    assert not subprocess.check_output(['git', '-C', str(a.corpus), 'status', '--porcelain'], text=True).strip()
    work = Path(ref['work']); target = ref['target']; isa = target.removesuffix('-linux')
    assert sha(work/'lcb-snapshot') == ref['compiler_sha256'], 'compiler snapshot mismatch'
    for name, expected in ref['source_hashes'].items(): assert sha(work/'source'/name) == expected
    for name, expected in ref['translation_units'].items(): assert sha(work/'ir'/(name+'.ssa')) == expected['sha256']
    for label in REQUIRED:
        assert ref['backends'][label]['status'] == 'built'
        assert ref['backends'][label]['execution_status'] == 'passed'
    labels = REQUIRED + (['qbe'] if ref['backends']['qbe']['status'] == 'built' else [])
    executables = {n: sha(work/n/'run-parser-test-suite') for n in labels}
    manifest = {str(p.relative_to(a.corpus)): {'sha256': sha(p), 'bytes': p.stat().st_size}
                for p in sorted(a.corpus.rglob('in.yaml'))}
    assert manifest
    a.output_dir.mkdir(parents=True, exist_ok=True)
    report = {'schema': 1, 'status': 'running', 'target': target, 'corpus_commit': PIN,
              'reference_sha256': ref_hash, 'reference_report': str(a.reference),
              'compiler_identity': ref['compiler_identity'], 'compiler_sha256': ref['compiler_sha256'],
              'harness_sha256': sha(__file__), 'payload_manifest': manifest, 'input_count': len(manifest),
              'executables_sha256': executables, 'original_qbe_reference_status': ref['backends']['qbe'],
              'notes': ['Exact parser event stdout, error stderr, and exit comparison with GCC O0/O2.',
                        'Not YAML specification conformance; libyaml 0.2.5 may disagree with suite goldens.',
                        'No rebuild; compiler/source/IR hashes checked against reference; executable hashes checked before and after replay.',
                        'Reference reports predate executable hashes; seven generated parser fixtures bind required executables behaviorally to recorded reference output.',
                        'Original QBE failures remain separate; unbuilt original QBE is skipped explicitly.',
                        'ARM runs natively in Linux VM; x86/RV run under QEMU user emulation.']}
    config = {'target': target, 'work': inside(work), 'corpus': inside(a.corpus),
              'output': inside(a.output_dir/(target+'.json')), 'report': report,
              'prefix': [] if isa == 'aarch64' else ['qemu-'+isa, '-L', '/usr/'+isa+'-linux-gnu'],
              'executables': executables,
              'preflight': {n: {k: v for k, v in ref['execution']['backends'][n]['checks'].items() if k.endswith('-parse')} for n in REQUIRED}}
    assert all(len(v) == 7 for v in config['preflight'].values())
    script = a.output_dir/'libyaml_corpus.py'; script.write_bytes(Path(__file__).read_bytes())
    cfg = a.output_dir/(target+'-config.json'); cfg.write_text(json.dumps(config))
    for p in [script, cfg]: host_file(p, base, a.docker_container)
    subprocess.run(['docker', 'exec', a.docker_container, 'python3', inside(script), '--guest', inside(cfg)], check=True)
    assert sha(a.reference) == ref_hash, 'reference changed during replay'


if __name__ == '__main__': main()
