/- Conservative dominance-aware common integer-expression elimination. -/
import LeanCompilerBackend.CFG
import LeanCompilerBackend.Optimize.Cleanup

namespace LeanCompilerBackend.Optimize.Common

private def key (i : Instruction) : Option String := do
  match i.operation with
  | .cast _ | .unary .. | .binary .. | .compare .. => pure ()
  | _ => none
  if i.operation.operands.any (fun v => match v with | .symbol _ | .threadSymbol _ => true | _ => false) then
    none
  else
    -- Structural constructor spelling includes operand order and comparison width.
    -- Result width/class prevent merging truncations or integer/FP bit casts.
    some s!"{reprStr i.width}|{i.floating}|{reprStr i.operation}"

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
    Unreachable regions are left unchanged if invoked without CFG cleanup. -/
def eliminate (f : Function) : Except String Function := do
  let doms ← CFG.dominators (← CFG.build f)
  let mut candidates : Std.HashMap String (List (Nat × String)) := {}
  let mut aliases : Std.HashMap String String := {}
  let mut blocks := f.blocks
  for index in reversePostorder doms.graph do
    let b := blocks[index]!
    let mut instructions := #[]
    for statement in b.instructions do
      match statement with
      | .assign original =>
        let i := {original with operation := Cleanup.mapOperation (rewrite aliases) original.operation}
        let mut operation := i.operation
        if let some expression := key i then
          let available := (candidates[expression]?).getD []
          if let some (_, name) := available.find? (fun (source, _) =>
              ((doms.sets[index]! >>> source) &&& 1) == 1) then
            operation := .copy (.temporary name)
            -- Representatives are never aliases, so one lookup is sufficient.
            aliases := aliases.insert i.destination name
          else
            candidates := candidates.insert expression ((index, i.destination) :: available)
        instructions := instructions.push (.assign {i with operation})
      | other => instructions := instructions.push other
    blocks := blocks.set! index {b with instructions}
  pure (Cleanup.rewriteOperands {f with blocks} (rewrite aliases))

end LeanCompilerBackend.Optimize.Common
