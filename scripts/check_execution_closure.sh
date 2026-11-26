#!/usr/bin/env bash
set -euo pipefail

# Local compiler attributes can disappear from imported metadata after scope exit.
check_sources() {
  lake env lean --run scripts/ExecutionClosure.lean --sources "$@"
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/ExecutionClosureControls.lean" <<'LEAN'
def USize.plantedHostWidth : Nat := System.Platform.numBits

namespace ExecutionClosureControls

def total (n : Nat) : Nat := n

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

def extrinsicRoot (n : Nat) : Nat :=
  WellFounded.extrinsicFix (C := fun _ : Nat => Nat) (fun _ _ => True)
    (fun i recurse => recurse (i + 1) trivial) n

def opaqueRoot (n : Nat) : Nat :=
  WellFounded.opaqueFix₃ (β := fun _ : Nat => Unit) (γ := fun _ _ => Unit)
    (C₃ := fun _ _ _ => Nat) (fun _ _ => True)
    (fun i _ _ recurse => recurse (i + 1) () () trivial) n () ()

theorem sorryDecrease (n : Nat) : n + 1 < n := by sorry
axiom plantedDecrease (n : Nat) : n + 1 < n
theorem wrappedDecrease (n : Nat) : n + 1 < n := plantedDecrease n

def sorryRecursion (n : Nat) : Nat := sorryRecursion (n + 1)
termination_by n
decreasing_by exact sorryDecrease n

def axiomRecursion (n : Nat) : Nat := axiomRecursion (n + 1)
termination_by n
decreasing_by exact wrappedDecrease n

theorem nativeBound : 0 < (#[9] : Array Nat).size := by native_decide
def nativeProofRoot (n : Nat) : Nat :=
  if n == 0 then 0 else (#[9] : Array Nat)[0]'nativeBound

theorem sorryFalse : False := by sorry
axiom plantedFalse : False
theorem wrappedFalse : False := plantedFalse

def sorryRoot (n : Nat) : Nat := if n == 0 then 0 else False.elim sorryFalse
def axiomRoot (n : Nat) : Nat := if n == 0 then 0 else False.elim wrappedFalse

def coreCsimpRoot (xs : List Nat) : List Nat := xs.map (· + 1)

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

cat > "$tmp/SourceText.lean" <<'LEAN'
/- initialize and @[implemented_by replacement] are mentioned in documentation. -/
def message : String := "attribute [csimp] eq"
LEAN

mapfile -d '' backend_sources < <(find LeanCompilerBackend -name '*.lean' -print0)
check_sources LeanCompilerBackend.lean "${backend_sources[@]}" "$tmp/SourceText.lean"
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
  $'extrinsicRoot\timplemented_by\tWellFounded.extrinsicFix → _private.Init.WFExtrinsicFix.0.WellFounded.opaqueFix' \
  $'opaqueRoot\tpartial\tWellFounded.opaqueFix₃' \
  $'nativeProofRoot\tproof axiom\tExecutionClosureControls.nativeBound._native.native_decide.ax_1_1' \
  $'sorryRecursion\tproof axiom\tsorryAx' \
  $'axiomRecursion\tproof axiom\tExecutionClosureControls.plantedDecrease' \
  $'sorryRoot\tproof axiom\tsorryAx' \
  $'axiomRoot\tproof axiom\tExecutionClosureControls.plantedFalse' \
  $'coreCsimpRoot\tcsimp\tList.map → List.mapTR' \
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

lake env lean --run scripts/ExecutionClosure.lean
