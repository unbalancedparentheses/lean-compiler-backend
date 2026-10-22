"""Digest barriers for host-authored inputs crossing Docker Desktop mounts."""
import hashlib
import os
from pathlib import Path
import subprocess
import time


def host_file(path, root, container):
    path, root = Path(path).resolve(), Path(root).resolve()
    if not path.is_relative_to(root) or not path.is_file(): return
    expected = hashlib.sha256(path.read_bytes()).hexdigest()
    with path.open('rb') as stream: os.fsync(stream.fileno())
    guest = '/work/' + str(path.relative_to(root))
    for _ in range(100):
        result = subprocess.run(['docker', 'exec', container, 'sha256sum', guest], text=True, capture_output=True, timeout=30)
        if result.returncode == 0 and result.stdout.split()[0] == expected: return
        time.sleep(0.05)
    raise AssertionError(f'host/guest input digest did not synchronize: {path}')


def sources(command, root, container):
    # C callers and SSA inputs are host-authored. Assembly is synchronized just
    # after host compilation; guest-generated QBE assembly must not be treated
    # as authoritative host input while its mirror may still be stale.
    output = command[command.index('-o')+1] if '-o' in command else None
    for arg in command[1:]:
        if arg != output and Path(arg).suffix in ['.c', '.h', '.ssa']:
            host_file(arg, root, container)
