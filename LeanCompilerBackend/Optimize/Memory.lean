/- Conservative scalar stack promotion. No general alias analysis or proof. -/
import LeanCompilerBackend.SSA

namespace LeanCompilerBackend.Optimize.Memory

private structure Candidate where
  name : String
  bytes : Nat
  kind : Option (Width × Bool) := none
  valid : Bool := true
  deriving Inhabited

private def temporary : Operand → Option String
  | .temporary name => some name | _ => none

/-- Only direct, exact-width scalar accesses to entry-block objects qualify.
    Byte/half objects use word SSA values with explicit store truncation and
    signed/unsigned load extension to either word or long results.
    Any address escape, pointer arithmetic, partial or mixed-class access rejects
    the object. Loads must be definitely initialized on every entry-reachable path. -/
def promote (f : Function) : Function := Id.run do
  let some entry := f.blocks[0]? | return f
  let mut candidates : Array Candidate := #[]
  let mut indices : Std.HashMap String Nat := {}
  for statement in entry.instructions do
    if let .assign inst := statement then
      if let .allocate _ (.constant bytes) := inst.operation then
        if bytes == 1 || bytes == 2 || bytes == 4 || bytes == 8 then
          indices := indices.insert inst.destination candidates.size
          candidates := candidates.push { name := inst.destination, bytes := bytes.toNat }
  if candidates.isEmpty then return f
  let .ok graph := CFG.build f | return f
  let mut reachable := (Array.replicate f.blocks.size false).set! 0 true
  let mut pending := #[0]
  for next in [:f.blocks.size] do
    if next >= pending.size then break
    for successor in graph.successors[pending[next]!]! do
      if !reachable[successor]! then
        reachable := reachable.set! successor true
        pending := pending.push successor
  let invalidate := fun (cs : Array Candidate) (v : Operand) =>
    match temporary v >>= fun n => indices[n]? with
    | some i => cs.set! i {cs[i]! with valid := false}
    | none => cs
  let access := fun (cs : Array Candidate) (address : Operand) (bytes : Nat) (kind : Width × Bool) =>
    let kind := if bytes < 4 && !kind.2 then (.word,false) else kind
    match temporary address >>= fun n => indices[n]? with
    | some i =>
      let c := cs[i]!
      cs.set! i {c with
        kind := some kind
        valid := c.valid && c.bytes == bytes &&
          (c.bytes == kind.1.bytes || (c.bytes < 4 && kind == (.word,false))) &&
          (c.kind.isNone || c.kind == some kind)}
    | none => cs
  for b in [:f.blocks.size] do
    let block := f.blocks[b]!
    for phi in block.phis do
      for (_,v) in phi.incoming do candidates := invalidate candidates v
    for statement in block.instructions do
      if !reachable[b]! then
        for v in statement.operands do candidates := invalidate candidates v
      else
        match statement with
        | .assign {operation := .load kind address, width, floating, ..} =>
          candidates := access candidates address (kind.bytes width) (width,floating)
        | .store width value address =>
          candidates := invalidate candidates value
          candidates := access candidates address width.bytes (width.valueWidth,false)
        | .storeFloat width value address =>
          candidates := invalidate candidates value
          candidates := access candidates address width.bytes (width,true)
        | _ => for v in statement.operands do candidates := invalidate candidates v
    match block.terminator with
    | .ret (some v) | .branch v .. => candidates := invalidate candidates v
    | _ => pure ()
  let bit := fun (v : Operand) =>
    (temporary v >>= fun n => indices[n]?).map (fun i => 1 <<< i) |>.getD 0
  let writes := f.blocks.map fun b => b.instructions.foldl (fun mask s => match s with
    | .store _ _ address | .storeFloat _ _ address => mask ||| bit address
    | _ => mask) 0
  let all := (1 <<< candidates.size)-1
  let mut inputs := Array.replicate f.blocks.size all
  let mut outputs := Array.replicate f.blocks.size all
  let mut converged := false
  -- Must-initialization: a bit survives a join only when all predecessors store
  -- before reaching it. False propagates along a simple path of at most |B| edges.
  for _ in [:f.blocks.size+2] do
    let mut changed := false
    for b in [:f.blocks.size] do
      let preds := graph.predecessors[b]!
      let incoming := if b == 0 || preds.isEmpty then 0
        else preds.foldl (fun mask p => mask &&& outputs[p]!) all
      let outgoing := incoming ||| writes[b]!
      changed := changed || incoming != inputs[b]! || outgoing != outputs[b]!
      inputs := inputs.set! b incoming
      outputs := outputs.set! b outgoing
    if !changed then
      converged := true
      break
  if !converged then return f
  for b in [:f.blocks.size] do
    let mut initialized := inputs[b]!
    for statement in f.blocks[b]!.instructions do
      match statement with
      | .assign {operation := .load _ address, ..} =>
        if initialized &&& bit address == 0 then candidates := invalidate candidates address
      | .store _ _ address | .storeFloat _ _ address => initialized := initialized ||| bit address
      | _ => pure ()
  let active := fun (name : String) =>
    (indices[name]?).bind fun i => if candidates[i]!.valid && candidates[i]!.kind.isSome then some i else none
  if !candidates.any (fun c => c.valid && c.kind.isSome) then return f
  let names := f.locals.map (·.1)
  let mut namePrefix := "lcb.mem."
  for _ in [:names.size+1] do
    if names.any (·.startsWith namePrefix) then namePrefix := namePrefix ++ "_"
  let variableName := fun i => namePrefix ++ toString i
  let mut blocks := #[]
  for block in f.blocks do
    let mut instructions := #[]
    let mut positions := #[]
    for statement in block.instructions do
      positions := positions.push instructions.size
      match statement with
      | .assign inst =>
        if (active inst.destination).isSome then continue
        match inst.operation with
        | .load kind (.temporary name) =>
          if let some i := active name then
            let value := Operand.temporary (variableName i)
            let operation := match kind with
              | .signedByte => Operation.unary .signedByte value
              | .unsignedByte => Operation.unary .unsignedByte value
              | .signedHalf => Operation.unary .signedHalf value
              | .unsignedHalf => Operation.unary .unsignedHalf value
              | _ => Operation.copy value
            instructions := instructions.push (.assign {inst with operation})
          else instructions := instructions.push statement
        | _ => instructions := instructions.push statement
      | .store _ value (.temporary name) | .storeFloat _ value (.temporary name) =>
        if let some i := active name then
          let (width,floating) := candidates[i]!.kind.getD (.long,false)
          let operation := if candidates[i]!.bytes == 1 then Operation.unary .unsignedByte value
            else if candidates[i]!.bytes == 2 then Operation.unary .unsignedHalf value
            else Operation.copy value
          instructions := instructions.push (.assign {destination := variableName i, width, floating, operation})
        else instructions := instructions.push statement
      | _ => instructions := instructions.push statement
    positions := positions.push instructions.size
    blocks := blocks.push {block with
      instructions
      debugLocations := block.debugLocations.map fun loc => {loc with instruction := positions[loc.instruction]!}}
  -- Reuse the validated mutable-temporary SSA builder. On its resource boundary,
  -- keep the original function instead of expanding the compatibility domain.
  match SSA.construct {f with blocks} with
  | .ok promoted =>
    match validateFunction promoted true with
    | .ok () =>
      return promoted
    | .error _ =>
      return f
  | .error _ =>
    return f

private structure Stored where
  address : Operand
  bytes : Nat
  floating : Bool
  value : Operand

private def sameAddress : Operand → Operand → Bool
  | .temporary a, .temporary b | .symbol a, .symbol b | .threadSymbol a, .threadSymbol b => a == b
  | .constant a, .constant b => a == b
  | _, _ => false

private def storedOperation (stored : Stored) (i : Instruction) (kind : LoadKind)
    (address : Operand) : Option Operation := do
  if !sameAddress stored.address address || stored.bytes != kind.bytes i.width ||
      stored.floating != i.floating then none
  else
    some (match kind with
      | .signedByte => .unary .signedByte stored.value
      | .unsignedByte => .unary .unsignedByte stored.value
      | .signedHalf => .unary .signedHalf stored.value
      | .unsignedHalf => .unary .unsignedHalf stored.value
      | .signedWord => if i.width == .word then .copy stored.value else .unary .signedWord stored.value
      | .unsignedWord => if i.width == .word then .copy stored.value else .unary .unsignedWord stored.value
      | .plain => .copy stored.value)

/-- Same-block, exact-address forwarding. Every store invalidates all prior
    facts before recording its own value. Calls, variadic state accesses, blits
    and allocations clear all facts. No alias-disjointness or cross-block facts
    are assumed, and stores are never removed. Access widths and FP classes must
    match; integer store truncation/load extension remains explicit. -/
def forward (f : Function) : Function := Id.run do
  let mut blocks := #[]
  for block in f.blocks do
    let mut loads : Std.HashMap String String := {}
    let mut stored : Option Stored := none
    let mut instructions := #[]
    for statement in block.instructions do
      let mut replacement := statement
      match statement with
      | .assign i =>
        match i.operation with
        | .load kind address =>
          let key := s!"{reprStr address}|{reprStr kind}|{reprStr i.width}|{i.floating}"
          let forwarded := stored.bind (fun value => storedOperation value i kind address)
          let operation := forwarded.orElse (fun _ =>
            (loads[key]?).map (fun name => Operation.copy (.temporary name)))
          if let some operation := operation then replacement := .assign {i with operation}
          loads := loads.insert key i.destination
        | .call .. | .vaArg .. | .allocate .. =>
          loads := {}
          stored := none
        | _ => pure ()
      | .store width value address =>
        loads := {}
        stored := some {address, value, bytes := width.bytes, floating := false}
      | .storeFloat width value address =>
        loads := {}
        stored := some {address, value, bytes := width.bytes, floating := true}
      | .callVoid .. | .vaStart .. | .blit .. =>
        loads := {}
        stored := none
      instructions := instructions.push replacement
    blocks := blocks.push {block with instructions}
  return {f with blocks}

end LeanCompilerBackend.Optimize.Memory
