"""Permit only complete t0 word-normalization pair deletions."""
import argparse
import json
from pathlib import Path

PAIR = ['\tslli t0, t0, 32\n', '\tsrli t0, t0, 32\n']


def audit(old, new):
    old, new = old.splitlines(keepends=True), new.splitlines(keepends=True)
    i = j = count = 0
    while i < len(old):
        if j < len(new) and old[i] == new[j]:
            i += 1
            j += 1
        else:
            assert old[i:i+2] == PAIR, (i, old[i:i+2])
            i += 2
            count += 1
    assert j == len(new)
    return count


def main():
    p = argparse.ArgumentParser()
    p.add_argument('raw_report', type=Path)
    p.add_argument('output', type=Path)
    args = p.parse_args()
    r = json.loads(args.raw_report.read_text())
    inputs = sorted(set(row['input'] for row in r['cases']))
    work = Path(r['work'])
    changes = removed = 0
    for row in r['cases']:
        if row['status'] == 'identical_refusal':
            continue
        assert row['before']['exit'] == row['after']['exit'] == 0
        stem = f'{inputs.index(row["input"])}-{row["target"]}-{row["mode"]}'
        old = (work/(stem+'-before.s')).read_text()
        new = (work/(stem+'-after.s')).read_text()
        if row['target'] == 'riscv64-linux':
            removed += audit(old, new)
            changes += old != new
        else:
            assert old == new
    out = {'status': 'passed', 'compilers': r['compilers'], 'cases': len(r['cases']),
           'unchanged_assemblies': r['identical_assemblies'],
           'matching_refusals': r['identical_refusals'],
           'expected_changed_rv_assemblies': changes, 'removed_normalization_pairs': removed,
           'note': 'Raw exact comparison reports intended differences. Separate audit allows only complete t0 normalization-pair deletions on RV; every other byte unchanged. Not a semantic proof.'}
    args.output.write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps(out))


if __name__ == '__main__':
    main()
