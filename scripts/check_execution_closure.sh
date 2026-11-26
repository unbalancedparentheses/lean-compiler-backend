#!/usr/bin/env bash
set -euo pipefail

# Check reserved source commands independently of the compiler rewrite journal.
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
cat > "$tmp/UnprovedRewriteControl.lean" <<'LEAN'
import ExecutionClosureControls
namespace ExecutionClosureControls
def unprovedBefore (n : Nat) : Nat := n
@[csimp] axiom unprovedRewrite : unprovedBefore = replacement
def unprovedCsimpRoot (n : Nat) : Nat := unprovedBefore n
end ExecutionClosureControls
LEAN

cat > "$tmp/AxiomRewriteControl.lean" <<'LEAN'
import ExecutionClosureControls
namespace ExecutionClosureControls
def axiomBefore (n : Nat) : Nat := n
axiom rewriteEquality : axiomBefore = replacement
@[csimp] theorem axiomRewrite : axiomBefore = replacement := rewriteEquality
def axiomCsimpRoot (n : Nat) : Nat := axiomBefore n
end ExecutionClosureControls
LEAN

cat > "$tmp/SorryRewriteControl.lean" <<'LEAN'
import ExecutionClosureControls
namespace ExecutionClosureControls
def sorryBefore (n : Nat) : Nat := n
@[csimp] theorem sorryRewrite : sorryBefore = replacement := by sorry
def sorryCsimpRoot (n : Nat) : Nat := sorryBefore n
end ExecutionClosureControls
LEAN

cat > "$tmp/ExternRewriteControl.lean" <<'LEAN'
import ExecutionClosureControls
namespace ExecutionClosureControls
def beforeExtern (n : Nat) : Nat := n + 1
@[csimp] theorem externRewrite : beforeExtern = nativeStep := rfl
def externCsimpRoot (n : Nat) : Nat := beforeExtern n
end ExecutionClosureControls
LEAN

# This reproduces a local registration made by the elaborator, with no
# attribute syntax for a source guard to see.
cat > "$tmp/Probe.lean" <<'LEAN'
import Lean
open Lean
namespace Probe
def before (n : Nat) : Nat := n
def after (n : Nat) : Nat := n + 1
theorem bad : before = after := by sorry
section
run_cmd Elab.Command.liftCoreM (Compiler.CSimp.add `Probe.bad .local)
def root (n : Nat) : Nat := before n
end
#eval root 10
example : root 10 = 10 := rfl
end Probe
LEAN

# Register the same false rewrite only in the stock frontend.
cat > "$tmp/StockOnlyRewrite.lean" <<'LEAN'
import Lean
open Lean
namespace StockOnlyRewrite
def before (n : Nat) : Nat := n
def after (n : Nat) : Nat := n + 1
theorem bad : before = after := by sorry
section
run_cmd do
  let some stock ← IO.getEnv "LCB_CONTROL_STOCK_LEAN" | throwError "missing stock Lean path"
  if (← IO.FS.realPath (← IO.appPath)).toString == stock then
    Elab.Command.liftCoreM (Compiler.CSimp.add `StockOnlyRewrite.bad .local)
def root (n : Nat) : Nat := before n
end
#eval root 10
example : root 10 = 10 := rfl
end StockOnlyRewrite
LEAN

cat > "$tmp/CleanControl.lean" <<'LEAN'
def cleanRoot (n : Nat) : Nat := n
LEAN

cat > "$tmp/CustomPass.lean" <<'LEAN'
import Lean
open Lean Compiler.LCNF
namespace CustomPass
@[noinline] def before (n : Nat) : Nat := n
@[noinline] def after (n : Nat) : Nat := n + 1
@[cpass] meta def installer : PassInstaller :=
  .installAtEnd .base <| .mkPerDeclaration `CustomPass.replace .base fun decl => do
    if let .code (.let binding tail) := decl.value then
      if let .const `CustomPass.before us args _ := binding.value then
        return { decl with value := .code (.let { binding with value := .const `CustomPass.after us args } tail) }
    return decl
def root (n : Nat) : Nat := before n
example : root 10 = 10 := rfl
end CustomPass
LEAN

cat > "$tmp/ImportedPass.lean" <<'LEAN'
import CustomPass
def importedPassRoot (n : Nat) : Nat := CustomPass.before n
example : importedPassRoot 10 = 10 := rfl
LEAN

cat > "$tmp/ProvedLocalRewrite.lean" <<'LEAN'
import Lean
open Lean
namespace ProvedLocalRewrite
def before (n : Nat) : Nat := n + 1
def after (n : Nat) : Nat := n + 1
theorem same : before = after := rfl
section
run_cmd Elab.Command.liftCoreM (Compiler.CSimp.add `ProvedLocalRewrite.same .local)
def root (n : Nat) : Nat := before n
end
end ProvedLocalRewrite
LEAN

cat > "$tmp/ImportedRewrite.lean" <<'LEAN'
import Probe
def importedRoot (n : Nat) : Nat := Probe.root n
LEAN

cat > "$tmp/ValueInit.lean" <<'LEAN'
def setValue : IO Nat := do
  IO.println "planted value initializer"
  pure 42
@[init setValue] def value : Nat := 0
def root (n : Nat) : Nat := value + n
example : root 0 = 0 := rfl
LEAN

cat > "$tmp/StandaloneInit.lean" <<'LEAN'
@[builtin_init] def action : IO Unit := IO.println "planted standalone initializer"
def root (n : Nat) : Nat := n
LEAN

cat > "$tmp/FormatControl.lean" <<'LEAN'
def formatted (n : Nat) : String := reprStr n
LEAN

cat > "$tmp/SourceText.lean" <<'LEAN'
/- initialize and @[implemented_by replacement] are mentioned in documentation. -/
def message : String := "attribute [csimp] eq"
def before (n : Nat) : Nat := n
def after (n : Nat) : Nat := n
@[csimp] theorem eq : before = after := rfl
LEAN

mapfile -d '' backend_sources < <(find LeanCompilerBackend -name '*.lean' -print0)
check_sources LeanCompilerBackend.lean "${backend_sources[@]}" "$tmp/SourceText.lean"
provenance_sysroot="$tmp/toolchain"
stock_prefix=$(lake env lean --print-prefix)
stock_lean="$(realpath "$stock_prefix/bin/lean")"
official_path=$(lake env printenv LEAN_PATH)

# Use the same Lake configuration and source bytes with a fresh artifact tree.
# LeanIR is intentionally unavailable in the instrumented sysroot: a module
# that postpones code generation would bypass the recorder, so it must fail.
audit="$tmp/audit"
mkdir "$audit"
cp -R lakefile.toml lake-manifest.json lean-toolchain LeanCompilerBackend.lean LeanCompilerBackend "$audit/"
"$stock_lean" --run scripts/ExecutionClosure.lean --imports "$audit"
bash scripts/prepare_provenance_compiler.sh "$provenance_sysroot" "$stock_prefix"
(
  cd "$audit"
  LAKE_OVERRIDE_LEAN=true LEAN_SYSROOT="$provenance_sysroot" \
    lake --no-cache build +LeanCompilerBackend:olean +LeanCompilerBackend.Verified.Codec:olean
)
audit_build="$audit/.lake/build"
LEAN_PATH="$audit_build/lib/lean" "$stock_lean" --run scripts/ExecutionClosure.lean \
  --compare .lake/build/lib/lean .lake/build/ir "$audit_build/lib/lean" "$audit_build/ir"

compile_control() (
  cd "$tmp"
  LEAN_SYSROOT="$provenance_sysroot" LEAN_PATH="$tmp:$official_path" \
    "$provenance_sysroot/bin/lean" "$1.lean" -o "$1.olean" -c "$1.c"
)
stock_controls="$tmp/stock-controls"
mkdir "$stock_controls"
compile_stock_control() (
  cd "$tmp"
  LEAN_PATH="$stock_controls:$official_path" "$stock_lean" "$1.lean" \
    -o "$stock_controls/$1.olean" -c "$stock_controls/$1.c"
)
compare_control() {
  LEAN_PATH="$tmp" "$stock_lean" --run scripts/ExecutionClosure.lean \
    --compare "$stock_controls" "$stock_controls" "$tmp" "$tmp" "$@"
}
compile_control ExecutionClosureControls
compile_control SorryRewriteControl
compile_control AxiomRewriteControl
compile_control UnprovedRewriteControl
compile_control ExternRewriteControl
compile_control Probe >"$tmp/probe-build.log"
grep -Fx 11 "$tmp/probe-build.log"
compile_control ProvedLocalRewrite
compile_control ImportedRewrite
compile_control ValueInit
compile_control StandaloneInit
compile_control FormatControl
compile_control CleanControl
# Both frontends see one input and one condition. Only the stock executable
# satisfies the condition. The journal alone accepts the instrumented output.
LCB_CONTROL_STOCK_LEAN="$stock_lean" compile_stock_control StockOnlyRewrite >"$tmp/stock-only-stock.log"
LCB_CONTROL_STOCK_LEAN="$stock_lean" compile_control StockOnlyRewrite >"$tmp/stock-only-audit.log"
grep -Fx 11 "$tmp/stock-only-stock.log"
grep -Fx 10 "$tmp/stock-only-audit.log"
status=0
compare_control StockOnlyRewrite StockOnlyRewrite.root >"$tmp/stock-only-gate.log" 2>&1 || status=$?
if [[ $status != 1 ]] ||
    ! grep -Fq 'execution audit build mismatch for StockOnlyRewrite: generated C differs from stock Lean' \
      "$tmp/stock-only-gate.log"; then
  cat "$tmp/stock-only-gate.log" >&2
  exit 1
fi
echo "execution closure control rejected: stock-only local rewrite (C mismatch)"
LEAN_PATH="$tmp" "$stock_lean" --run scripts/ExecutionClosure.lean \
  StockOnlyRewrite StockOnlyRewrite.root

compile_stock_control CleanControl
"$stock_lean" --run scripts/ExecutionClosure.lean --imports "$tmp" CleanControl
compare_control CleanControl cleanRoot
echo "execution closure control accepted: clean module"

compile_stock_control CustomPass
compile_stock_control ImportedPass
compile_control CustomPass
compile_control ImportedPass
for control in 'CustomPass CustomPass.root' 'ImportedPass importedPassRoot'; do
  read -r module root <<< "$control"
  status=0
  "$stock_lean" --run scripts/ExecutionClosure.lean --imports "$tmp" "$module" \
    >"$tmp/$module-imports.log" 2>&1 || status=$?
  if [[ $status != 1 ]] || ! grep -Fxq 'execution audit forbidden import Lean in CustomPass' \
      "$tmp/$module-imports.log"; then
    cat "$tmp/$module-imports.log" >&2
    exit 1
  fi
  # Confirm that the pass rewrote the root in both generated C files.
  symbol="l_${root//./_}"
  for c in "$stock_controls/$module.c" "$tmp/$module.c"; do
    sed -n "/^LEAN_EXPORT lean_object\* $symbol(.*){/,/^}/p" "$c" |
      grep -F ' = l_CustomPass_after(' >/dev/null
  done
  LEAN_PATH="$tmp" "$stock_lean" --run scripts/ExecutionClosure.lean "$module" "$root"
  status=0
  compare_control "$module" "$root" >"$tmp/$module-gate.log" 2>&1 || status=$?
  if [[ $status != 1 ]] || ! grep -Fq $'toolchain import outside Init and Std\tLean' "$tmp/$module-gate.log"; then
    cat "$tmp/$module-gate.log" >&2
    exit 1
  fi
  echo "execution closure control rejected: $module (Lean import boundary)"
done

export LEAN_PATH="$tmp:$official_path"
control_module=ExecutionClosureControls
lake env lean --run scripts/ExecutionClosure.lean "$control_module" "$control_module.total"
lake env lean --run scripts/ExecutionClosure.lean "$control_module" \
  "$control_module.csimpRoot" "$control_module.coreCsimpRoot" >"$tmp/proved.log"
grep -F 'ExecutionClosureControls.ordinary → ExecutionClosureControls.replacement by ExecutionClosureControls.rewrite' "$tmp/proved.log"
grep -F 'List.map → List.mapTR by List.map_eq_mapTR' "$tmp/proved.log"
# Check the complete diagnostic for each planted root. A process crash,
# missing declaration, or rejection of a different root cannot pass.
for control in \
  $'whileRoot\twhile\tLean.Loop.forIn' \
  $'partialRoot\tpartial\tExecutionClosureControls.partialLoop' \
  $'unsafeRoot\tunsafe\tExecutionClosureControls.unsafeStep' \
  $'implementedByRoot\timplemented_by\tExecutionClosureControls.replaced → ExecutionClosureControls.replacement' \
  $'externRoot\textern\tExecutionClosureControls.nativeStep' \
  $'sorryCsimpRoot\tproof axiom\tsorryAx\tfrom ExecutionClosureControls.sorryRewrite' \
  $'axiomCsimpRoot\tproof axiom\tExecutionClosureControls.rewriteEquality\tfrom ExecutionClosureControls.axiomRewrite' \
  $'unprovedCsimpRoot\tcsimp theorem\tExecutionClosureControls.unprovedRewrite' \
  $'externCsimpRoot\textern\tExecutionClosureControls.nativeStep' \
  $'stringOrderRoot\textern\tString.compare' \
  $'hostRoot\tstage effect\tSystem.Platform.numBits' \
  $'extrinsicRoot\timplemented_by\tWellFounded.extrinsicFix → _private.Init.WFExtrinsicFix.0.WellFounded.opaqueFix' \
  $'opaqueRoot\tpartial\tWellFounded.opaqueFix₃' \
  $'nativeProofRoot\tproof axiom\tExecutionClosureControls.nativeBound._native.native_decide.ax_1_1' \
  $'sorryRecursion\tproof axiom\tsorryAx' \
  $'axiomRecursion\tproof axiom\tExecutionClosureControls.plantedDecrease' \
  $'sorryRoot\tproof axiom\tsorryAx' \
  $'axiomRoot\tproof axiom\tExecutionClosureControls.plantedFalse' \
  $'wordRoot\thost word size\tUSize.ofNat'; do
  IFS=$'\t' read -r root kind declaration origin <<< "$control"
  case "$root" in
    sorryCsimpRoot) module=SorryRewriteControl ;;
    axiomCsimpRoot) module=AxiomRewriteControl ;;
    unprovedCsimpRoot) module=UnprovedRewriteControl ;;
    externCsimpRoot) module=ExternRewriteControl ;;
    *) module=$control_module ;;
  esac
  status=0
  lake env lean --run scripts/ExecutionClosure.lean "$module" "$control_module.$root" \
    >"$tmp/$root.log" 2>&1 || status=$?
  diagnostic="$kind"$'\t'"$declaration"$'\t'"$origin"
  if [[ "$status" != 1 ]] || ! grep -Fq "$diagnostic" "$tmp/$root.log"; then
    cat "$tmp/$root.log" >&2
    echo "execution closure control failed: $root (exit $status)" >&2
    exit 1
  fi
  echo "execution closure control rejected: $root"
done
check_sources "$tmp/Probe.lean"
for invocation in 'Probe Probe.root' 'ImportedRewrite importedRoot'; do
  read -r module root <<< "$invocation"
  status=0
  lake env lean --run scripts/ExecutionClosure.lean "$module" "$root" \
    >"$tmp/local.log" 2>&1 || status=$?
  if [[ $status != 1 ]] ||
      ! grep -Fq $'proof axiom\tsorryAx\tfrom Probe.bad' "$tmp/local.log"; then
    cat "$tmp/local.log" >&2
    echo "execution closure control failed: elaborator-registered local rewrite ($module)" >&2
    exit 1
  fi
  echo "execution closure control rejected: elaborator-registered local rewrite ($module)"
done
lake env lean --run scripts/ExecutionClosure.lean ProvedLocalRewrite ProvedLocalRewrite.root \
  >"$tmp/proved-local.log"
grep -F 'ProvedLocalRewrite.before → ProvedLocalRewrite.after by ProvedLocalRewrite.same' "$tmp/proved-local.log"

for control in $'ValueInit\tinit\tvalue\tsetValue' $'StandaloneInit\tbuiltin_init\taction'; do
  IFS=$'\t' read -r module attr decl action <<< "$control"
  if check_sources "$tmp/$module.lean" >"$tmp/$module-source.log" 2>&1 ||
      ! grep -Fq "reserved execution attribute or command $attr" "$tmp/$module-source.log"; then
    cat "$tmp/$module-source.log" >&2
    exit 1
  fi
  status=0
  lake env lean --run scripts/ExecutionClosure.lean "$module" root \
    >"$tmp/$module-audit.log" 2>&1 || status=$?
  diagnostic=$'initializer\t'"$attr"$'\t'"$decl"$'\t'"$action"
  if [[ $status != 1 ]] || ! grep -Fq "$diagnostic" "$tmp/$module-audit.log"; then
    cat "$tmp/$module-audit.log" >&2
    exit 1
  fi
  echo "execution closure control rejected: $module initializer"
done

# Even a planted exemption for the outer partial formatter must not hide its
# recursive implementation's callees.
project=$PWD
mkdir "$tmp/scripts"
cp scripts/execution-primitives.tsv "$tmp/scripts/"
printf '%s\n' \
  $'opaque\t_private.Init.Data.Format.Basic.0.Std.Format.be\tplanted outer exemption' \
  $'partial\t_private.Init.Data.Format.Basic.0.Std.Format.be\tplanted outer exemption' \
  >>"$tmp/scripts/execution-primitives.tsv"
status=0
(cd "$tmp"; lean --run "$project/scripts/ExecutionClosure.lean" FormatControl formatted) \
  >"$tmp/format.log" 2>&1 || status=$?
if [[ $status != 1 ]] || ! grep -Fq $'partial\t'"_private.Init.Data.Format.Basic.0.Std.Format.spaceUptoLine'" "$tmp/format.log"; then
  cat "$tmp/format.log" >&2
  exit 1
fi
for primitive in next posOf extract offsetOfPos; do
  grep -Fq $'extern\t'"String.Internal.$primitive"$'\t' "$tmp/format.log"
done
echo "execution closure control rejected: partial formatter and four externs behind an exemption"
