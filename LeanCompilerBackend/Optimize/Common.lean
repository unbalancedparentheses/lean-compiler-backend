/- Conservative dominance-aware common integer-expression elimination. -/
import LeanCompilerBackend.CFG
import LeanCompilerBackend.Liveness
import LeanCompilerBackend.Optimize.Cleanup

namespace LeanCompilerBackend.Optimize.Common

deriving instance BEq, Hashable for Operand
deriving instance Hashable for Width, Binary, Unary, Comparison

/-- The pure expressions CSE may merge, compared structurally. -/
private inductive Expression where
  | cast (value : Operand)
  | unary (op : Unary) (value : Operand)
  | binary (op : Binary) (lhs rhs : Operand)
  | compare (op : Comparison) (operandWidth : Width) (lhs rhs : Operand)
  deriving BEq, Hashable

private structure Key where
  width : Width
  floating : Bool
  expression : Expression
  deriving BEq, Hashable

private def key (i : Instruction) : Option Key := do
  let expression ← match i.operation with
    | .cast v => some (Expression.cast v)
    | .unary op v => some (.unary op v)
    | .binary op a b => some (.binary op a b)
    | .compare op w a b => some (.compare op w a b)
    | _ => none
  if i.operation.operands.any (fun v => match v with | .symbol _ | .threadSymbol _ => true | _ => false) then
    none
  else
    -- Structural equality includes operand order and comparison width.
    -- Result width/class prevent merging truncations or integer/FP bit casts.
    some { width := i.width, floating := i.floating, expression }

private def rewrite (aliases : Std.HashMap String String) : Operand → Operand
  | .temporary name => (aliases[name]?).map Operand.temporary |>.getD (.temporary name)
  | other => other

private def reversePostorder (graph : CFG.Graph) : List Nat := Id.run do
  let mut seen : Std.HashSet Nat := {}
  let mut pending := [(0, false)]
  let mut order := []
  while !pending.isEmpty do
    let (node, expanded) := pending.head!
    pending := pending.tail
    if expanded then
      order := node :: order
    else if !seen.contains node then
      seen := seen.insert node
      pending := (graph.successors[node]!.toList.map (·, false)) ++ (node, true) :: pending
  return order

/-- Reuse only an already encountered, dominating definition of an identical
    pure expression. No memory, floating arithmetic, division, TLS or call CSE.
    Reuse a value already live here, or a definition within eight visited
    instructions. The small window retains nearby folding opportunities without
    resurrecting thousands of dead address calculations in large copies.
    This is a profitability heuristic, not a register-pressure proof.
    Unreachable regions are left unchanged if invoked without CFG cleanup. -/
def eliminate (f : Function) : Except String Function := do
  let live ← Liveness.analyze f
  let doms ← CFG.dominators live.graph
  let mut candidates : Std.HashMap Key (List (Nat × Nat × String)) := {}
  let mut ordinal := 0
  let mut aliases : Std.HashMap String String := {}
  let mut blocks := f.blocks
  for index in reversePostorder doms.graph do
    let b := blocks[index]!
    let mut instructions := #[]
    for position in [:b.instructions.size] do
      let statement := b.instructions[position]!
      match statement with
      | .assign original =>
        let i := {original with operation := Cleanup.mapOperation (rewrite aliases) original.operation}
        let mut operation := i.operation
        if let some expression := key i then
          let available := (candidates[expression]?).getD []
          let profitable := fun (_, encountered, name) =>
            ordinal - encountered <= 8 || live.contains live.before[index]![position]! name
          if let some (_, _, name) := available.find? (fun candidate =>
              ((doms.sets[index]! >>> candidate.1) &&& 1) == 1 && profitable candidate) then
            operation := .copy (.temporary name)
            -- Representatives are never aliases, so one lookup is sufficient.
            aliases := aliases.insert i.destination name
          else
            -- A dead, distant candidate cannot become live later in this same
            -- block. Drop it to avoid quadratic scans of repeated expressions.
            let available := available.filter (fun candidate => candidate.1 != index || profitable candidate)
            candidates := candidates.insert expression ((index, ordinal, i.destination) :: available)
        instructions := instructions.push (.assign {i with operation})
      | other => instructions := instructions.push other
      ordinal := ordinal + 1
    blocks := blocks.set! index {b with instructions}
  pure (Cleanup.rewriteOperands {f with blocks} (rewrite aliases))

end LeanCompilerBackend.Optimize.Common
