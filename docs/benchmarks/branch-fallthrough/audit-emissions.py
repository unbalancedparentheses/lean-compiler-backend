"""Accept only jumps to the immediately following label being deleted."""
import argparse
import json
from pathlib import Path
import re


def audit(old, new):
    old_lines = old.splitlines(keepends=True)
    result = []
    removed = 0
    for i, line in enumerate(old_lines):
        m = re.fullmatch(r'\t(?:jmp|j) ([^\n]+)\n', line)
        if m and i+1 < len(old_lines) and old_lines[i+1] == m[1]+':\n':
            removed += 1
        else:
            result.append(line)
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
        if not row['target'].startswith('aarch64-') and row['mode'] != 'baseline':
            removed += audit(old, new)
        else:
            assert old == new
        if old != new:
            changes[row['target']] = changes.get(row['target'], 0)+1
    out = {'status': 'passed', 'compilers': r['compilers'], 'cases': len(r['cases']),
           'unchanged_assemblies': r['identical_assemblies'],
           'matching_refusals': r['identical_refusals'], 'expected_changed_assemblies': changes,
           'removed_jumps': removed,
           'note': 'Only allocated/optimized AMD64/RV64 jumps to the next label may be deleted; every other byte preserved. Raw exact comparison reports intended differences. Not a semantic proof.'}
    args.output.write_text(json.dumps(out, indent=2)+'\n')
    print(json.dumps(out))


if __name__ == '__main__':
    main()
