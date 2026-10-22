"""Accept only deletion of ARM same-register unsigned extensions."""
import argparse
import json
from pathlib import Path
import re


def audit(old, new):
    new = new.splitlines(keepends=True)
    j = removed = 0
    for line in old.splitlines(keepends=True):
        if j < len(new) and line == new[j]:
            j += 1
        else:
            assert re.fullmatch(r'\tuxt[bh] (w\d+), \1\n', line), line
            removed += 1
    assert j == len(new)
    return removed


def main():
    p = argparse.ArgumentParser()
    p.add_argument('raw_report', type=Path)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    r = json.loads(args.raw_report.read_text())
    inputs = sorted(set(row['input'] for row in r['cases']))
    work = Path(r['work'])
    changes = {}
    removed = 0
    for row in r['cases']:
        if row['status'] == 'identical_refusal':
            continue
        assert row['before']['exit'] == row['after']['exit'] == 0
        stem = f'{inputs.index(row["input"])}-{row["target"]}-{row["mode"]}'
        old = (work/(stem+'-before.s')).read_text()
        new = (work/(stem+'-after.s')).read_text()
        if row['target'].startswith('aarch64-') and row['mode'] != 'baseline':
            removed += audit(old, new)
        else:
            assert old == new
        if old != new:
            changes[row['target']] = changes.get(row['target'], 0)+1
    out = {'status': 'passed', 'compilers': r['compilers'], 'cases': len(r['cases']),
           'unchanged_assemblies': r['identical_assemblies'],
           'matching_refusals': r['identical_refusals'], 'expected_changed_assemblies': changes,
           'removed_extensions': removed,
           'note': 'Only allocated/optimized ARM same-register unsigned-extension deletions accepted; every other byte preserved. Raw exact comparison reports intended differences. Not a semantic proof.'}
    args.output.write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps(out))


if __name__ == '__main__':
    main()
