import LeanCompilerBackend.Parser
import LeanCompilerBackend.SSA
import LeanCompilerBackend.Optimize
import LeanCompilerBackend.Allocation

open LeanCompilerBackend

def unwrap (x : Except String α) : IO α :=
  match x with | .ok a => pure a | .error e => throw (IO.userError e)

def timed (label : String) (action : Unit → IO α) : IO α := do
  let start ← IO.monoMsNow
  let result ← action ()
  let stop ← IO.monoMsNow
  IO.println s!"stage {label} milliseconds {stop-start}"
  (← IO.getStdout).flush
  return result

def population (value : Nat) : Nat := Id.run do
  let mut bits := value
  let mut count := 0
  for _ in [:value.log2+1] do
    if bits == 0 then break
    bits := bits &&& (bits-1)
    count := count+1
  return count

-- Count adjacent liveness differences, avoiding rescanning every dense set.
def maxLive (r : Liveness.Result) : Nat := Id.run do
  let mut maximum := 0
  for points in r.before do
    let mut prior := 0
    let mut count := 0
    for value in points do
      let common := prior &&& value
      count := count - population (prior ^^^ common) + population (value ^^^ common)
      maximum := max maximum count
      prior := value
  for value in r.liveIn ++ r.liveOut do maximum := max maximum (population value)
  for edges in r.edges do
    for value in edges do maximum := max maximum (population value)
  return maximum

def inventory (phase : String) (f : Function) : IO Unit := do
  let instructions := f.blocks.foldl (fun n b => n+b.instructions.size) 0
  let phis := f.blocks.foldl (fun n b => n+b.phis.size) 0
  IO.println s!"inventory {phase} function {f.name} locals {f.locals.size} blocks {f.blocks.size} instructions {instructions} phis {phis}"
  (← IO.getStdout).flush

def main (args : List String) : IO Unit := do
  let some path := args.head? | throw (IO.userError "input path required")
  let source ← IO.FS.readFile path
  let parsed ← timed "parse" (fun _ => unwrap (Parser.parseModule source))
  let normalized ← timed "SSA" (fun _ => unwrap (SSA.constructModule parsed))
  for f in normalized.functions do inventory "before" f
  let optimized ← timed "optimize" (fun _ => unwrap (Optimize.module normalized))
  for f in optimized.functions do
    inventory "after" f
    let live ← timed (f.name ++ " liveness") (fun _ => unwrap (Liveness.analyze f))
    let maximum ← timed (f.name ++ " count-live") (fun _ => pure (maxLive live))
    IO.println s!"liveness function {f.name} max_live_bits {maximum} names {live.names.size}"
    (← IO.getStdout).flush
    let plan ← timed (f.name ++ " allocation-including-liveness-and-checks") (fun _ => unwrap (Allocation.allocate f 10))
    IO.println s!"allocation function {f.name} colors {plan.colorCount} registers {plan.registers} spills {plan.spills}"
    (← IO.getStdout).flush
