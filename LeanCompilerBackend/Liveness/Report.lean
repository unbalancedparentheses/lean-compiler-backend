/- Diagnostic SSA facts and liveness results, for independent test oracles. -/
import Lean
import LeanCompilerBackend.Liveness

namespace LeanCompilerBackend.Liveness
open Lean

private def temporary : Operand → Option String
  | .temporary name => some name | _ => none
private def useNames (values : List Operand) : Array String := (values.filterMap temporary).toArray

private def blockReport (f : Function) (r : Result) (node : Nat) : Json :=
  let b := f.blocks[node]!
  let phis := b.phis.map fun p =>
    let incoming := p.incoming.map fun (label, value) => Json.mkObj [
      ("predecessor", toJson label), ("use", toJson (temporary value))]
    Json.mkObj [("definition", toJson p.destination), ("incoming", Json.arr incoming)]
  let instructions := b.instructions.map fun s => Json.mkObj [
    ("definition", toJson (s.definition.map (·.1))), ("uses", toJson (useNames s.operands)),
    ("call", toJson s.callSite.isSome)]
  let edges := (r.graph.successors[node]!.zip r.edges[node]!).map fun (target, set) =>
    Json.mkObj [("target", toJson f.blocks[target]!.label), ("live", toJson (r.members set))]
  Json.mkObj [
    ("label", toJson b.label), ("phis", Json.arr phis), ("instructions", Json.arr instructions),
    ("terminatorUses", toJson (useNames (terminatorOperands b.terminator))),
    ("successors", toJson b.terminator.successors),
    ("liveIn", toJson (r.members r.liveIn[node]!)),
    ("liveOut", toJson (r.members r.liveOut[node]!)),
    ("before", Json.arr (r.before[node]!.map (fun set => toJson (r.members set)))),
    ("edges", Json.arr edges)]

/-- Versioned diagnostic report; this is not a certified artifact. -/
def report (f : Function) (r : Result) : Json := Json.mkObj [
  ("schema", toJson (1 : Nat)), ("function", toJson f.name), ("values", toJson r.names),
  ("blocks", Json.arr ((List.range f.blocks.size).toArray.map (blockReport f r)))]

end LeanCompilerBackend.Liveness
