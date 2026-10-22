import LeanCompilerBackend.Optimize.Memory
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.Parser

namespace LeanCompilerBackend.Optimize.MemoryTests

private def parse (s : String) : IO Function :=
  match Parser.parseModule s >>= SSA.constructModule with
  | .ok m => pure m.functions[0]!
  | .error e => throw (IO.userError e)
private def memoryCount (f : Function) : Nat := f.blocks.foldl (fun n b => n +
  (b.instructions.filter fun s => match s with
    | .assign {operation := .allocate .., ..} | .assign {operation := .load .., ..}
    | .store .. | .storeFloat .. => true | _ => false).size) 0
private def require (condition : Bool) (why : String) : IO Unit :=
  unless condition do throw (IO.userError why)
private def agrees (f g : Function) (args : Array UInt64) : Bool :=
  match Semantics.evaluate f args, Semantics.evaluate g args with
  | .ok a, .ok b => a == b | _, _ => false

def run : IO Unit := do
  for (bytes, suffix) in #[(1, "b"), (2, "h")] do
    for signedness in #["s", "u"] do
      for width in #["w", "l"] do
        let text := "function " ++ width ++ " $f(l %x) { @s %p =l alloc4 " ++ toString bytes ++
          " store" ++ suffix ++ " %x,%p %v =" ++ width ++ " load" ++ signedness ++ suffix ++ " %p ret %v }"
        let original ← parse text
        let result := Memory.promote original
        require (memoryCount result == 0) "narrow scalar did not promote"
        for x in (#[0,1,127,128,255,256,32767,32768,65535,65536,4294967295,18446744073709551615] : Array UInt64) do
          require (agrees original result #[x]) "narrow promotion lost store truncation or load signedness"
  for source in #[
    "function w $f() { @s %p =l alloc4 1 %r =w loadub %p ret %r }",
    "function w $f() { @s %p =l alloc4 2 storeh 65535,%p storeb 0,%p %r =w loaduh %p ret %r }",
    "function w $f() { @s %p =l alloc4 1 storeb 17,%p call $touch(l %p) %r =w loadub %p ret %r }"] do
    let original ← parse source
    require (memoryCount (Memory.promote original) == memoryCount original)
      "unsupported narrow object was promoted"
  let branch ← parse "function l $f(l %x,w %c) { @s %p =l alloc8 8 jnz %c,@a,@b @a storel %x,%p jmp @done @b storel 17,%p jmp @done @done %v =l loadl %p ret %v }"
  let result := Memory.promote branch
  require (memoryCount result == 0 && result.blocks.any (!·.phis.isEmpty)) "branch stores did not become SSA phis"
  for x in (#[0,17,4294967295,18446744073709551615] : Array UInt64) do
    for c in (#[0,1] : Array UInt64) do require (agrees branch result #[x,c]) "branch promotion changed result"
  let loop ← parse "function l $f(l %n) { @s %p =l alloc8 8 storel 0,%p jmp @loop @loop %v =l loadl %p %next =l add %v,1 storel %next,%p %c =w cultl %next,%n jnz %c,@loop,@done @done %r =l loadl %p ret %r }"
  let result := Memory.promote loop
  require (memoryCount result == 0) "loop variable did not promote"
  for n in (#[1,2,10,50] : Array UInt64) do require (agrees loop result #[n]) "loop promotion changed result"
  let floating ← parse "function d $f(d %x) { @s %p =l alloc8 8 stored %x,%p %r =d loadd %p ret %r }"
  let result := Memory.promote floating
  require (memoryCount result == 0) "floating scalar did not promote"
  for x in (#[0,9223372036854775808,9221140253039434428] : Array UInt64) do
    require (agrees floating result #[x]) "floating promotion changed raw bits"
  for source in #[
    "function l $f(w %c) { @s %p =l alloc8 8 jnz %c,@a,@b @a storel 17,%p jmp @done @b jmp @done @done %r =l loadl %p ret %r }",
    "function l $f() { @s %p =l alloc8 8 storel 17,%p call $touch(l %p) %r =l loadl %p ret %r }",
    "function l $f() { @s %p =l alloc8 8 storel 17,%p storew 3,%p %r =l loadl %p ret %r }",
    "function d $f() { @s %p =l alloc8 8 storel 17,%p %r =d loadd %p ret %r }",
    "function l $f() { @s %p =l alloc8 8 %q =l add %p,0 storel 17,%q %r =l loadl %p ret %r }",
    "function l $f() { @s jmp @b @b %p =l alloc8 8 storel 17,%p %r =l loadl %p ret %r }"] do
    let original ← parse source
    require (memoryCount (Memory.promote original) == memoryCount original)
      "unsafe/partial/escaping/uninitialized/nonentry object was promoted"
  let collision ← parse "function l $f(l %lcb.mem.0) { @s %p =l alloc8 8 storel %lcb.mem.0,%p %v =l loadl %p ret %v }"
  let result := Memory.promote collision
  require (memoryCount result == 0 && agrees collision result #[42]) "promotion name collision"
  let debug := {collision with debugFile := some "memory.c", blocks := collision.blocks.map fun b => {b with
    debugLocations := #[{instruction := 0, line := 1, column := 1}, {instruction := 3, line := 2, column := 1}]}}
  let result := Memory.promote debug
  require (result.blocks[0]!.debugLocations[1]!.instruction == 2) "promotion did not remap debug positions"
  -- Exercise forwarding directly: large objects deliberately cannot promote.
  for (store, load, width) in #[("b","sb","w"),("b","ub","l"),("h","sh","l"),
      ("h","uh","w"),("w","sw","l"),("w","uw","l"),("w","w","w"),("l","l","l")] do
    let original ← parse ("function " ++ width ++ " $f(l %x) { @s %p =l alloc8 32 store" ++ store ++
      " %x,%p %v =" ++ width ++ " load" ++ load ++ " %p ret %v }")
    let result := Memory.forward original
    require (memoryCount result == memoryCount original - 1) "same-address store did not forward"
    for x in (#[0,127,128,255,256,32767,32768,65535,2147483648,4294967295,18446744073709551615] : Array UInt64) do
      require (agrees original result #[x]) s!"store forwarding changed {store}/{load}/{width} input {x}: {reprStr (Semantics.evaluate original #[x])} vs {reprStr (Semantics.evaluate result #[x])}"
  for (width,suffix) in #[("s","s"),("d","d")] do
    let original ← parse ("function " ++ width ++ " $f(" ++ width ++ " %x) { @s %p =l alloc8 32 store" ++ suffix ++
      " %x,%p %v =" ++ width ++ " load" ++ suffix ++ " %p ret %v }")
    let result := Memory.forward original
    require (memoryCount result == memoryCount original - 1) "floating store did not forward"
    for x in (#[0,2147483648,2143289345,9223372036854775808,9221140253039434428] : Array UInt64) do
      require (agrees original result #[x]) "floating store forwarding changed raw bits"
  let repeated ← parse "function l $f(l %p) { @s %a =l loadl %p %b =l loadl %p %r =l add %a,%b ret %r }"
  require (memoryCount (Memory.forward repeated) == 1) "repeated load did not forward"
  for source in #[
    "function l $f(l %p,l %q) { @s %a =l loadl %p storel 7,%q %b =l loadl %p ret %b }",
    "function l $f(l %p) { @s %a =l loadl %p call $touch(l %p) %b =l loadl %p ret %b }",
    "function l $f(l %p) { @s %a =l loadl %p %v =l call $touch(l %p) %b =l loadl %p ret %b }",
    "function l $f(l %p,l %q) { @s %a =l loadl %p blit %q,%p,8 %b =l loadl %p ret %b }",
    "function l $f(l %p) { @s %a =l loadl %p %q =l alloc8 8 %b =l loadl %p ret %b }",
    "function l $f(l %p) { @s %a =l loadl %p jmp @next @next %b =l loadl %p ret %b }",
    "function l $f(l %p) { @s %a =w loadw %p %b =l loadl %p ret %b }",
    "function l $f(l %p) { @s storeb 7,%p %b =l loadl %p ret %b }",
    "function d $f(l %p) { @s storel 7,%p %b =d loadd %p ret %b }"] do
    let original ← parse source
    require (memoryCount (Memory.forward original) == memoryCount original)
      "forwarding crossed a write/call/block boundary or incompatible access"
  for barrier in #["call $touch(l %p)", "%v =l call $touch(l %p)",
      "%v =l vaarg %p", "vastart %p", "%q =l alloc8 8", "blit %q,%p,8"] do
    let parameters := if barrier == "vastart %p" then "l %p,l %q,..." else "l %p,l %q"
    for initialStatement in #["storel 17,%p", "%a =l loadl %p"] do
      let original ← parse ("function l $f(" ++ parameters ++ ") { @s " ++ initialStatement ++ " " ++ barrier ++
        " %b =l loadl %p ret %b }")
      require (memoryCount (Memory.forward original) == memoryCount original)
        "memory barrier retained a stored-value or repeated-load fact"
  for source in #[
    "function l $f(l %p) { @s %a =l loadsb %p %b =l loadub %p ret %b }",
    "function d $f(l %p) { @s %a =l loadl %p %b =d loadd %p ret %b }"] do
    let original ← parse source
    require (memoryCount (Memory.forward original) == memoryCount original)
      "load cache merged distinct signedness or integer/FP classes"
  let forwardedDebug := Memory.forward {repeated with blocks := repeated.blocks.map fun b => {b with
    debugLocations := #[{instruction := 2, line := 9, column := 1}]}}
  require (forwardedDebug.blocks[0]!.debugLocations[0]!.instruction == 2) "forwarding moved debug positions"
  for (load, extension, width, bytes, store) in #[
      ("sb", "sb", "w", 1, "b"), ("ub", "ub", "l", 1, "b"),
      ("sh", "sh", "l", 2, "h"), ("uh", "uh", "w", 2, "h"),
      ("sw", "sw", "l", 4, "w"), ("uw", "uw", "l", 4, "w")] do
    let original ← parse ("function " ++ width ++ " $f(l %x) { @s %p =l alloc8 " ++ toString bytes ++
      " store" ++ store ++ " %x,%p %a =" ++ width ++ " load" ++ load ++ " %p " ++
      " storeb 0,%p %b =" ++ width ++ " ext" ++ extension ++ " %a ret %b }")
    let result := Memory.eliminateExtensions original
    match result.blocks[0]!.instructions[4]! with
    | .assign {operation := .copy (.temporary name), ..} => require (name == "a") "load extension source changed"
    | _ => throw (IO.userError "matching same-width extension was not removed")
    require (memoryCount result == memoryCount original) "extension cleanup removed a memory access"
    for x in (#[0,127,128,255,32767,32768,65535,2147483648,4294967295,18446744073709551615] : Array UInt64) do
      require (agrees original result #[x]) "extension cleanup changed signedness or SSA value after store"
  for source in #[
    "function l $f(l %p) { @s %a =w loadsw %p %b =l extsw %a ret %b }",
    "function l $f(l %p) { @s %a =l loadub %p %b =l extsb %a ret %b }",
    "function l $f(l %p) { @s %a =l loadl %p %b =l extub %a ret %b }",
    "function l $f(l %p) { @s %a =l loadsh %p %b =l extsb %a ret %b }",
    "function w $f(l %p) { @s %a =l loadsh %p %b =w extsh %a ret %b }"] do
    let original ← parse source
    let result := Memory.eliminateExtensions original
    match result.blocks[0]!.instructions[1]! with
    | .assign {operation := .unary .., ..} => pure ()
    | _ => throw (IO.userError "unsafe cross-width/mismatched/plain-load extension removed")
  let successor ← parse "function l $f(l %p) { @s %a =l loaduh %p jmp @next @next %b =l extuh %a ret %b }"
  let result := Memory.eliminateExtensions successor
  match result.blocks[1]!.instructions[0]! with
  | .assign {operation := .copy (.temporary name), ..} => require (name == "a") "successor load source changed"
  | _ => throw (IO.userError "dominated matching extension was not removed")
  let mixedPhi ← parse "function l $f(l %p,w %c) { @s %a =l loaduh %p jnz %c,@yes,@no @yes jmp @join @no jmp @join @join %v =l phi @yes %a,@no 65536 %b =l extuh %v ret %b }"
  let result := Memory.eliminateExtensions mixedPhi
  match result.blocks[3]!.instructions[0]! with
  | .assign {operation := .unary .., ..} => pure ()
  | _ => throw (IO.userError "mixed phi inherited an invalid narrowing fact")
  IO.println "load extension cleanup: same-width signedness, retained loads/effects and cross-width guards passed"
  IO.println "same-block memory forwarding: exact addresses, integer extensions, FP bits, alias/call/blit/allocation/block guards passed"
  IO.println "scalar stack promotion: branches, loops, FP bits, initialization/escape/width guards and debug positions passed"

end LeanCompilerBackend.Optimize.MemoryTests
