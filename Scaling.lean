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
      (j + 1, .literal (.word (BitVec.ofNat 32 (seed + i + j)))) : Source.Phi }
  let joinBlock : Source.Block := { phis, instructions := #[], terminator := .ret (.local (n - 1)) }
  return { resultWidth := width, parameters := #[], valueWidths := Array.replicate n width
           blocks := blocks.push joinBlock }

private def job (f : Source.Function) : FunctionJob :=
  { code := { symbol := { namespaceName := "scaling", name := "body", exported := true }
              body := f, abi := planAbi f, layout := planFrame f } }

private def linux (f : Source.Function) : Except String String := do
  let m : Module := { functions := #[reify f "body" true] }
  validateModule m
  AMD64.emitModuleValidated m false false

@[noinline] private def quadratic (f : Source.Function) : Nat := Id.run do
  let some block := f.blocks[0]? | return 0
  let code := block.instructions
  let mut total := 0
  for i in code do
    for j in code do
      if i.destination <= j.destination then total := total + 1
  return total

private def sample (work : Source.Function → Except String Nat)
    (inputs : Array Source.Function) : IO Nat := do
  let start ← IO.monoNanosNow
  let mut checksum := 0
  for f in inputs do
    match work f with
    | .ok size => checksum := checksum + size
    | .error e => throw (IO.userError e)
  let stop ← IO.monoNanosNow
  if checksum == 0 || stop <= start then throw (IO.userError "invalid scaling sample")
  return stop - start

private def measurements (fixture : Nat → Nat → Source.Function) (base : Nat)
    (work : Source.Function → Except String Nat) : IO (Nat × Nat × Nat) := do
  let inputs := (#[base, 8 * base, 16 * base]).map fun n => (Array.range 32).map (fixture n)
  let mut samples : Array (Array Nat) := #[#[], #[], #[]]
  for input in inputs do discard (sample work input)
  for trial in [:9] do
    -- Rotate the order so all sizes encounter the same transient host load.
    for offset in [:3] do
      let i := (trial + offset) % 3
      let elapsed ← sample work inputs[i]!
      samples := samples.modify i (·.push elapsed)
  -- Scheduling delays inflate wall times. Use the second-fastest of nine
  -- samples so a single unusually fast sample cannot decide a row.
  let times := samples.map fun ns => (ns.qsort (· < ·))[1]!
  return (times[0]!, times[1]!, times[2]!)

private def ratio (large small : Nat) : String :=
  let hundredths := 100 * large / small
  let fraction := hundredths % 100
  s!"{hundredths / 100}.{if fraction < 10 then "0" else ""}{fraction}"

private inductive Expectation where
  | scaling
  | quadraticControl
  | knownTracked
  deriving BEq

private def check (name : String) (fixture : Nat → Nat → Source.Function) (base : Nat)
    (work : Source.Function → Except String Nat) (expectation : Expectation := .scaling) : IO Bool := do
  for attempt in [:(if expectation == .scaling then 3 else 1)] do
    let (small, medium, large) ← measurements fixture base work
    -- Allow logarithmic index growth and fixed per-call overhead. A quadratic
    -- scan should grow by roughly 64x and 256x over these same windows.
    let passed := medium * 2 <= small * 25 && large * 2 <= small * 53 &&
      large * 2 <= medium * 5
    let verdict := if passed then "accepted" else "rejected"
    let status := if expectation == .knownTracked then s!"known-tracked ({verdict})" else verdict
    IO.println s!"{name}: {small / 32}, {medium / 32}, {large / 32} ns/call; ratios {ratio medium small}, {ratio large small}; {status} (attempt {attempt + 1})"
    (← IO.getStdout).flush
    match expectation with
    | .knownTracked => return true
    | .quadraticControl => return !passed
    | .scaling => if passed then return true
  return false

private def validation (f : Source.Function) : Except String Nat :=
  ((validateJob (job f)).mapError reprStr).map fun _ => f.valueWidths.size + f.blocks.size

private def arm (f : Source.Function) : Except String Nat :=
  ((compileFunction (job f)).mapError reprStr).map (·.code.fragment.utf8ByteSize)

private def checkFixture (name : String) (fixture : Nat → Nat → Source.Function) (base : Nat)
    (numbered : Expectation := .scaling) (linuxExpectation : Expectation := .scaling) : IO Bool := do
  let validationOK ← check (name ++ " job validation") fixture base validation numbered
  let x86OK ← check (name ++ " x86-64 Linux assembly") fixture base
    (fun f => (linux f).map String.utf8ByteSize) linuxExpectation
  let armOK ← check (name ++ " AArch64 macOS assembly") fixture base arm numbered
  return validationOK && x86OK && armOK

-- Measure the validated emitter boundary so compatibility CFG validation
-- cannot hide the cost of an emitter's edge lookups.
private def checkCompatibility (name : String) (fixture : Nat → Nat → Source.Function)
    (base : Nat) : IO Bool := do
  let moduleOf := fun f => ({ functions := #[reify f "body" true] } : Module)
  for n in #[base, 8 * base, 16 * base] do
    match validateModule (moduleOf (fixture n 0)) with
    | .ok () => pure ()
    | .error e => throw (IO.userError e)
  let x86 ← check (name ++ " x86-64 compatibility") fixture base
    (fun f => (AMD64.emitModuleValidated (moduleOf f)).map String.utf8ByteSize)
  let a64 ← check (name ++ " AArch64 compatibility") fixture base
    (fun f => (AArch64.emitModuleValidated (moduleOf f)).map String.utf8ByteSize)
  return x86 && a64

-- Terminator-only debug records force the allocated emitter's lookahead
-- to scan the full location array for each ordinary instruction.
private def allocatedDebug (f : Source.Function) : Except String Nat := do
  let body := reify f "body" true
  let block := body.blocks[0]!
  let count := block.instructions.size
  let instructions := (Array.range count).map fun i =>
    Statement.assign { destination := s!"copy{i}", width := .word, operation := .copy (.constant 0) }
  let debugLocations := (Array.range count).map fun i =>
    { instruction := count, line := i + 1 : DebugLocation }
  let body := { body with debugFile := some "scaling.ssa", blocks := #[{
    block with instructions, debugLocations, terminator := .ret (some (.constant 0)) }] }
  (AArch64.emitModule { functions := #[body] } (allocate := true)).map String.utf8ByteSize

def main (args : List String) : IO UInt32 := do
  let ladderOK ← checkFixture "reverse ladder" reverseLadder 4 .knownTracked .knownTracked
  let bidirectionalOK ← checkFixture "bidirectional chain" bidirectionalChain 4 .knownTracked
  let chainOK ← checkFixture "chain" chain 30
  let cfgOK ← checkFixture "checked chain" (checkedChain false) 3
  let loopOK ← checkFixture "loop chain" (checkedChain true) 3
  let phiOK ← checkFixture "phi join" (fun n seed => phiJoin 8 n seed) 15
  let edgesOK ← checkCompatibility "jump chain" jumpChain 256
  let publicArm := fun f =>
    (AArch64.emitModule { functions := #[reify f "body" true] }).map String.utf8ByteSize
  let publicEdgesOK ← check "jump chain public AArch64 assembly" jumpChain 256 publicArm
  let publicCycleOK ← check "bidirectional chain public AArch64 assembly"
    bidirectionalChain 16 publicArm
  let stagingOK ← checkCompatibility "two-way phi join" (fun n seed => phiJoin 2 n seed .long) 128
  let fanInOK ← checkCompatibility "phi fan-in" (fun n seed => phiJoin n 8 seed) 128
  let debugOK ← check "allocated AArch64 debug locations" chain 128 allocatedDebug .knownTracked
  unless quadratic (chain 480 0) == 480 * 481 / 2 do
    throw (IO.userError "planted quadratic checksum mismatch")
  let control ← check "planted quadratic" chain 30 (fun f => .ok (quadratic f)) .quadraticControl
  return if (chainOK && cfgOK && loopOK && phiOK && ladderOK && bidirectionalOK && edgesOK && publicEdgesOK && publicCycleOK && stagingOK && fanInOK && debugOK && control) || args == ["--report-only"] then 0 else 1
