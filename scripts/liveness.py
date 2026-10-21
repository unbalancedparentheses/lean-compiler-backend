#!/usr/bin/env python3
"""Independent name-set and path-search oracles for compatibility SSA liveness."""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import tempfile
from fuzz import ROOT, LCB, generate


def edge_uses(blocks):
    result = {}
    for block in blocks:
        for phi in block['phis']:
            for incoming in phi['incoming']:
                key = incoming['predecessor'], block['label']
                result.setdefault(key, set())
                if incoming['use'] is not None:
                    result[key].add(incoming['use'])
    return result


def transfer(block, outgoing):
    live = set(outgoing) | set(block['terminatorUses'])
    points = [live.copy()]
    for instruction in reversed(block['instructions']):
        live.discard(instruction['definition'])
        live.update(instruction['uses'])
        points.append(live.copy())
    points.reverse()
    live.difference_update(phi['definition'] for phi in block['phis'])
    return live, points


def check(report):
    blocks = report['blocks']
    phi_uses = edge_uses(blocks)
    ins = {b['label']: set() for b in blocks}
    outs = {b['label']: set() for b in blocks}
    # Ordinary name sets and complete reverse scans: no production bitset or queue.
    for _ in range((len(report['values'])+1)*len(blocks)+1):
        changed = False
        for block in reversed(blocks):
            name = block['label']
            outgoing = set()
            for target in block['successors']:
                outgoing |= ins[target] | phi_uses.get((name, target), set())
            incoming, _ = transfer(block, outgoing)
            changed |= incoming != ins[name] or outgoing != outs[name]
            ins[name], outs[name] = incoming, outgoing
        if not changed:
            break
    else:
        raise AssertionError('reference liveness did not converge')
    for block in blocks:
        name = block['label']
        assert set(block['liveIn']) == ins[name], (report['function'], name, 'liveIn')
        assert set(block['liveOut']) == outs[name], (report['function'], name, 'liveOut')
        _, points = transfer(block, outs[name])
        assert [set(x) for x in block['before']] == points, (report['function'], name, 'instruction boundaries')
        expected_edges = {target: ins[target] | phi_uses.get((name, target), set()) for target in block['successors']}
        assert {edge['target']: set(edge['live']) for edge in block['edges']} == expected_edges, (name, 'phi edges')


def paths(report):
    """A value is live iff a forward path reaches a use before its definition."""
    blocks = {b['label']: b for b in report['blocks']}
    phi_uses = edge_uses(report['blocks'])
    def reaches_use(value, start):
        pending, seen = [start], set()
        while pending:
            name, position = pending.pop()
            if (name, position) in seen:
                continue
            seen.add((name, position))
            block = blocks[name]
            if position == -1:
                if any(p['definition'] == value for p in block['phis']):
                    continue
                pending.append((name, 0))
            elif position < len(block['instructions']):
                instruction = block['instructions'][position]
                if value in instruction['uses']:
                    return True
                if instruction['definition'] != value:
                    pending.append((name, position+1))
            else:
                if value in block['terminatorUses']:
                    return True
                for target in block['successors']:
                    if value in phi_uses.get((name, target), set()):
                        return True
                    pending.append((target, -1))
        return False
    for name, block in blocks.items():
        for position, actual in [(-1, block['liveIn']), *enumerate(block['before'])]:
            expected = {v for v in report['values'] if reaches_use(v, (name, position))}
            assert set(actual) == expected, (report['function'], name, position, 'path oracle')


CASES = '''function l $diamond(l %x,l %y,w %condition) {
@s
 jnz %condition,@left,@right
@left
 %a =l add %x,1
 jmp @join
@right
 %b =l add %y,2
 jmp @join
@join
 %v =l phi @left %a,@right %b
 ret %v
}
function l $swap(l %x,l %y,w %condition) {
@s
 jmp @loop
@loop
 %a =l phi @s %x,@loop %b
 %b =l phi @s %y,@loop %a
 jnz %condition,@loop,@done
@done
 ret %a
}
function l $call_live(l %x,l %fn,l %p) {
@s
 %r =l call %fn(l %x)
 storel %r,%p
 %sum =l add %x,%r
 ret %sum
}
function l $disconnected(l %x) {
@s
 ret %x
@dead
 %a =l phi @dead %b
 %b =l add %a,1
 jmp @dead
}
'''


def reports(source):
    result = subprocess.run([LCB, '--liveness', source], capture_output=True, text=True, timeout=120)
    assert result.returncode == 0, (source, result.stderr)
    return [json.loads(line) for line in result.stdout.splitlines()]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native', action='store_true', help='accepted for the shared check runner; analysis is host-independent')
    ap.parse_args()
    functions = points = 0
    with tempfile.TemporaryDirectory(prefix='lcb-liveness-') as directory:
        source = Path(directory)/'cases.ssa'
        # Keep generated function names unique across seeds.
        generated = '\n'.join(f.source().replace('$'+f.name+'(', f'$generated_{seed}(')
                              for seed in range(16) for f in generate(seed, 1, 8, True))
        source.write_text(CASES+generated)
        small = reports(source)
        for report in small:
            check(report)
            paths(report)
        diamond = small[0]['blocks']
        assert set(diamond[1]['edges'][0]['live']) == {'a'}
        assert set(diamond[2]['edges'][0]['live']) == {'b'}
        assert set(diamond[3]['liveIn']) == set()
        assert len(small[3]['blocks']) == 1, 'compatibility input must prune the disconnected loop'
        call = small[2]['blocks'][0]
        assert set(call['before'][0]) == {'x', 'fn', 'p'}
        assert set(call['before'][1]) == {'x', 'r', 'p'}
        damaged = copy.deepcopy(small[0])
        damaged['blocks'][1]['edges'][0]['live'].append('b')
        try:
            check(damaged)
        except AssertionError:
            pass
        else:
            raise AssertionError('wrong-edge phi corruption was not detected')
        functions += len(small)
        fixtures = 0
        for source in sorted((ROOT/'third_party/qbe/test').glob('*.ssa')):
            if source.name == 'dark.ssa':
                rejected = subprocess.run([LCB, '--liveness', source], capture_output=True, text=True)
                assert rejected.returncode != 0 and 'argument count' in rejected.stderr, rejected.stderr
                continue
            for report in reports(source):
                check(report)
                functions += 1
                points += sum(len(b['before']) for b in report['blocks'])
            fixtures += 1
    print(f'liveness: {fixtures} original QBE fixtures, {functions} functions, {points} upstream instruction boundaries; set and path oracles, phi swaps/calls/unreachable normalization and wrong-edge corruption passed', flush=True)


if __name__ == '__main__':
    main()
