#!/usr/bin/env bash
set -euo pipefail

# Local attributes can disappear from imported metadata and their replacements
# can be inlined away. Reserve their spellings throughout backend sources.
check_sources() {
  python3 - "$@" <<'PY'
import re
import sys
from pathlib import Path

forbidden = re.compile(r"\b(csimp|implemented_by|builtin_initialize|initialize)\b")
found = False
for argument in sys.argv[1:]:
    path = Path(argument)
    files = sorted(path.rglob("*.lean")) if path.is_dir() else [path]
    for file in files:
        for number, line in enumerate(file.read_text().splitlines(), 1):
            if match := forbidden.search(line):
                print(f"{file}:{number}: reserved execution attribute or command {match[0]}", file=sys.stderr)
                found = True
sys.exit(int(found))
PY
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/ExecutionClosureControls.lean" <<'LEAN'
def USize.plantedHostWidth : Nat := System.Platform.numBits

namespace ExecutionClosureControls

def total (n : Nat) : Nat := n + 1

def whileRoot (n : Nat) : Nat := Id.run do
  let mut i := 0
  while i < n do
    i := i + 1
  return i

partial def partialLoop (n : Nat) : Nat := partialLoop (n + 1)
def partialRoot (n : Nat) : Nat := partialLoop n

unsafe def unsafeStep (n : Nat) : Nat := n + 1
unsafe def unsafeRoot (n : Nat) : Nat := unsafeStep n

def replacement (n : Nat) : Nat := n + 1
@[implemented_by replacement] def replaced (n : Nat) : Nat := n + 1
def implementedByRoot (n : Nat) : Nat := replaced n

@[extern "lcb_planted_extern"] def nativeStep (n : Nat) : Nat := n + 1
def externRoot (n : Nat) : Nat := nativeStep n

def ordinary (n : Nat) : Nat := n + 1
@[csimp] theorem rewrite : ordinary = replacement := rfl
def csimpRoot (n : Nat) : Nat := ordinary n

def stringOrderRoot (a b : String) : Ordering := compare a b
def hostRoot : Nat := USize.plantedHostWidth
def wordRoot (n : Nat) : Nat := (USize.ofNat n).toNat

end ExecutionClosureControls
LEAN
cat > "$tmp/LocalRewrite.lean" <<'LEAN'
def before (n : Nat) : Nat := n + 1
def after (n : Nat) : Nat := n + 1
theorem eq : before = after := rfl
section
attribute [local «csimp»] eq
def locallyRewritten (n : Nat) : Nat := before n
end
LEAN

check_sources LeanCompilerBackend.lean LeanCompilerBackend
lake env lean --run scripts/ExecutionClosure.lean

lake env lean --root="$tmp" -o "$tmp/ExecutionClosureControls.olean" "$tmp/ExecutionClosureControls.lean"
lake env lean --root="$tmp" -o "$tmp/LocalRewrite.olean" "$tmp/LocalRewrite.lean"
export LEAN_PATH="$tmp:$(lake env printenv LEAN_PATH)"
control_module=ExecutionClosureControls
lake env lean --run scripts/ExecutionClosure.lean "$control_module" "$control_module.total"
# Check the complete diagnostic for each planted root. A process crash,
# missing declaration, or rejection of a different root cannot pass.
for control in \
  $'whileRoot\twhile\tLean.Loop.forIn' \
  $'partialRoot\tpartial\tExecutionClosureControls.partialLoop' \
  $'unsafeRoot\tunsafe\tExecutionClosureControls.unsafeStep' \
  $'implementedByRoot\timplemented_by\tExecutionClosureControls.replaced → ExecutionClosureControls.replacement' \
  $'externRoot\textern\tExecutionClosureControls.nativeStep' \
  $'csimpRoot\tcsimp\tExecutionClosureControls.ordinary → ExecutionClosureControls.replacement' \
  $'stringOrderRoot\textern\tString.compare' \
  $'hostRoot\tstage effect\tSystem.Platform.numBits' \
  $'wordRoot\thost word size\tUSize.ofNat'; do
  IFS=$'\t' read -r root kind declaration <<< "$control"
  status=0
  lake env lean --run scripts/ExecutionClosure.lean "$control_module" "$control_module.$root" \
    >"$tmp/$root.log" 2>&1 || status=$?
  if [[ "$status" != 1 ]] || ! grep -Fq "$kind"$'\t'"$declaration"$'\t' "$tmp/$root.log"; then
    cat "$tmp/$root.log" >&2
    echo "execution closure control failed: $root (exit $status)" >&2
    exit 1
  fi
  echo "execution closure control rejected: $root"
done
if check_sources "$tmp/LocalRewrite.lean" >"$tmp/local.log" 2>&1 ||
    ! grep -Fq 'reserved execution attribute or command csimp' "$tmp/local.log"; then
  cat "$tmp/local.log" >&2
  echo "execution closure control failed: local rewrite" >&2
  exit 1
fi
echo "execution closure control rejected: local rewrite"
