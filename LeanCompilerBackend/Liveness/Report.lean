/- Diagnostic SSA facts and liveness results, for independent test oracles. -/
import LeanCompilerBackend.Allocation

namespace LeanCompilerBackend.Liveness

private def jsonString (value : String) : String :=
  (value.foldl (init := "\"") fun out c =>
    match c with
    | '"' => out ++ "\\\""
    | '\\' => out ++ "\\\\"
    | '\n' => out ++ "\\n"
    | '\r' => out ++ "\\r"
    | _ =>
      let n := c.toNat
      if n < 32 then
        (out ++ "\\u00").push (n / 16).digitChar |>.push (n % 16).digitChar
      else out.push c).push '"'

private def jsonArray (render : α → String) (values : Array α) : String :=
  "[" ++ String.intercalate "," (values.toList.map render) ++ "]"

private def jsonObject (fields : List (String × String)) : String :=
  "{" ++ String.intercalate "," (fields.map fun (key, value) => jsonString key ++ ":" ++ value) ++ "}"

private def jsonOptionalString (value : Option String) : String :=
  value.elim "null" jsonString

private def temporary : Operand → Option String
  | .temporary name => some name | _ => none
private def useNames (values : List Operand) : Array String := (values.filterMap temporary).toArray

private def blockReport (f : Function) (r : Result) (node : Nat) : String :=
  let b := f.blocks[node]!
  let phiReport := fun p : Phi =>
    let incoming := jsonArray (fun (label, value) => jsonObject [
      ("predecessor", jsonString label), ("use", jsonOptionalString (temporary value))]) p.incoming
    jsonObject [("definition", jsonString p.destination), ("incoming", incoming)]
  let instructionReport := fun s : Statement => jsonObject [
    ("call", toString s.callSite.isSome), ("definition", jsonOptionalString (s.definition.map (·.1))),
    ("uses", jsonArray jsonString (useNames s.operands))]
  let edgeReport := fun (target, set) => jsonObject [
    ("live", jsonArray jsonString (r.members set)), ("target", jsonString f.blocks[target]!.label)]
  jsonObject [
    ("before", jsonArray (fun set => jsonArray jsonString (r.members set)) r.before[node]!),
    ("edges", jsonArray edgeReport (r.graph.successors[node]!.zip r.edges[node]!)),
    ("instructions", jsonArray instructionReport b.instructions), ("label", jsonString b.label),
    ("liveIn", jsonArray jsonString (r.members r.liveIn[node]!)),
    ("liveOut", jsonArray jsonString (r.members r.liveOut[node]!)),
    ("phis", jsonArray phiReport b.phis),
    ("successors", jsonArray jsonString b.terminator.successors.toArray),
    ("terminatorUses", jsonArray jsonString (useNames (terminatorOperands b.terminator)))]

/-- Versioned diagnostic report; this is not a certified artifact. -/
def report (f : Function) (r : Result) : String := jsonObject [
  ("blocks", jsonArray (blockReport f r) (List.range f.blocks.size).toArray),
  ("function", jsonString f.name), ("schema", "1"), ("values", jsonArray jsonString r.names)]

def allocationReport (f : Function) (r : Result) (result : Allocation.Plan) : String :=
  jsonObject [
    ("colorCount", toString result.colorCount), ("colors", jsonArray toString result.colors),
    ("liveness", report f r), ("parameters", jsonArray (fun p => jsonString p.name) f.parameters)]

end LeanCompilerBackend.Liveness
