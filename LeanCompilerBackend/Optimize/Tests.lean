import LeanCompilerBackend.Optimize
import LeanCompilerBackend.Parser
import LeanCompilerBackend.SSA
import LeanCompilerBackend.AMD64
import LeanCompilerBackend.AArch64
import LeanCompilerBackend.RV64

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

private def markerCounts (m : Module) : Nat × Nat × Nat := Id.run do
  let mut calls := 0
  let mut markers := 0
  let mut voids := 0
  for f in m.functions do
    for b in f.blocks do
      for s in b.instructions do
        match s with
        | .assign {operation := .call _ _ marker, ..} =>
          calls := calls + 1
          if marker then markers := markers + 1
        | .callVoid _ _ marker =>
          calls := calls + 1
          voids := voids + 1
          if marker then markers := markers + 1
        | _ => pure ()
  return (calls,markers,voids)


private def symbolPlacement : IO Unit := do
  let m ← parse "data $left = { l 5 } data $right = { l 7 } dbgfile \"placement.c\" function l $f(l %lcb.symbol.0) { @s dbgloc 10 dbgloc 11 %pre =l add %lcb.symbol.0,1 dbgloc 12 %a =l add $left,$right dbgloc 13 %b =l add $left,$right dbgloc 14 %c =l add $left,$right %r =l xor %a,%pre %out =l add %r,%b %final =l add %out,%c dbgloc 15 ret %final }"
  let f := m.functions[0]!
  let placed := Symbols.hoist (m.data.map (·.name)) f
  require (placed.blocks[0]!.debugLocations.map (·.instruction) == #[0,0,3,4,5,9])
    "first-use address placement lost repeated/trailing debug positions"
  let addressAt := fun (index : Nat) (symbol : String) => match placed.blocks[0]!.instructions[index]? with
    | some (.assign {operation := .copy (.symbol name), ..}) => name == symbol
    | _ => false
  require (addressAt 1 "left" && addressAt 2 "right")
    "multiple address copies were not inserted at first original use"
  for value in (#[0,1,4294967295,18446744073709551615] : Array UInt64) do
    let .ok expected := Semantics.evaluateModule m "f" #[value]
      | throw (IO.userError "symbol placement source evaluation failed")
    require ((Semantics.evaluateModule {m with functions := #[placed]} "f" #[value]).toOption == some expected)
      "first-use address placement changed values or captured a local name"
  for count in [8,9] do
    let mut data := ""
    let mut body := ""
    for i in [:count] do
      data := data ++ "data $g" ++ toString i ++ " = { l 0 }\n"
      for j in [:3] do
        body := body ++ " %v" ++ toString i ++ "." ++ toString j ++ " =l add $g" ++ toString i ++ "," ++ toString j ++ "\n"
    for loop in [false,true] do
      let shape := if loop then
        "function w $f(w %limit) { @s jmp @loop @loop %i =w phi @s 0,@loop %next " ++ body ++ " %next =w add %i,1 %c =w cultw %next,%limit jnz %c,@loop,@done @done ret %next }"
      else "function w $f(w %limit) { @s jnz %limit,@yes,@no @yes " ++ body ++ " ret 0 @no ret 1 }"
      let original ← parse (data ++ shape)
      let input := original.functions[0]!
      let output := Symbols.hoist (original.data.map (·.name)) input
      if count == 8 then
        require (output.blocks[0]!.instructions.size == 8) "eight-address CFG hoisting boundary changed"
      else
        require (reprStr output == reprStr input) "nine-address CFG fallback changed the original function"
      for limit in (#[0,1,4] : Array UInt64) do
        let .ok expected := Semantics.evaluateModule original "f" #[limit]
          | throw (IO.userError "bounded symbol hoisting source evaluation failed")
        require ((Semantics.evaluateModule {original with functions := #[output]} "f" #[limit]).toOption == some expected)
          "bounded address hoisting changed branch or loop values"

private def discardedCallResults : IO Unit := do
  let source ← parse "dbgfile \"calls.c\" function l $effect(l %p,l %x,...) { @s %old =l loadl %p %next =l add %old,%x storel %next,%p ret 99 } function l $root(l %x) { @s %p =l alloc8 8 storel 0,%p %fn =l copy $effect %arg =l add %x,1 dbgloc 10 %unused =l call %fn(l %p,l %arg,...) dbgloc 11 %dead =l add %unused,3 dbgloc 12 %result =l loadl %p ret %result }"
  let cleaned := {source with functions := source.functions.map Cleanup.deadDefinitions}
  require (markerCounts cleaned == (1,1,1)) "unused scalar call result was retained or variadic marker lost"
  let body := cleaned.functions[1]!.blocks[0]!
  require (body.instructions.size == 6 && body.debugLocations.map (·.instruction) == #[4,5,5])
    "discarded call changed call position or dead-definition debug remapping"
  require (match body.instructions[4]! with
    | .callVoid (.indirect (.temporary "fn")) args true => args.size == 2
    | _ => false) "indirect call target or operands lost"
  for x in (#[0,1,4294967295,18446744073709551615] : Array UInt64) do
    for m in #[source,cleaned] do
      let .ok result := Semantics.evaluateModule m "root" #[x]
        | throw (IO.userError "discarded-result effect interpreter failed")
      require (result == some (x+1)) "discarding a result changed a call's visible memory effect"
  let retained ← parse "function l $f(l %p,l %fn) { @s %a =l call %fn() %b =l call %fn(l %a) storel %b,%p %c =l call %fn() jnz %c,@yes,@no @yes %d =l call %fn() ret %d @no ret 0 }"
  require (markerCounts {retained with functions := retained.functions.map Cleanup.deadDefinitions} == (4,0,0))
    "live call result feeding call/store/branch/return was discarded"
  let aggregate ← parse "type :big = { l 4 } function :big $make() { @s %p =l alloc8 32 ret %p } function $root() { @s %unused =:big call $make() ret }"
  require (markerCounts {aggregate with functions := aggregate.functions.map Cleanup.deadDefinitions} == (1,0,0))
    "unused aggregate call lost required return storage"

def run : IO Unit := do
  discardedCallResults
  symbolPlacement
  -- A marker without anonymous arguments must survive every call reconstruction.
  let marked ← parse "function $sink(l %x,...) { @s ret } export function l $root(l %fn,l %x) { @s %arg =l copy %x %unused =l call $sink(l %arg,...) %a =l add %x,1 %b =l add %x,1 %r =l call %fn(l %a,...) %copy =l copy %r jnz 1,@yes,@no @yes call %fn(l %b,...) ret %copy @no ret 0 }"
  require (markerCounts marked == (3,3,2)) "SSA lost empty marker or unused-result void conversion"
  let stages := #[marked,
    {marked with functions := marked.functions.map Cleanup.copies},
    {marked with functions := marked.functions.map Cleanup.deadDefinitions}]
  for stage in stages do
    require (markerCounts stage == (3,3,2)) "cleanup lost empty call marker"
  for stage in [marked.functions.mapM ControlFlow.simplify, marked.functions.mapM Common.eliminate] do
    match stage with
    | .ok fs => require (markerCounts {marked with functions := fs} == (3,3,2)) "CFG/Common lost empty call marker"
    | .error e => throw (IO.userError e)
  require (markerCounts (← optimize marked) == (3,3,2)) "full optimizer lost empty call marker"
  let namedFP ← parse "function l $f(d %x,...) { @s %bits =l cast %x ret %bits } export function l $root() { @s %r =l call $f(d d_1.5,...) ret %r }"
  let namedFP ← optimize namedFP
  match Semantics.evaluateModule namedFP "root" #[] with
  | .ok value => require (value == some 4609434218613702656) "empty-tail named FP call changed semantics"
  | .error e => throw (IO.userError e)
  match AMD64.emitModule namedFP with
  | .ok assembly => require (assembly.contains "movl $1, %eax") "empty-tail named FP call omitted AL count"
  | .error e => throw (IO.userError e)
  -- x9/t5 environment registers do not overlap variadic metadata on ARM/RV.
  for tail in ["", ",l 33"] do
    let env ← parse ("export function l $root() { @s %r =l call $external(env 9,d d_1.5,..." ++ tail ++ ") ret %r }")
    for emitted in [AArch64.emitModule env true, AArch64.emitModule env false, RV64.emitModule env] do
      match emitted with
      | .ok _ => pure ()
      | .error e => throw (IO.userError e)
    match AMD64.emitModule env with
    | .ok _ => throw (IO.userError "AMD64 accepted environment plus variadic marker")
    | .error e => require (e.contains "variadic environment calls") "unexpected AMD64 environment refusal"
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
  for (width, bits) in [("w",32),("l",64)] do
    for op in ["udiv","urem"] do
      for bit in [:bits] do
        let divisor := toString (2^bit : Nat)
        let m ← parse ("function " ++ width ++ " $f(l %x) { @s %r =" ++ width ++ " " ++ op ++ " %x," ++ divisor ++ " ret %r }")
        let optimized ← optimize m
        require (optimized.functions[0]!.blocks[0]!.instructions.all fun statement => match statement with
          | .assign {operation := .divide .., ..} => false | _ => true)
          "unsigned power-of-two division was not reduced"
        for x in (#[0,1,7,8,4294967295,4294967296,9223372036854775808,18446744073709551615] : Array UInt64) do
          require (same (Semantics.evaluate m.functions[0]! #[x]) (Semantics.evaluate optimized.functions[0]! #[x]))
            s!"unsigned division/remainder changed width: {width} {op} {divisor}"
  for (width, divisors) in [("w", ["1", "4294967297", "-4294967295", "18446744069414584321"]),
                             ("l", ["1", "-18446744073709551615"])] do
    for op in ["div", "rem"] do
      for divisor in divisors do
        let m ← parse ("function " ++ width ++ " $f(l %x) { @s %r =" ++ width ++ " " ++ op ++ " %x," ++ divisor ++ " ret %r }")
        let optimized ← optimize m
        require (optimized.functions[0]!.blocks[0]!.instructions.all fun statement => match statement with
          | .assign {operation := .divide .., ..} => false | _ => true)
          "signed division/remainder by normalized one was not reduced"
        for x in (#[0,1,4294967295,4294967296,2147483648,9223372036854775808,9223372036854775807,18446744073709551615] : Array UInt64) do
          require (same (Semantics.evaluate m.functions[0]! #[x]) (Semantics.evaluate optimized.functions[0]! #[x]))
            s!"signed division/remainder by one changed result width: {width} {op} {divisor}"
  for source in #[
    "function w $f(l %x) { @s %r =w div %x,4294967295 ret %r }",
    "function w $f(l %x) { @s %r =w rem %x,4294967296 ret %r }",
    "function l $f(l %x) { @s %r =l div %x,-1 ret %r }",
    "function w $f() { @s %x =w div -2147483648, -1 ret %x }",
    "function l $f() { @s %x =l udiv 17, 0 ret %x }",
    "function w $f(l %x) { @s %r =w udiv %x,4294967296 ret %r }",
    "function l $f(l %x) { @s %r =l urem %x,0 ret %r }",
    "function l $f(l %x) { @s %r =l div %x,8 ret %r }",
    "function w $f(l %x) { @s %r =w rem %x,8 ret %r }"] do
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
  -- Repeated, immediately consumed expressions must not keep an entire earlier
  -- batch live until a distant second batch. This models scalar-expanded copies.
  let mut pressureSource := "function l $pressure(l %x) { @s %sum0 =l copy 0 "
  for pass in [:2] do
    for i in [:128] do
      let n := pass * 128 + i
      let op := if pass == 0 then "xor" else "add"
      pressureSource := pressureSource ++ s!"%v{n} =l add %x, {i+1} %sum{n+1} =l {op} %sum{n}, %v{n} "
  pressureSource := pressureSource ++ "ret %sum256 }"
  let pressure ← parse pressureSource
  let pressureCleaned ← optimize pressure
  let live ← match Liveness.analyze pressureCleaned.functions[0]! with
    | .ok live => pure live
    | .error reason => throw (IO.userError reason)
  let maxLive := live.before.foldl (fun maximum points => points.foldl
    (fun maximum point => max maximum (live.members point).size) maximum) 0
  require (maxLive <= 12) "common expression reuse resurrected a distant batch of dead values"
  for x in (#[0,1,42,18446744073709551615] : Array UInt64) do
    let first := (List.range 128).foldl (fun acc i => acc ^^^ (x + UInt64.ofNat (i+1))) (0 : UInt64)
    let expected := (List.range 128).foldl (fun acc i => acc + (x + UInt64.ofNat (i+1))) first
    let actual ← match Semantics.evaluate pressureCleaned.functions[0]! #[x] with
      | .ok value => pure value
      | .error reason => throw (IO.userError reason)
    require (actual == expected)
      "common expression elimination changed the independently calculated batch result"
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
