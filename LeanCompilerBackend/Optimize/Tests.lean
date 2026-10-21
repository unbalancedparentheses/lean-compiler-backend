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
  let globals ← parse "data $table = { l 5 } dbgfile \"addresses.c\" function l $f(l %lcb.symbol.0) { @s dbgloc 7 %a =l loadl $table %b =l loadl $table %c =l loadl $table %ab =l add %a,%b %abc =l add %ab,%c %r =l add %abc,%lcb.symbol.0 ret %r }"
  let shared ← optimize globals
  let symbolUses := shared.functions[0]!.blocks.foldl (fun n b => n +
    b.instructions.foldl (fun count s => count + (s.operands.filter fun v =>
      match v with | .symbol _ => true | _ => false).length) 0) 0
  require (symbolUses == 1) "repeated module-data address was not shared"
  require (shared.functions[0]!.blocks[0]!.debugLocations[0]!.instruction == 1)
    "address hoisting did not shift the original debug location"
  for x in (#[0,1,42,18446744073709551615] : Array UInt64) do
    let expected := some (some (15+x))
    require ((Semantics.evaluateModule globals "f" #[x]).toOption == expected &&
      (Semantics.evaluateModule shared "f" #[x]).toOption == expected)
      "shared address changed contents or collided with an existing local"
  let external ← parse "function w $f(w %condition) { @s jnz %condition,@use,@done @use %a =l copy $missing %b =l add $missing,8 %c =l add $missing,16 ret 0 @done ret 42 }"
  let retained ← optimize external
  require ((Semantics.evaluateModule retained "f" #[0]).toOption == some (some 42) &&
    retained.functions[0]!.blocks[0]!.instructions.isEmpty)
    "external symbol resolution was moved onto an inactive path"
  let tls ← parse "thread data $local = { l 1 } function l $f(w %condition) { @s jnz %condition,@use,@done @use %a =l copy thread $local %b =l add thread $local,8 %c =l add thread $local,16 ret %a @done ret 42 }"
  let retained ← optimize tls
  require retained.functions[0]!.blocks[0]!.instructions.isEmpty
    "TLS address resolution was hoisted"
  for (op, operand, expectedShift) in #[
      ("mul", "1", false), ("mul", "4294967297", false),
      ("mul", "8", true), ("mul", "-2147483648", true),
      ("add", "4294967296", false), ("sub", "0", false),
      ("and", "-1", false), ("or", "0", false), ("xor", "0", false),
      ("shl", "32", false), ("shr", "-32", false), ("sar", "4294967360", false)] do
    let m ← parse ("function w $f(l %x) { @s %r =w " ++ op ++ " %x, " ++ operand ++ " ret %r }")
    let optimized ← optimize m
    let instructions := optimized.functions[0]!.blocks[0]!.instructions
    require (instructions.size == 1 && match instructions[0]! with
      | .assign {operation := .binary .shiftLeft .., ..} => expectedShift
      | .assign {operation := .copy .., ..} => !expectedShift
      | _ => false) s!"integer identity was not selected: {op} {operand}"
    for x in (#[0, 1, 4294967295, 4294967296, 9223372036854775808, 18446744073709551615] : Array UInt64) do
      require (same (Semantics.evaluate m.functions[0]! #[x]) (Semantics.evaluate optimized.functions[0]! #[x]))
        s!"integer identity lost result width: {op} {operand}"
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
  let common ← parse "function l $f(l %x) { @s %a =l add %x, 1 %b =l add %x, 1 %c =l mul %a, 2 %d =l mul %b, 2 %r =l add %c, %d ret %r }"
  let cleaned ← optimize common
  require (cleaned.functions[0]!.blocks[0]!.instructions.size == 3) "cascading common expressions were retained"
  for x in (#[0,1,42,18446744073709551615] : Array UInt64) do
    require (same (Semantics.evaluate common.functions[0]! #[x]) (Semantics.evaluate cleaned.functions[0]! #[x])) "common expressions changed bit-vector results"
  let dominated ← parse "function l $f(l %x, w %condition) { @s jmp @parent @left %a =l mul %x, 7 jmp @join @right %b =l mul %x, 7 jmp @join @join %r =l phi @left %a, @right %b ret %r @parent %base =l mul %x, 7 jnz %condition, @left, @right }"
  let cleaned ← optimize dominated
  require (cleaned.functions[0]!.blocks.foldl (fun n b => n + b.instructions.size) 0 == 1) "dominating common expression in later-listed block was missed"
  for c in (#[0,1] : Array UInt64) do
    require (same (Semantics.evaluate dominated.functions[0]! #[42,c]) (Semantics.evaluate cleaned.functions[0]! #[42,c])) "cross-block common expression changed phi results"
  let siblings ← parse "function l $f(l %x, w %condition) { @s jnz %condition, @left, @right @left %a =l add %x, 1 jmp @join @right %b =l add %x, 1 jmp @join @join %v =l phi @left %a, @right %b %z =l add %x, 1 %r =l add %v, %z ret %r }"
  let cleaned ← optimize siblings
  require (cleaned.functions[0]!.blocks.foldl (fun n b => n + b.instructions.size) 0 == 4) "common expression crossed a non-dominating branch"
  let loads ← parse "function l $f(l %p) { @s %a =l load %p storel 42, %p %b =l load %p %r =l add %a, %b ret %r }"
  let cleaned ← optimize loads
  require (cleaned.functions[0]!.blocks[0]!.instructions.size == 4) "common expression merged potentially aliased memory reads"
  let widths ← parse "function l $f(l %x) { @s %a =w add %x, 1 %b =l add %x, 1 %wide =l extuw %a %r =l xor %wide, %b ret %r }"
  let cleaned ← optimize widths
  require (same (Semantics.evaluate widths.functions[0]! #[4294967295]) (Semantics.evaluate cleaned.functions[0]! #[4294967295])) "common expression merged different result widths"
  let trivial ← parse "function l $f(l %x,w %c) { @s jnz %c,@a,@b @a jmp @join @b jmp @join @join %r =l phi @a %x,@b %x ret %r }"
  let cleaned ← optimize trivial
  require (cleaned.functions[0]!.blocks.all (·.phis.isEmpty)) "equal-input phi was not eliminated"
  for c in (#[0,1] : Array UInt64) do
    require (same (Semantics.evaluate trivial.functions[0]! #[42,c]) (Semantics.evaluate cleaned.functions[0]! #[42,c])) "trivial phi changed result"
  let selfPhi ← parse "function l $f(l %x) { @s jmp @loop @loop %v =l phi @s %x,@loop %v %i =w phi @s 0,@loop %j %j =w add %i,1 %c =w cultw %j,7 jnz %c,@loop,@done @done ret %v }"
  let cleaned ← optimize selfPhi
  require (cleaned.functions[0]!.blocks.foldl (fun n b => n+b.phis.size) 0 == 1) "self-edge trivial phi was not eliminated"
  require (same (Semantics.evaluate selfPhi.functions[0]! #[42]) (Semantics.evaluate cleaned.functions[0]! #[42])) "self-edge phi changed result"
  let large ← parse "function l $f() { @s %n =l copy 8192 %p =l alloc16 %n ret 42 }"
  discard (optimize large)
  IO.println "compatibility optimization: constants, copies, CFG/phi cleanup, dominance-aware common expressions, widths, traps and debug indices passed"

end LeanCompilerBackend.Optimize.Tests
