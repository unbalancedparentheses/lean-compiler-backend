import LeanCompilerBackend.Parser
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.Verified.Job
import LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified.Tests

private def require (condition : Bool) (message : String) : IO Unit :=
  unless condition do throw (IO.userError message)

private def parse (text : String) : IO Function := do
  match Parser.parse text with
  | .ok fs =>
    let some f := fs[0]? | throw (IO.userError "empty test program")
    pure f
  | .error e => throw (IO.userError e)

private def admitted (text : String) : IO Source.Function := do
  match admit (← parse text) with
  | .ok f => pure f
  | .error e => throw (IO.userError s!"admission failed: {repr e}")

private def returns (text : String) (arguments : Array Int) (expected : Int)
    (fuel := 10000) : IO Unit := do
  let original ← parse text
  let f ← admitted text
  let args := (f.parameters.zip arguments).map fun (w, n) => Source.Value.constant w n
  let want := Source.Value.constant f.resultWidth expected
  let result := Source.evaluateFunction f args fuel
  require (decide (result = .returned want)) s!"wrong source result: {repr result}; expected {repr want}"
  let artifact ← match prepareJob original "tests" >>= compileFunction with
    | .ok a => pure a
    | .error e => throw (IO.userError s!"first-path compilation: {repr e}")
  for (stage, execution) in [
      ("MIR", Machine.evaluateMIR artifact.code.stackMIR args (fuel * 32)),
      ("assembly", Machine.evaluateAssembly artifact.code.assembly args (fuel * 32))] do
    match execution with
    | .returned value data =>
      require (decide (value = want)) s!"{stage} wrong value: {repr value}"
      require (data.sp == data.entrySP) s!"{stage} did not restore SP"
    | other => throw (IO.userError s!"{stage} execution failed: {repr other}")
  -- Independent expected constants are primary; agreement with the existing
  -- interpreter additionally guards the import boundary for exercised cases.
  match Semantics.evaluate original (arguments.map fun n => (BitVec.ofInt 64 n).toNat.toUInt64) with
  | .ok value => require (value.toNat == want.toNat) "compatibility interpreter mismatch"
  | other => throw (IO.userError s!"compatibility evaluation failed: {repr other}")

private def rejected (text : String) : IO Unit := do
  match admit (← parse text) with
  | .error _ => pure ()
  | .ok _ => throw (IO.userError s!"profile unexpectedly admitted: {text}")

private def loop := "function w $sum(w %n) {
@entry jmp @loop
@loop
%i =w phi @entry 0, @body %next
%s =w phi @entry 0, @body %sum
%more =w cultw %i, %n
jnz %more, @body, @exit
@body
%sum =w add %s, %i
%next =w add %i, 1
jmp @loop
@exit ret %s
}"

private def swap := "function w $swap(w %count) {
@entry jmp @loop
@loop
%a =w phi @entry 11, @body %b
%b =w phi @entry 22, @body %a
%i =w phi @entry 0, @body %next
%more =w cultw %i, %count
jnz %more, @body, @exit
@body %next =w add %i, 1
jmp @loop
@exit ret %a
}"

private def mustNext (f : Source.Function) (s : Source.State) : IO Source.State := do
  match Source.step f s with
  | .ok (.next t) => pure t
  | other => throw (IO.userError s!"expected next state: {repr other}")

private def initial (f : Source.Function) (args : Array Source.Value) : IO Source.State := do
  match Source.initial f args with
  | .ok s => pure s
  | .error e => throw (IO.userError s!"initial state: {repr e}")

private def arithmetic : IO Unit := do
  for w in ["w", "l"] do
    let maxValue : Int := if w == "w" then 4294967295 else 18446744073709551615
    for (op, a, b, expected) in [
        ("add", maxValue, 1, 0), ("sub", 0, 1, maxValue),
        ("mul", maxValue, 2, maxValue - 1),
        ("and", 170, 204, 136), ("or", 170, 204, 238), ("xor", 170, 204, 102)] do
      returns s!"function {w} $f({w} %a, {w} %b) \{ @s %r ={w} {op} %a, %b ret %r }"
        #[a,b] expected
    for (op, a, b, expected) in [
        ("ceq", maxValue, maxValue, 1), ("ceq", 0, maxValue, 0),
        ("cult", maxValue, 0, 0), ("cult", 0, maxValue, 1)] do
      returns s!"function w $f({w} %a, {w} %b) \{ @s %r =w {op}{w} %a, %b ret %r }"
        #[a,b] expected
    returns s!"function {w} $f() \{ @s %r ={w} copy -1 ret %r }" #[] maxValue
  returns "function w $f() { @s %r =w copy 4294967297 ret %r }" #[] 1
  returns "function l $f(w %unused, l %x) { @s %wide =l copy 4294967297 %r =l add %x, %wide ret %r }"
    #[123,18446744073709551615] 4294967296

private def control : IO Unit := do
  for (n, expected) in [(0,0),(1,0),(4,6),(100,4950)] do returns loop #[n] expected
  for (n, expected) in [(0,11),(1,22),(2,11),(3,22)] do returns swap #[n] expected
  returns "function l $mixed(w %n, l %x) {
@entry jmp @loop
@loop
%i =w phi @entry 0, @body %next
%v =l phi @entry %x, @body %updated
%more =w cultw %i, %n
jnz %more, @body, @exit
@body
%next =w add %i, 1
%updated =l add %v, 4294967296
jmp @loop
@exit ret %v
}" #[2,18446744073709551615] 8589934591
  returns "function w $f() { @s jnz 2, @yes, @no @yes ret 7 @no ret 9 }" #[] 7
  returns "function w $f() { @s jnz 0, @yes, @no @yes ret 7 @no ret 9 }" #[] 9
  returns "function w $f() { @s jnz 2, @end, @end @end %x =w phi @s 9 ret %x }" #[] 9
  returns "function w $f() { @s ret 7 }" #[] 7
  returns "function l $f(w %a, l %b, w %c, l %d, w %e, l %f, w %g, l %h) { @s ret %h }"
    #[1,2,3,4,5,6,7,8] 8
  let spin ← admitted "function w $spin() { @entry jmp @spin @spin jmp @spin }"
  for fuel in [0,1,2,100] do
    require (match Source.evaluateFunction spin #[] fuel with | .exhausted _ => true | _ => false)
      "spin must exhaust, never fabricate a return or divergence verdict"
  let ret ← admitted "function w $f() { @s ret 7 }"
  require (match Source.evaluateFunction ret #[] 0 with | .exhausted _ => true | _ => false)
    "zero budget must be inconclusive even for a returning function"
  -- Assert boundary values, not just the final result: staging reads the old env.
  let f ← admitted swap
  let s ← initial f #[.word 2]
  let mut s ← mustNext f s -- entry edge initializes all three phis
  require (s.environment[1]? == some (some (.word 11))) "entry a"
  require (s.environment[2]? == some (some (.word 22))) "entry b"
  for _ in [:4] do s ← mustNext f s -- comparison, branch, increment, backedge
  require (s.environment[1]? == some (some (.word 22))) "parallel a must use old b"
  require (s.environment[2]? == some (some (.word 11))) "parallel b must use old a"
  require (s.environment[3]? == some (some (.word 1))) "loop counter transfer"
  -- Identical semantics and numbering despite names/incoming-list permutations.
  let reordered ← admitted (swap.replace "@entry 11, @body %b" "@body %b, @entry 11")
  require (decide (f = reordered)) "incoming lists must be canonicalized"
  let renamed ← admitted (swap.replace "%a" "%renamed")
  require (decide (f = renamed)) "temporary names must not affect numbered syntax"

private def admissionFailures : IO Unit := do
  for text in [
      "function $f() { @s ret }",
      "function w $f() { @s hlt }",
      "function w $f(w %a) { @s %r =w shl %a, 1 ret %r }",
      "function w $f(w %a) { @s %r =w div %a, 1 ret %r }",
      "function w $f(w %a) { @s %r =w neg %a ret %r }",
      "function w $f(w %a) { @s %r =w csltw %a, 1 ret %r }",
      "function l $f(w %a) { @s %r =l ceqw %a, 1 ret %r }",
      "function w $f(l %a) { @s %r =w copy %a ret %r }",
      "function l $f(w %a) { @s %r =l copy %a ret %r }",
      "function w $f() { @s %r =w call $other() ret %r }",
      "function w $f() { @s call $other() ret 0 }",
      "function w $f(l %p) { @s %r =w loadw %p ret %r }",
      "function w $f(l %p) { @s storew 1, %p ret 0 }",
      "function w $f(l %p) { @s blit %p, %p, 0 ret 0 }",
      "function l $f() { @s %p =l alloc8 8 ret %p }",
      "function w $f() { @s ret 0 @unreachable ret 1 }",
      "function w $f() { @s jmp @s }",
      "function w $f() { @s %x =w add %missing, 1 ret %x }",
      "function w $f() { @s %x =w copy 1 %x =w copy 2 ret %x }",
      "function w $f(w %c) { @s jnz %c, @a, @b @a %x =w copy 1 jmp @b @b ret %x }",
      "function w $f() { @s jmp @b @b %x =w phi @b 1 ret %x }"] do
    rejected text
  let nine ← parse "function w $f(w %a,w %b,w %c,w %d,w %e,w %f,w %g,w %h,w %i) { @s ret %i }"
  require (match admit nine with | .error (.resourceLimit "parameters" 9 8) => true | _ => false)
    "argument limit must have a resource outcome"
  -- Each phi needs one value slot and one staging slot. Exercise the frame
  -- cap independently of the 480-definition cap.
  let makeFrame (count : Nat) :=
    let phis := String.intercalate " " ((List.range count).map fun i => s!"%v{i} =w phi @s {i}")
    s!"function w $f() \{ @s jmp @end @end {phis} ret 0 }"
  let _ ← admitted (makeFrame 255) -- (255 values + 255 stages)*8 = 4080
  let oversized ← parse (makeFrame 256)
  require (match admit oversized with | .error (.resourceLimit "frame bytes" 4096 4080) => true | _ => false)
    "frame overflow must reject"

private def faultControls : IO Unit := do
  let f ← admitted "function w $f(w %x) { @s ret %x }"
  require (decide (Source.evaluateFunction f #[] 1 = .stuck .arity)) "arity fault"
  require (decide (Source.evaluateFunction f #[.long 1] 1 = .stuck .widthMismatch)) "argument width fault"
  let s ← initial f #[.word 1]
  require (decide (Source.run f 1 { s with environment := #[none] } = .stuck (.missingValue 0)))
    "missing SSA values must not default to zero"
  require (decide (Source.run f 1 { s with block := 99 } = .stuck (.invalidBlock 99))) "invalid block"
  require (decide (Source.run f 1 { s with position := 1 } = .stuck .invalidPosition)) "invalid PC"
  let cyclic ← admitted swap
  let state ← initial cyclic #[.word 1]
  let state ← mustNext cyclic state
  -- Raw syntax is not CheckedSSA. Malformed transfers must fail at runtime too.
  let some loopBlock := cyclic.blocks[1]? | throw (IO.userError "missing loop block")
  let some phi := loopBlock.phis[0]? | throw (IO.userError "missing phi")
  let duplicate := { phi with incoming := phi.incoming ++ phi.incoming }
  let brokenBlock := { loopBlock with phis := loopBlock.phis.set! 0 duplicate }
  let broken := { cyclic with blocks := cyclic.blocks.set! 1 brokenBlock }
  require (match Source.transfer broken 0 1 state.environment with | .error (.invalidPhi 1) => true | _ => false)
    "duplicate incoming transfer must fail"

def run : IO Unit := do
  arithmetic
  control
  admissionFailures
  faultControls
  IO.println "first-path source semantics/admission checks passed"

end LeanCompilerBackend.Verified.Tests
