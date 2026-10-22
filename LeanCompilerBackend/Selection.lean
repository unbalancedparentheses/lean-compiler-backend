/- Shared conservative instruction-selection queries on validated SSA. -/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Selection

def useCounts (f : Function) : Std.HashMap String Nat := Id.run do
  let add := fun (counts : Std.HashMap String Nat) (v : Operand) => match v with
    | .temporary name => counts.insert name ((counts[name]?).getD 0 + 1)
    | _ => counts
  let mut counts := {}
  for b in f.blocks do
    for phi in b.phis do
      for (_,v) in phi.incoming do counts := add counts v
    for statement in b.instructions do
      counts := statement.operands.foldl add counts
    match b.terminator with
    | .ret (some v) | .branch v .. => counts := add counts v
    | _ => pure ()
  return counts

/-- A final integer comparison whose sole whole-function use is this branch. -/
def branchComparison (uses : Std.HashMap String Nat) (block : Block)
    : Option (Comparison × Width × Operand × Operand) :=
  match block.instructions[block.instructions.size-1]?, block.terminator with
  | some (.assign inst), .branch (.temporary name) _ _ =>
    match inst.operation with
    | .compare op width a b =>
      if inst.destination == name && (uses[name]?).getD 0 == 1 then some (op, width, a, b)
      else none
    | _ => none
  | _, _ => none

end LeanCompilerBackend.Selection
