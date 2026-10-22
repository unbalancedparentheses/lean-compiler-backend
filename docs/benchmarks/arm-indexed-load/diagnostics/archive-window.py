#!/usr/bin/env python3
"""Archive a completed private mixed-compression window; never runs timing."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work', type=Path, required=True)
parser.add_argument('--name', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[A-Za-z0-9_-]+', args.name), 'name must be a single directory name'
work = args.work.resolve()
report = json.loads((work / 'mixed-timing.json').read_text())
provenance = json.loads((work / 'provenance.json').read_text())[-1]
assert report['status'] == 'completed'
assert len(report['samples']) == len(report['labels']) * report['samples_requested']
assert report['sink_agreement'] == 'all labels/rounds'
assert provenance['stage'] == 'after_mixed_timing' and provenance['status'] == 'passed'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for name, digest in provenance['reports'].items():
    assert sha(work / name) == digest, name
files = ['mixed-timing.json', 'mixed-timing.log', 'provenance.json', 'manifest.json',
         'correctness.json', 'bindings.json', 'mixed-protocol.json', 'mixed_probe.py',
         'mixed_time.py', 'caller.c', 'probe.py', 'prepare.py']
assert all((work / name).is_file() for name in files)
destination = work / args.name
destination.mkdir()  # Refuse to overwrite any existing archive.
for name in files:
    shutil.copy2(work / name, destination / name)
(destination / 'archive-hashes.json').write_text(json.dumps(
    {name: sha(destination / name) for name in files}, indent=2) + '\n')
print(destination)
