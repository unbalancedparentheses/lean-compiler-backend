import LeanCompilerBackend
import LeanCompilerBackend.AArch64.Tests
import LeanCompilerBackend.AMD64.Tests
import LeanCompilerBackend.Driver.Tests
import LeanCompilerBackend.CFG.Tests
import LeanCompilerBackend.Liveness.Tests
import LeanCompilerBackend.Allocation.Tests
import LeanCompilerBackend.Optimize.Tests
import LeanCompilerBackend.Optimize.MemoryTests
import LeanCompilerBackend.Verified.Tests
import LeanCompilerBackend.Verified.JobTests
import LeanCompilerBackend.Verified.CodecTests

open LeanCompilerBackend

private def sample := "export function w $add(w %a, w %b) { @start %r =w add %a, %b ret %r }"

private def require (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def isFailure : Except ε α → Bool
  | .error _ => true
  | .ok _ => false

private def valueEquals [BEq α] (result : Except ε α) (expected : α) : Bool :=
  match result with
  | .ok actual => actual == expected
  | .error _ => false

def main : IO Unit := do
  let sectionModule ← match Parser.parseModule
      "section \"foo,ax\" data $literal = { l 1 } section \"foo,ax\" \"aw\" data $flagged = { l 2 } section \"foo\" \"ax\" function $code() { @s ret }" with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (sectionModule.data[0]!.customSection == some ⟨"foo,ax", none⟩)
    "section parser must preserve a literal comma without inventing flags"
  require (sectionModule.data[1]!.customSection == some ⟨"foo,ax", some "aw"⟩)
    "section parser must retain explicit flags separately from a comma-containing name"
  require (sectionModule.functions[0]!.customSection == some ⟨"foo", some "ax"⟩)
    "function section parser must retain the original two-string boundary"
  for darwin in [false, true] do
    require (valueEquals (Section.checkTarget darwin sectionModule.functions[0]!.customSection) ())
      "ambiguous two-string sections must be interpreted by the selected target"
  let discardedSource := "data $seen = { l 0 } function d $floating() { @s storel 41, $seen ret d_1.5 } function sb $narrow() { @s %v =l loadl $seen %n =l add %v, 1 storel %n, $seen ret 255 } function $nothing() { @s ret } export function l $discarded() { @s call $floating() call $narrow() call $nothing() %r =l loadl $seen ret %r }"
  let discarded ← match Parser.parseModule discardedSource >>= SSA.constructModule with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (valueEquals (Semantics.evaluateModule discarded "discarded" #[]) (some 42))
    "effect-only calls must discard scalar results while preserving effects"
  let aggregateDiscard := "type :big = { l 4 } function :big $aggregate() { @s %p =l alloc8 32 ret %p } export function $bad() { @s call $aggregate() ret }"
  require (isFailure (Parser.parseModule aggregateDiscard >>= SSA.constructModule))
    "effect-only call must not omit aggregate result storage"
  AArch64.Tests.run
  AMD64.Tests.run
  Driver.Tests.run
  CFG.Tests.run
  Liveness.Tests.run
  Allocation.Tests.run
  Optimize.Tests.run
  Optimize.MemoryTests.run
  Verified.Tests.run
  Verified.JobTests.run
  Verified.CodecTests.run
  let program ← match Parser.parse sample with
    | .ok p => pure p
    | .error e => throw (IO.userError e)
  require (valueEquals (validate program) ()) "sample should validate"
  require (valueEquals (Semantics.evaluate program[0]! #[4294967295, 2]) 1) "word addition must wrap"
  require (valueEquals (Semantics.evaluate program[0]! #[10, 20]) 30) "word addition result"
  let chained ← match Parser.parse "function w $f(w %a) { @s %v0 =w and %a, %a %v1 =w add %v0, %v0 ret %v1 }" with
    | .ok p => pure p
    | .error e => throw (IO.userError e)
  require (valueEquals (Semantics.evaluate chained[0]! #[4294967295]) 4294967294)
    "interpreter must continue after each binary instruction"
  require (isFailure (Semantics.evaluate program[0]! #[])) "arity mismatch must reject"
  require (!(isFailure (Parser.parse "export function d $float() { @s ret d_0 }"))) "floating signature should parse"
  require (isFailure (Parser.parse "export function :pair $bad() { @s ret 0 }")) "aggregate signature must reject"
  require (isFailure (Parser.parse "function w $bad() { @s ret 0 } trailing")) "surplus input must reject"
  let bare ← match Parser.parse "function w $bare() { @s ret }" with
    | .ok p => pure p
    | .error e => throw (IO.userError e)
  require (valueEquals (validateFunction bare[0]! true) ()) "compatibility bare typed return must validate"
  require (isFailure (validateFunction bare[0]!)) "first-path bare typed return must reject"
  let deadInput := "function l $dead(l %x) { @s %v =l add %x,17 jmp @join @unreachable jmp @join @join %p =l phi @s %v,@unreachable 0 %r =l add %p,%v ret %r }"
  let raw ← match Parser.parseModule deadInput with
    | .ok m => pure m | .error e => throw (IO.userError e)
  require (isFailure (validateModule raw)) "raw unreachable predecessor should expose dominance restriction"
  let normalized ← match SSA.constructModule raw with
    | .ok m => pure m | .error e => throw (IO.userError e)
  require (normalized.functions[0]!.blocks.size == 2 && normalized.functions[0]!.blocks[1]!.phis[0]!.incoming.size == 1)
    "compatibility normalization must remove dead blocks and their phi incoming edges"
  require (valueEquals (Semantics.evaluate normalized.functions[0]! #[25]) 84) "dead predecessor normalization changed value"
  for malformed in #[
    "function l $f() { @s jmp @join @join %v =l phi @missing 0 ret %v }",
    "function l $f() { @s jmp @join @unused jmp @missing @join ret 1 }"] do
    require (isFailure (Parser.parseModule malformed >>= SSA.constructModule)) "unreachable pruning hid a malformed CFG"
  let largeObject ← match Parser.parseModule "function l $large(l %x) { @s %p =l alloc16 4704 %q =l add %p,4696 storel %x,%q %r =l loadl %q ret %r }" >>= SSA.constructModule with
    | .ok m => pure m.functions[0]! | .error e => throw (IO.userError e)
  require (valueEquals (Semantics.evaluate largeObject #[123456789]) 123456789) "large constant object tail changed value"
  require (isFailure (validateFunction largeObject)) "restricted validator allocation bound changed"
  for size in #[4097,1048576] do
    require (!isFailure (Parser.parseModule s!"function l $f() \{ @s %p =l alloc16 {size} ret 0 }" >>= SSA.constructModule)) "compatibility large allocation admission failed"
  require (isFailure (Parser.parseModule "function l $f() { @s %p =l alloc16 1048577 ret 0 }" >>= SSA.constructModule)) "oversized constant allocation admitted"
  let aggregate ← match Parser.parseModule "type :record = { d } type :union = { { d } }" with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (!aggregate.types[0]!.isUnion && aggregate.types[1]!.isUnion)
    "single-variant unions must retain their ABI identity"
  require (isFailure (Parser.parse "type :record = { w } function w $f() { @s ret 0 }"))
    "function-only parsing must not silently discard aggregate types"
  IO.println "unit checks passed"
