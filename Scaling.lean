/- In-process scaling of the numbered-source entry points. -/
import LeanCompilerBackend.Verified.Job
import LeanCompilerBackend.AMD64
import LeanCompilerBackend.AArch64

open LeanCompilerBackend LeanCompilerBackend.Verified

private def chain (n seed : Nat) : Source.Function :=
  { resultWidth := .word, parameters := #[], valueWidths := Array.replicate n .word
    blocks := #[{ phis := #[], instructions := (Array.range n).map fun i =>
                    { destination := i, width := .word
                      operation := .binary .add
                        (if i == 0 then .literal (.word 0) else .local (i - 1))
                        (.literal (.word (BitVec.ofNat 32 (seed + i)))) }
                  terminator := .ret (.local (n - 1)) }] }

-- A checked-operation shape with a shared failure exit and cross-block uses.
private def checkedChain (cyclic : Bool) (n seed : Nat) : Source.Function :=
  { resultWidth := .word, parameters := #[], valueWidths := Array.replicate (6 * n) .word
    blocks := (Array.range (n + 1)).map fun block =>
      if block == n then
        { phis := #[], instructions := #[], terminator := .ret (.literal (.word 0)) }
      else
        let instructions := (Array.range 6).map fun i =>
          let id := 6 * block + i
          { destination := id, width := .word
            operation := .binary .add
              (if id == 0 then .literal (.word 0) else .local (id - 1))
              (.literal (.word (BitVec.ofNat 32 (seed + i)))) : Source.Instruction }
        let value := Source.Operand.local (6 * block + 5)
        let terminator := if block + 1 == n then
            if cyclic then Source.Terminator.jump 1 else .ret value
          else .branch value (block + 1) n
        { phis := #[], instructions, terminator } }

-- Repeatedly reconverging edges, with the non-entry blocks in reverse order.
private def reverseLadder (n seed : Nat) : Source.Function :=
  let number := fun i => if i == 0 then 0 else n - i
  { resultWidth := .word, parameters := #[], valueWidths := #[]
    blocks := (Array.range n).map fun slot =>
      let i := number slot
      let value := Source.Operand.literal (.word (BitVec.ofNat 32 (seed + i + 1)))
      let terminator :=
        if i + 1 == n then Source.Terminator.ret value
        else if i == 0 || i + 2 == n then .jump (number (i + 1))
        else .branch value (number (i + 1)) (number (i + 2))
      { phis := #[], instructions := #[], terminator } }

-- Entry edges to both endpoints make the cycle irreducible.
private def bidirectionalChain (n seed : Nat) : Source.Function :=
  let condition := Source.Operand.literal (.word (BitVec.ofNat 32 (seed + 1)))
  { resultWidth := .word, parameters := #[], valueWidths := #[]
    blocks := (Array.range n).map fun i =>
      { phis := #[], instructions := #[], terminator :=
          if i == 0 then .branch condition 1 (n - 1)
          else if i == 1 then .jump 2
          else if i + 1 == n then .jump (i - 1)
          else .branch condition (i - 1) (i + 1) } }

private def jumpChain (n seed : Nat) : Source.Function :=
  { resultWidth := .word, parameters := #[], valueWidths := #[]
    blocks := (Array.range n).map fun i =>
      { phis := #[], instructions := #[], terminator :=
          if i + 1 < n then .jump (i + 1) else .ret (.literal (.word (BitVec.ofNat 32 seed))) } }

private def phiJoin (predecessors n seed : Nat) (width : Width := .word) : Source.Function := Id.run do
  let join := predecessors + 1
  let mut blocks : Array Source.Block := #[{ phis := #[], instructions := #[], terminator := .jump 1 }]
  for i in [1:join] do
    let terminator := if i == predecessors then Source.Terminator.jump join
      else .branch (.literal (.word 1)) join (i + 1)
    blocks := blocks.push { phis := #[], instructions := #[], terminator }
  let phis := (Array.range n).map fun i =>
    { destination := i, width, incoming := (Array.range predecessors).map fun j =>
      let value := seed + i + j
      let literal := match width with
        | .word => Source.Value.word (BitVec.ofNat 32 value)
        | .long => Source.Value.long (BitVec.ofNat 64 value)
      (j + 1, .literal literal) : Source.Phi }
  let joinBlock : Source.Block := { phis, instructions := #[], terminator := .ret (.local (n - 1)) }
  return { resultWidth := width, parameters := #[], valueWidths := Array.replicate n width
           blocks := blocks.push joinBlock }

private def job (f : Source.Function) : FunctionJob :=
  { code := { symbol := { namespaceName := "scaling", name := "body", exported := true }
              body := f, abi := planAbi f, layout := planFrame f } }

private def reifyFixture (f : Source.Function) : Except String Function :=
  (reify f "body" true).mapError fun e => s!"scaling fixture reification: {repr e}"

private def moduleOf (f : Source.Function) : Except String Module := do
  pure { functions := #[← reifyFixture f] }

@[noinline] private def quadratic (f : Source.Function) : Nat × Nat := Id.run do
  let some block := f.blocks[0]? | return (0, 0)
  let code := block.instructions
  let mut total := 0
  let mut probes := 0
  for i in code do
    for j in code do
      probes := probes + 1
      if i.destination <= j.destination then total := total + 1
  return (total, probes)

private def ratio (large small : Nat) : String :=
  let hundredths := 100 * large / small
  let fraction := hundredths % 100
  s!"{hundredths / 100}.{if fraction < 10 then "0" else ""}{fraction}"

-- Use the size of the scaled dimension. A linear traversal is bounded by
-- this envelope when combined with ordered-index operations at O(log n).
private def budget (n : Nat) : Nat :=
  n * (1 + n.log2)

private def withinBudget (smallN largeN smallWork largeWork : Nat) : Bool :=
  largeWork * budget smallN <= smallWork * budget largeN

-- Names must match measured rows. The runner verifies that every entry is used.
private def expectedFailures : List (String × String) := [
  ("bidirectional chain job validation", "bidirectional chain dominance"),
  ("bidirectional chain AArch64 macOS assembly", "bidirectional chain dominance"),
  ("allocated AArch64 debug locations", "AArch64 debug-location lookahead")
]

private structure Row where
  name : String
  fixture : Nat → Nat → Source.Function
  base : Nat
  work : Source.Function → Except String Nat

private def check (row : Row) (expectedFailure : Option String) : IO Bool := do
  let measure := fun n => do
    let mut total := 0
    for seed in [:4] do
      let visits ← match row.work (row.fixture n seed) with
        | .ok visits => pure visits
        | .error error => throw (IO.userError s!"{row.name}, size {n}, seed {seed}: {error}")
      if visits == 0 then
        throw (IO.userError s!"{row.name}: empty work sample at size {n}")
      total := total + visits
    return total
  let n := row.base
  let small ← measure n
  let medium ← measure (8 * n)
  let large ← measure (16 * n)
  let passed := withinBudget n (8 * n) small medium &&
    withinBudget n (16 * n) small large &&
    withinBudget (8 * n) (16 * n) medium large
  let verdict := match expectedFailure with
    | none => if passed then "accepted" else "rejected"
    | some issue => if passed then s!"unexpected pass ({issue})" else s!"expected rejection ({issue})"
  IO.println s!"{row.name}: {small}, {medium}, {large} work; ratios {ratio medium small}, {ratio large small}, {ratio large medium}; {verdict}"
  return passed == expectedFailure.isNone

private def fixtureRows (name : String) (fixture : Nat → Nat → Source.Function) (base : Nat) :
    List Row := [
  ⟨name ++ " job validation", fixture, base, fun f => (validateJobWithWork (job f)).mapError reprStr⟩,
  ⟨name ++ " x86-64 Linux assembly", fixture, base,
    fun f => do (AMD64.emitModuleWithWork (← moduleOf f)).map Prod.snd⟩,
  ⟨name ++ " AArch64 macOS assembly", fixture, base,
    fun f => ((compileFunctionWithWork (job f)).mapError reprStr).map Prod.snd⟩
]

-- Measure the validated emitter boundary to isolate edge emission.
private def compatibilityRows (name : String) (fixture : Nat → Nat → Source.Function)
    (base : Nat) : List Row := [
  ⟨name ++ " x86-64 compatibility", fixture, base,
    fun f => do (AMD64.emitModuleValidatedWithWork (← moduleOf f)).map Prod.snd⟩,
  ⟨name ++ " AArch64 compatibility", fixture, base,
    fun f => do (AArch64.emitModuleValidatedWithWork (← moduleOf f)).map Prod.snd⟩
]

-- Terminator-only debug records force the allocated emitter's lookahead
-- to scan the full location array for each ordinary instruction.
private def allocatedDebug (f : Source.Function) : Except String Nat := do
  let body ← reifyFixture f
  let block := body.blocks[0]!
  let count := block.instructions.size
  let instructions := (Array.range count).map fun i =>
    Statement.assign { destination := s!"copy{i}", width := .word, operation := .copy (.constant 0) }
  let debugLocations := (Array.range count).map fun i =>
    { instruction := count, line := i + 1 : DebugLocation }
  let body := { body with debugFile := some "scaling.ssa", blocks := #[{
    block with instructions, debugLocations, terminator := .ret (some (.constant 0)) }] }
  (AArch64.emitModuleWithWork { functions := #[body] } (allocate := true)).map Prod.snd

def main : IO UInt32 := do
  let publicArm := fun f => do (AArch64.emitModuleWithWork (← moduleOf f)).map Prod.snd
  let compatibility := [
    ("jump chain", jumpChain, 256),
    ("two-way phi join", (fun n seed => phiJoin 2 n seed .long), 128),
    ("phi fan-in", (fun n seed => phiJoin n 8 seed), 128)
  ]
  for (name, fixture, base) in compatibility do
    for n in #[base, 8 * base, 16 * base] do
      match moduleOf (fixture n 0) >>= validateModule with
      | .ok () => pure ()
      | .error error => throw (IO.userError s!"{name}, size {n}: {error}")
  -- Reification erases literal widths. Check the long fixture at a size
  -- within the numbered profile before measuring the compatibility emitters.
  match validateJob (job (phiJoin 2 128 0 .long)) with
  | .ok () => pure ()
  | .error error => throw (IO.userError s!"long phi fixture: {repr error}")
  let rows :=
    fixtureRows "reverse ladder" reverseLadder 4 ++
    fixtureRows "bidirectional chain" bidirectionalChain 4 ++
    fixtureRows "chain" chain 30 ++
    fixtureRows "checked chain" (checkedChain false) 3 ++
    fixtureRows "loop chain" (checkedChain true) 3 ++
    fixtureRows "phi join" (fun n seed => phiJoin 8 n seed) 15 ++
    compatibility.flatMap (fun (name, fixture, base) => compatibilityRows name fixture base) ++ [
      ⟨"jump chain public AArch64 assembly", jumpChain, 256, publicArm⟩,
      ⟨"bidirectional chain public AArch64 assembly", bidirectionalChain, 16, publicArm⟩,
      ⟨"allocated AArch64 debug locations", chain, 128, allocatedDebug⟩
    ]
  for (name, _) in expectedFailures do
    unless (rows.filter (·.name == name)).length == 1 &&
        (expectedFailures.filter (·.1 == name)).length == 1 do
      throw (IO.userError s!"invalid scaling expected-failure entry: {name}")
  let mut passed := true
  for row in rows do
    let ok ← check row (expectedFailures.lookup row.name)
    passed := passed && ok
  unless quadratic (chain 480 0) == (480 * 481 / 2, 480 * 480) do
    throw (IO.userError "planted quadratic checksum or work mismatch")
  let control ← check ⟨"planted quadratic", chain, 30, fun f => .ok (quadratic f).2⟩
    (some "planted control")
  return if passed && control then 0 else 1
