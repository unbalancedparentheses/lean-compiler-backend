import LeanCompilerBackend.Allocation
import LeanCompilerBackend.Parser
import LeanCompilerBackend.SSA

namespace LeanCompilerBackend.Allocation.Tests

private def parse (s : String) : IO Function :=
  match Parser.parseModule s >>= SSA.constructModule with
  | .ok m => pure m.functions[0]!
  | .error e => throw (IO.userError e)

private def unwrap (result : Except String α) : IO α :=
  match result with | .ok x => pure x | .error e => throw (IO.userError e)

private def rejected (r : Except String Unit) : Bool :=
  match r with | .error _ => true | _ => false

def run : IO Unit := do
  let f ← parse "function l $f(l %x) { @s %a =l add %x, 1 %b =l mul %a, 3 ret %b }"
  let plan ← unwrap (allocate f)
  unless plan.colorCount == 1 do throw (IO.userError "nonoverlapping chain did not share its home")
  let f ← parse "function l $f(l %x,l %y) { @s %dead =l add %x,1 %a =l add %x,%y ret %a }"
  let plan ← unwrap (allocate f 1)
  let live ← unwrap (Liveness.analyze f)
  unless plan.registers == 1 && plan.spills >= 1 do throw (IO.userError "pressure did not spill")
  let corrupt := {plan with colors := Array.replicate plan.names.size 0, colorCount := 1}
  unless rejected (check f live corrupt) do throw (IO.userError "overlapping homes were accepted")
  unless rejected (HomeFlow.check f corrupt.names corrupt.colors corrupt.colorCount) do
    throw (IO.userError "home-flow checker accepted overlapping parameter values")
  let missing := {plan with colors := #[]}
  unless rejected (check f live missing) do throw (IO.userError "missing allocation was accepted")
  let bad := {plan with colors := plan.colors.set! 0 plan.colorCount}
  unless rejected (check f live bad) do throw (IO.userError "out-of-bounds allocation was accepted")
  let f ← parse "function l $f(l %x) { @s jmp @loop @loop %a =l phi @s %x,@loop %b %unused =l phi @s 7,@loop 8 %b =l add %a,1 %c =w cultl %b,10 jnz %c,@loop,@done @done ret %b }"
  let plan ← unwrap (allocate f)
  let live ← unwrap (Liveness.analyze f)
  let a := live.indices["a"]!
  let unused := live.indices["unused"]!
  let bad := {plan with colors := plan.colors.set! unused plan.colors[a]!}
  unless rejected (check f live bad) do throw (IO.userError "dead phi overwrote live parallel destination")
  unless rejected (HomeFlow.check f bad.names bad.colors bad.colorCount) do
    throw (IO.userError "home-flow checker accepted dead phi overwrite")
  IO.println "allocation checks: reusable homes, spills, dead writes and corrupted plans passed"

end LeanCompilerBackend.Allocation.Tests
