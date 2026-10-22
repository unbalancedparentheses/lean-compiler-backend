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
  let mixedSource := "export function w $long_then_word(l %input, w %n) {\n@s\n %v =l copy %input\n %v =w add %v, 1\n ret %v\n}\nexport function w $word_then_long(l %input, w %n) {\n@s\n %v =w copy %n\n %v =l add %input, 3\n ret %v\n}\nexport function w $parameter_long(l %input, w %n) {\n@s\n %input =w add %input, 17\n ret %input\n}\nexport function w $parameter_word(l %input, w %n) {\n@s\n %n =l add %input, 23\n ret %n\n}\nexport function w $branch(l %input, w %n) {\n@s\n %flag =w and %n, 1\n jnz %flag, @wide, @narrow\n@wide\n %v =l add %input, 7\n jmp @join\n@narrow\n %v =w add %input, 13\n jmp @join\n@join\n %v =w xor %v, 305419896\n ret %v\n}\nexport function w $loop(l %input, w %n) {\n@s\n %v =l copy %input\n %i =w copy 0\n jnz %n, @body, @done\n@body\n %v =w add %v, 3\n %wide =l extuw %v\n %v =l add %wide, 7\n %i =w add %i, 1\n %more =w cultw %i, %n\n jnz %more, @body, @done\n@done\n ret %v\n}\nexport function w $shift(l %input, w %n) {\n@s\n %v =l copy %input\n %v =w add %v, %n\n %wide =l shl %input, %v\n %r =w copy %wide\n ret %r\n}\nfunction w $called(w %x) {\n@s\n %r =w mul %x, 7\n ret %r\n}\nexport function w $call_word(l %input, w %n) {\n@s\n %v =l copy %input\n %v =w add %v, %n\n %r =w call $called(w %v)\n ret %r\n}\nexport function w $word_roles(l %input, w %n) {\n@s\n %v =l copy %input\n %v =w xor %v, %n\n %f =s cast %v\n %bits =w cast %f\n %p =l alloc8 8\n storew %bits, %p\n %r =w loadw %p\n ret %r\n}\n"
  let mixed ← match Parser.parseModule mixedSource >>= SSA.constructModule with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (valueEquals (Semantics.evaluateModule mixed "long_then_word" #[4294967295, 0]) (some 0))
    "mixed mutable long-to-word arithmetic must wrap"
  require (valueEquals (Semantics.evaluateModule mixed "word_then_long" #[4294967295, 0]) (some 2))
    "mixed mutable word-to-long definitions preserve low-word results"
  require (valueEquals (Semantics.evaluateModule mixed "parameter_long" #[4294967295, 0]) (some 16))
    "mixed mutable parameter widths must preserve incoming ABI width"
  require (valueEquals (Semantics.evaluateModule mixed "loop" #[4294967295, 8]) (some 79))
    "mixed mutable loop joins must use word phis"
  let loop := (mixed.functions.find? (·.name == "loop")).getD default
  require (loop.blocks.any (fun b => b.phis.any (fun p => p.width == .word)))
    "mixed mutable loop must retain word-class SSA joins"
  require (loop.blocks.any (fun b => b.instructions.any (fun s => match s with
      | .assign i => i.width == .long
      | _ => false))) "mixed mutable lowering must retain long instruction widths"
  require (isFailure (Parser.parseModule "function w $bad(l %input){\n@s\n %v =l copy %input\n %r =l add %v,1\n %v =w copy 1\n ret 0\n}\n" >>= SSA.constructModule))
    "raw mixed class must reject invalid before_narrow"
  require (isFailure (Parser.parseModule "function w $bad(l %input) {\n@s\n %v =l copy %input\n %v =w copy 1\n ret %v\n@dead\n %r =l copy %v\n ret 0\n}\n" >>= SSA.constructModule))
    "raw mixed class must reject invalid dead_long"
  require (isFailure (Parser.parseModule "function w $bad(l %input){\n@s\n %v =l copy %input\n %r =l add %v,1\n ret 0\n@dead\n %v =w copy 1\n ret 0\n}\n" >>= SSA.constructModule))
    "raw mixed class must reject invalid dead_definition"
  require (isFailure (Parser.parseModule "function w $bad(l %input) {\n@s\n %v =l copy %input\n %v =w copy 1\n %v =s copy s_1\n ret 0\n}\n" >>= SSA.constructModule))
    "raw mixed class must reject invalid mixed_float"
  let rawMixed ← match Parser.parseModule "function w $bad(l %input){\n@s\n %v =l copy %input\n %r =l add %v,1\n %v =w copy 1\n ret 0\n}\n" with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (isFailure (SSA.construct rawMixed.functions[0]!))
    "public SSA construction must enforce raw mixed-use guard"
  for source in ["type :a = { l 2 } type :b = { l, l }",
      "type :a = { d, l } type :b = { l, d }",
      "type :x = { l } type :y = { d } type :a = { :x } type :b = { :y }"] do
    let shapes ← match Parser.parseModule source with
      | .ok m => pure m
      | .error e => throw (IO.userError e)
    require (!Aggregate.signatureMatches (Aggregate.signatureAliases shapes.types) (some "a") (some "b"))
      "aggregate aliases must preserve repetition, field order and nested scalar class"
  let aliasSource := "type :a = { l } type :b = { l } type :outera = { :a } type :outerb = { :b } function :outera $echo(:outera %p) { @s ret %p } export function l $alias() { @s %p =l alloc8 8 storel 42, %p %fp =l copy $echo %r =:outerb call %fp(:outerb %p) %v =l loadl %r ret %v }"
  let aliases ← match Parser.parseModule aliasSource >>= SSA.constructModule with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (valueEquals (Semantics.evaluateModule aliases "alias" #[]) (some 42))
    "nested aggregate aliases must agree in indirect interpreter signatures"
  let directAliases ← match Parser.parseModule (aliasSource.replace "call %fp" "call $echo") >>= SSA.constructModule with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  require (valueEquals (Semantics.evaluateModule directAliases "alias" #[]) (some 42))
    "nested aggregate aliases must agree in direct interpreter signatures"
  require (isFailure (validate directAliases.functions))
    "Program-only validation without aggregate declarations remains nominal"
  for replacement in ["type :b = { d }", "type :b = align 8 { l }",
      "type :b = { { l } }", "type :b = align 8 { 8 }"] do
    require (isFailure (Parser.parseModule ((aliasSource.replace "call %fp" "call $echo").replace "type :b = { l }" replacement) >>= SSA.constructModule))
      "aggregate signature equivalence must preserve exact declaration shape"
  let printable := String.ofList ((List.range 95).map fun n => Char.ofNat (n+32))
  require (valueEquals (Section.checkTarget false (some ⟨printable, some "aw"⟩)) ())
    "ELF printable ASCII names rejected"
  for name in ["", String.ofList (List.replicate 129 'a'), "a\n", "a\t", "a" ++ String.singleton (Char.ofNat 127), "λ"] do
    require (isFailure (Section.checkTarget false (some ⟨name, some "aw"⟩)))
      "ELF invalid decoded name admitted"
  let escaped := Assembly.sectionDirective false ⟨"a\"b\\c", some "aw"⟩
  require (escaped == ".section \"a\\\"b\\\\c\",\"aw\"")
    "ELF section quote/backslash escaping changed decoded bytes"
  require (Assembly.sectionDirective false ⟨"foo,bar", some "aw"⟩ == ".section \"foo,bar\",\"aw\"")
    "ordinary ELF section spelling changed"
  require (isFailure (Section.checkTarget true (some ⟨"a b", some "aw"⟩)))
    "Apple section grammar broadened with ELF"
  for flags in ["aR", "awR", "axR", "Rwa", "Ra", "R"] do
    require (valueEquals (Section.checkTarget false (some ⟨".retain", some flags⟩)) ())
      "ELF retain flag rejected"
  for flags in ["awT", "axG", "aR,extra", "aR\\n"] do
    require (isFailure (Section.checkTarget false (some ⟨".retain", some flags⟩)))
      "ELF retain broadened unrelated flag grammar"
  require (valueEquals (Section.checkTarget true (some ⟨"__DATA", some "aR"⟩)) ())
    "Apple literal second-field section name changed"
  for flags in ["awTR", "RawT", "TRwa"] do
    require (valueEquals (Section.checkDataTarget false true (some ⟨".retained_tls", some flags⟩)) ())
      "ELF retained writable TLS rejected"
    require (isFailure (Section.checkDataTarget true true (some ⟨".retained_tls", some flags⟩)))
      "Apple custom TLS must remain refused with R"
  for flags in ["aTR", "wTR", "awR", "awTRx", "awTRG"] do
    require (isFailure (Section.checkDataTarget false true (some ⟨".retained_tls", some flags⟩)))
      "retained TLS must still require awT and reject unrelated flags"
  let tlsSection : SectionSpec := ⟨".custom_tls", some "awT"⟩
  require (valueEquals (Section.checkDataTarget false true (some tlsSection)) ())
    "ELF custom TLS section rejected"
  require (isFailure (Section.checkDataTarget true true (some tlsSection)))
    "Apple custom TLS must remain rejected"
  require (isFailure (Section.checkDataTarget false false (some tlsSection)))
    "ordinary data must reject TLS flags"
  for flags in [none, some "aw", some "aT", some "wT", some "awTx"] do
    require (isFailure (Section.checkTLS {tlsSection with flags}))
      "custom TLS accepted missing/incompatible flags"
  let tlsModule ← match Parser.parseModule
      "section \".custom_tls\" \"awT\" export thread data $tls = { l 37 }" with
    | .ok m => pure m
    | .error e => throw (IO.userError e)
  let tlsAssembly := Assembly.emitData false tlsModule.data[0]!
  require ((tlsAssembly.splitOn ".section \".custom_tls\",\"awT\"").length == 2)
    "TLS emitter lost custom section"
  require ((tlsAssembly.splitOn "%tls_object").length == 2)
    "TLS emitter lost symbol kind"
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
