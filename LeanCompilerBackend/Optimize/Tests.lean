import LeanCompilerBackend.Optimize
import LeanCompilerBackend.Parser
import LeanCompilerBackend.SSA

namespace LeanCompilerBackend.Optimize.Tests

private def parse (s : String) : IO Module :=
  match Parser.parseModule s >>= SSA.constructModule with
  | .ok m => pure m
  | .error e => throw (IO.userError e)
private def require (b : Bool) (message : String) : IO Unit :=
  unless b do throw (IO.userError message)
private def same (a b : Except String UInt64) : Bool :=
  match a, b with | .ok x, .ok y => x == y | _, _ => false
private def optimize (m : Module) : IO Module :=
  match Optimize.module m with
  | .ok m => pure m
  | .error e => throw (IO.userError e)

def run : IO Unit := do
  let m ← parse "function l $f(l %x) { @s %a =w add 4294967295, 2 %b =l extuw %a %c =l mul %b, 37 %d =l xor %c, %x ret %d }"
  let optimized ← optimize m
  for x in (#[0,1,37,4294967295,18446744073709551615] : Array UInt64) do
    let expected := Semantics.evaluate m.functions[0]! #[x]
    let actual := Semantics.evaluate optimized.functions[0]! #[x]
    require (same actual expected) "constant folding changed word normalization or live parameter"
  require (optimized.functions[0]!.blocks[0]!.instructions.size == 1)
    "dead constant chain was not eliminated"
  for source in #[
    "function w $f() { @s %x =w div -2147483648, -1 ret %x }",
    "function l $f() { @s %x =l udiv 17, 0 ret %x }"] do
    let bad ← parse source
    let result ← optimize bad
    require (match result.functions[0]!.blocks[0]!.instructions[0]! with
      | .assign {operation := .divide .., ..} => true | _ => false)
      "undefined division was folded"
  let loop ← parse "function l $f(l %n) { @s jmp @loop @loop %i =l phi @s 0, @loop %next %next =l add %i, 1 %more =w cultl %next, %n jnz %more, @loop, @done @done ret %next }"
  let folded ← optimize loop
  for n in (#[1,2,17,100] : Array UInt64) do
    require (same (Semantics.evaluate loop.functions[0]! #[n]) (Semantics.evaluate folded.functions[0]! #[n]))
      "constant discovery invented a loop phi value"
  let debug ← parse "dbgfile \"fold.ssa\" function l $f() { @s dbgloc 7 %a =l add 1, 2 dbgloc 8 %b =l mul %a, 3 ret %b }"
  let folded ← optimize debug
  require (folded.functions[0]!.blocks[0]!.debugLocations.size == 2 && folded.functions[0]!.blocks[0]!.instructions.isEmpty)
    "cleanup failed to remap debug instruction indices"
  let copies ← parse "function l $f(l %x) { @s %a =l copy %x %b =l copy %a ret %b }"
  let cleaned ← optimize copies
  require cleaned.functions[0]!.blocks[0]!.instructions.isEmpty "same-width copy chain retained"
  require (same (Semantics.evaluate copies.functions[0]! #[42]) (Semantics.evaluate cleaned.functions[0]! #[42])) "copy propagation changed result"
  let effects ← parse "function l $f(l %p) { @s %v =l load %p %a =l alloc16 8 %d =l div 1, 0 ret 42 }"
  let cleaned ← optimize effects
  require (cleaned.functions[0]!.blocks[0]!.instructions.size == 3) "dead cleanup removed memory/allocation/trap operations"
  let narrow ← parse "function l $f(l %x) { @s %w =w copy %x %r =l extuw %w ret %r }"
  let cleaned ← optimize narrow
  require (same (Semantics.evaluate narrow.functions[0]! #[18446744073709551615]) (Semantics.evaluate cleaned.functions[0]! #[18446744073709551615])) "copy propagation removed word truncation"
  let diamond ← parse "function l $f() { @s jnz 4294967296, @bad, @good @bad %trap =l div 1, 0 jmp @join @good jmp @join @join %v =l phi @bad 7, @good 42 %c =w ceql %v, 42 jnz %c, @yes, @no @yes ret %v @no ret 9 }"
  let cleaned ← optimize diamond
  require (same (Semantics.evaluate diamond.functions[0]! #[]) (Semantics.evaluate cleaned.functions[0]! #[])) "CFG simplification changed word branch/phi result"
  require (cleaned.functions[0]!.blocks.size == 4) "CFG simplification retained unreachable diamond arms"
  require (cleaned.functions[0]!.blocks.all (fun b => b.phis.isEmpty && b.instructions.isEmpty)) "pruned phi did not expose constants"
  let infinite ← parse "function w $f() { @s jmp @loop @loop jnz 1, @loop, @done @done ret 42 }"
  let cleaned ← optimize infinite
  require (cleaned.functions[0]!.blocks.size == 2 && match cleaned.functions[0]!.blocks[1]!.terminator with | .jump label => label == "loop" | _ => false) "constant true loop was not retained"
  let deadCycle ← parse "function l $f() { @s ret 42 @a %x =l phi @b %y jmp @b @b %y =l copy %x jmp @a }"
  let cleaned ← optimize deadCycle
  require (cleaned.functions[0]!.blocks.size == 1) "unreachable phi cycle survived"
  let large ← parse "function l $f() { @s %n =l copy 8192 %p =l alloc16 %n ret 42 }"
  discard (optimize large)
  IO.println "constant propagation: word normalization, defined-domain folding, cyclic phis, debug indices and runtime-size admission passed"

end LeanCompilerBackend.Optimize.Tests
