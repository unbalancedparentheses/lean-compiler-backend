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

def observe (phase : String) (f : Function) : IO Unit := do
  inventory phase f
  let live ← timed (phase ++ " liveness") (fun _ => unwrap (Liveness.analyze f))
  let maximum ← timed (phase ++ " count-live") (fun _ => pure (maxLive live))
  IO.println s!"phase-live {phase} max_live_bits {maximum}"
  (← IO.getStdout).flush

def step (phase : String) (f : Function) (transform : Function → Except String Function) : IO Function := do
  let next ← timed phase (fun _ => unwrap (transform f))
  observe phase next
  return next

def main (args : List String) : IO Unit := do
  let some path := args.head? | throw (IO.userError "input required")
  let source ← IO.FS.readFile path
  let parsed ← timed "parse" (fun _ => unwrap (Parser.parseModule source))
  let m ← timed "SSA" (fun _ => unwrap (SSA.constructModule parsed))
  let some f := m.functions.find? (·.name == "copy_and_check") | throw (IO.userError "missing function")
  let globals := (m.data.filter (!·.threadLocal)).map (·.name)
  observe "input" f
  let f ← step "initial-copies" f (fun f => pure (Optimize.Cleanup.copies f))
  let f ← step "promote" f (fun f => pure (Optimize.Memory.promote f))
  let mut f ← step "post-promote-copies" f (fun f => pure (Optimize.Cleanup.copies f))
  for i in [:4] do
    f ← step ("simplify-round-" ++ toString i) f (fun f => Optimize.ControlFlow.simplify (Optimize.function f))
    f ← step ("copies-round-" ++ toString i) f (fun f => pure (Optimize.Cleanup.copies f))
  f ← step "hoist" f (fun f => pure (Optimize.Symbols.hoist globals f))
  f ← step "common" f (fun f => Optimize.Common.eliminate (Optimize.function f))
  f ← step "forward" f (fun f => pure (Optimize.Memory.forward (Optimize.Cleanup.copies f)))
  f ← step "extensions" f (fun f => pure (Optimize.Memory.eliminateExtensions (Optimize.Cleanup.copies f)))
  f ← step "final-dead" f (fun f => pure (Optimize.Cleanup.deadDefinitions (Optimize.Cleanup.copies f)))
  IO.println s!"completed phases for {f.name}"
