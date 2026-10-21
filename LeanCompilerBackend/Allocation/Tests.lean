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
  for (source, expected) in [
    ("function $f() { @e jmp @h @h jnz 1,@a,@b @a jmp @h @b jnz 1,@h,@d @d ret }", #[1,8,8,8,1]),
    ("function $f() { @e jnz 1,@a,@b @a jmp @b @b jnz 1,@a,@d @d ret }", #[1,1,1,1]),
    ("function $f() { @e jmp @d @a jmp @a @d ret }", #[1,1,1]),
    ("function $f() { @e jmp @h @h jnz 1,@h,@d @d ret }", #[1,8,1]),
    ("function $f() { @e jmp @a @a jnz 1,@b,@z @b jnz 1,@c,@la @c jnz 1,@d,@lb @d jnz 1,@d,@lc @lc jmp @c @lb jmp @b @la jmp @a @z ret }", #[1,8,64,512,512,512,64,8,1])] do
    let m ← unwrap (Parser.parseModule source)
    let graph ← unwrap (CFG.build m.functions[0]!)
    unless loopWeights graph == expected do
      throw (IO.userError "natural loop weights differ from expected membership/nesting")
  let largeGraph : CFG.Graph := {
    successors := ((Array.replicate 513 #[]).set! 0 #[1]).set! 1 #[1]
    predecessors := (Array.replicate 513 #[]).set! 1 #[0,1] }
  unless (loopWeights largeGraph).all (· == 1) &&
      (loopWeights {}).isEmpty do
    throw (IO.userError "loop heuristic resource/empty fallback changed")
  let loopHot ← parse "function l $loop_hot(l %cold,l %hot,w %go) { @e %a =l add %cold,%cold %b =l add %cold,%cold %c =l add %cold,%cold %d =l add %cold,%cold %e =l add %cold,%cold %f =l add %cold,%cold jmp @loop @loop %r =l add %hot,%hot jnz %go,@loop,@done @done %sum =l add %cold,%hot ret %sum }"
  let loopPlan ← unwrap (allocate loopHot 1)
  let loopLive ← unwrap (Liveness.analyze loopHot)
  unless loopPlan.colors[loopLive.indices["hot"]!]! == 0 &&
      loopPlan.colors[loopLive.indices["cold"]!]! != 0 do
    throw (IO.userError "loop uses did not outrank colder static uses")
  let hot ← parse "function l $hot(l %cold,l %hot) { @s %a =l mul %hot,3 %b =l xor %a,%hot %r =l add %b,%cold ret %r }"
  let preferred ← unwrap (allocate hot 1)
  let hotLive ← unwrap (Liveness.analyze hot)
  unless preferred.colors[hotLive.indices["hot"]!]! == 0 &&
      preferred.colors[hotLive.indices["cold"]!]! != 0 do
    throw (IO.userError "frequent color group was not preferred for the register bank")
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
