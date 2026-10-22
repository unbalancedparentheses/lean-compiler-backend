"""Accept only exact empty ARM conditional trampoline rewrites."""
import argparse
import json
from pathlib import Path
import re


def audit(old, new):
    lines = old.splitlines(keepends=True)
    result = []
    i = removed = 0
    while i < len(lines):
        if i+4 < len(lines):
            branch, yes, edge, no, label = lines[i:i+5]
            m = re.fullmatch(r'(\tb\.[a-z]+ |\tcbz w[0-9]+, )(L_lcb_edge_[^\n]+)\n', branch)
            if (m and edge == m[2]+':\n' and yes.startswith('\tb ') and
                    no.startswith('\tb ') and label == yes[3:-1]+':\n'):
                result.append(m[1]+no[3:])
                i += 4
                removed += 2  # two instructions; the edge label also disappears
                continue
        result.append(lines[i])
        i += 1
    assert ''.join(result) == new
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
           'removed_branch_instructions': removed,
           'note': 'Only allocated/optimized ARM empty conditional trampoline rewrites accepted; every other byte preserved. Raw exact comparison reports intended differences. Not a semantic proof.'}
    args.output.write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps(out))


if __name__ == '__main__':
    main()
