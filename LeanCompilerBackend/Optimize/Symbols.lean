/- Common addresses of module-defined, non-TLS data in the optional optimizer. -/
import LeanCompilerBackend.Optimize.Cleanup
import LeanCompilerBackend.SSA

namespace LeanCompilerBackend.Optimize.Symbols

/-- Computing a known module-data address is pure. External and TLS operands stay
    in their original blocks, including their interpreter refusal boundaries.
    Only repeated references qualify; no load/store contents are cached.
    Straight-line functions introduce each address at its first use. Elsewhere,
    bound entry hoisting to eight addresses: this is a profitability heuristic,
    not a register-pressure or preservation proof. -/
def hoist (globals : Array String) (f : Function) : Function := Id.run do
  let some entry := f.blocks[0]? | return f
  let mut counts : Std.HashMap String Nat := {}
  let count := fun (counts : Std.HashMap String Nat) (value : Operand) =>
    match value with
    | .symbol name => counts.insert name ((counts[name]?).getD 0 + 1)
    | _ => counts
  for block in f.blocks do
    for phi in block.phis do
      for (_,value) in phi.incoming do counts := count counts value
    for statement in block.instructions do
      for value in statement.operands do counts := count counts value
    match block.terminator with
    | .ret (some value) | .branch value .. => counts := count counts value
    | _ => pure ()
  let shared := globals.filter (fun name => (counts[name]?).getD 0 >= 3)
  if shared.isEmpty then return f
  let straight := f.blocks.size == 1 && entry.phis.isEmpty && entry.terminator.successors.isEmpty
  -- A large collection of disjoint uses must not keep every address live from
  -- entry. General CFG placement remains separate work; retain the original
  -- expressions when their entry-hoisted set exceeds this conservative budget.
  if !straight && shared.size > 8 then return f
  let instructions := f.blocks.foldl (fun n b => n+b.instructions.size+b.phis.size) 0
  if instructions+shared.size > maxCompatibilityInstructions then return f
  let names := f.locals.map (·.1)
  let namePrefix := SSA.freshNamePrefix "lcb.symbol." names
  let mut replacements : Std.HashMap String String := {}
  let mut copies : Array Statement := #[]
  for i in [:shared.size] do
    let name := namePrefix ++ toString i
    replacements := replacements.insert shared[i]! name
    copies := copies.push (.assign {destination := name, width := .long, operation := .copy (.symbol shared[i]!)})
  let rewritten := Cleanup.rewriteOperands f fun value => match value with
    | .symbol name => (replacements[name]?).map Operand.temporary |>.getD value
    | _ => value
  let first := rewritten.blocks[0]!
  if straight then
    let mut introduced : Std.HashSet String := {}
    let mut instructions := #[]
    let mut offsets := #[]
    for position in [:entry.instructions.size+1] do
      let values := match entry.instructions[position]? with
        | some statement => statement.operands
        | none => match entry.terminator with
          | .ret value => value.toList
          | .branch value .. => [value]
          | _ => []
      for value in values do
        let .symbol symbol := value | continue
        let some name := replacements[symbol]? | continue
        if introduced.contains symbol then continue
        introduced := introduced.insert symbol
        instructions := instructions.push (.assign {destination := name, width := .long, operation := .copy (.symbol symbol)})
      offsets := offsets.push introduced.size
      if let some statement := first.instructions[position]? then
        instructions := instructions.push statement
    return {rewritten with blocks := rewritten.blocks.set! 0 {first with
      instructions
      debugLocations := entry.debugLocations.map fun loc =>
        {loc with instruction := loc.instruction + offsets[loc.instruction]!}}}
  return {rewritten with blocks := rewritten.blocks.set! 0 {first with
    instructions := copies ++ first.instructions
    debugLocations := entry.debugLocations.map fun loc => {loc with instruction := loc.instruction+copies.size}}}

end LeanCompilerBackend.Optimize.Symbols
