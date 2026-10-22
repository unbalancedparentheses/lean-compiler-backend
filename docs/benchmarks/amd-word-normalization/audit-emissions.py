"""Audit corpus changes as deletion of redundant AMD64 word normalization only."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('raw_report', type=Path)
p.add_argument('output', type=Path)
args = p.parse_args()
r = json.loads(args.raw_report.read_text())
work = Path(r['work'])
inputs = sorted(set(row['input'] for row in r['cases']))
counts = {}
removed = 0
for row in r['cases']:
    if row['status'] == 'identical_refusal':
        continue
    assert row['before']['exit'] == row['after']['exit'] == 0, row
    stem = f'{inputs.index(row["input"])}-{row["target"]}-{row["mode"]}'
    old = (work / (stem + '-before.s')).read_text().splitlines(keepends=True)
    new = (work / (stem + '-after.s')).read_text().splitlines(keepends=True)
    if row['target'] not in ['x86_64-linux', 'x86_64-macos']:
        assert old == new
    i = 0
    for line in old:
        if i < len(new) and line == new[i]:
            i += 1
        else:
            assert row['target'].startswith('x86_64-')
            assert line == '\tmovl %eax, %eax\n', (stem, line)
            removed += 1
    assert i == len(new), stem
    if old != new:
        counts[row['target']] = counts.get(row['target'], 0) + 1
out = {'status': 'passed', 'compilers': r['compilers'], 'cases': len(r['cases']),
       'unchanged_assemblies': r['identical_assemblies'],
       'matching_refusals': r['identical_refusals'],
       'expected_changed_assemblies': counts, 'removed_normalizations': removed,
       'note': 'Raw exact comparison reports intended differences. This audit permits only deletion of movl %eax,%eax on AMD64; every other byte is preserved. Not a semantic proof.'}
args.output.write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out))
