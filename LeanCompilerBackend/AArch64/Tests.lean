import LeanCompilerBackend.AArch64
import LeanCompilerBackend.Parser

namespace LeanCompilerBackend.AArch64.Tests

/-- Independently enumerate rotated runs of ones and replicate the elements.
    The selector instead recognizes repeated elements and counts transitions. -/
private def encodings (width : Width) : Std.HashSet Nat := Id.run do
  let mut result := {}
  for size in #[2,4,8,16,32,64] do
    if size > width.bits then break
    for ones in [1:size] do
      let run := 2^ones-1
      for rotation in [:size] do
        let element := ((run >>> rotation) ||| (run <<< (size-rotation))) &&& (2^size-1)
        let mut value := 0
        for i in [:width.bits/size] do value := value ||| (element <<< (i*size))
        result := result.insert value
  return result

def run : IO Unit := do
  let bank := #[19,20,21,22,23,24,25,26,27,28,16,17,8]
  let tests := [
    ("@s\n %a =l add %x,1\n ret %a",true),
    ("@s\n call $other()\n ret %x",false),
    ("@s\n %a =l call %x()\n ret %a",false),
    ("@s\n %a =l copy thread $slot\n ret %a",false),
    ("@s\n storel thread $slot,%x\n ret %x",false),
    ("@s\n ret thread $slot",false),
    ("@s\n jnz thread $slot,@yes,@no\n@yes\n ret %x\n@no\n ret %x",false),
    ("@s\n jmp @join\n@join\n %a =l phi @s thread $slot\n ret %a",false),
    ("@s\n ret %x\n@unreachable\n call $other()\n ret %x",false)]
  for (body,expected) in tests do
    let m ← match Parser.parseModule ("function l $bank(l %x) {\n"++body++"\n}\n") with
      | .ok m => pure m | .error e => throw (IO.userError e)
    let f := m.functions[0]!
    unless (checkPhysicalBank f bank).isOk == expected do throw (IO.userError s!"ARM leaf-bank eligibility differs for {body}")
    unless !(checkPhysicalBank f #[19,20,21,22,23,24,25,26,27,28,15,17,8]).isOk do
      throw (IO.userError "ARM scratch-bank mutation accepted")
  unless leafBranchesLocal ["L_a:","\tb L_a","1:","\tb.ne 1b"] do
    throw (IO.userError "ARM local branch rejected")
  for lines in [["L_a:","\tb external"],["L_a:","\tbl L_a"],["L_a:","\tblr x16"],
      [".text","L_a:",".section other","L_b:","\tb L_a"],
      ["L_a:",".space 100"],List.replicate 230401 "\tnop"] do
    unless !leafBranchesLocal lines do throw (IO.userError "ARM unsafe branch/size mutation accepted")
  IO.println "ARM physical banks: call/TLS/scratch/local-branch/size mutation controls passed"
  let edge := "L_lcb_edge_1_f_start"
  let shape := fun branch yes no =>
    [branch ++ " " ++ edge, "\tb " ++ yes, edge ++ ":", "\tb " ++ no, yes ++ ":", "\tret"]
  let require := fun condition message => unless condition do throw (IO.userError message)
  for branch in ["\tb.eq", "\tb.ne", "\tb.lt", "\tb.lo", "\tcbz w19,"] do
    for no in ["no", "yes"] do
      require (compactEmptyBranches (shape branch "yes" no) ==
        [branch ++ " " ++ no, "yes:", "\tret"]) "empty ARM branch edge did not fold"
  let plain := shape "\tb.eq" "yes" "no"
  let withPhi := ["\tb.eq " ++ edge, "\tmov x19, x20", "\tb yes", edge ++ ":", "\tb no", "yes:"]
  require (compactEmptyBranches withPhi == withPhi) "ARM true phi edge was removed"
  let falsePhi := ["\tb.eq " ++ edge, "\tb yes", edge ++ ":", "\tmov x19, x20", "\tb no", "yes:"]
  require (compactEmptyBranches falsePhi == falsePhi) "ARM false phi edge was removed"
  let falseNext := ["\tb.eq " ++ edge, "\tb yes", edge ++ ":", "no:", "\tret", "yes:"]
  require (compactEmptyBranches falseNext == falseNext) "ARM false fallthrough changed"
  let bitBranch := shape "\ttbz w19, #1," "yes" "no"
  require (compactEmptyBranches bitBranch == bitBranch) "short-range bit branch was folded"
  let unknown := plain ++ [".space 1048576"]
  require (compactEmptyBranches unknown == unknown) "unknown byte-emitting directive bypassed range guard"
  let large := plain ++ List.replicate (225*1024) "\tnop"
  require (compactEmptyBranches large == large) "large ARM function bypassed range guard"
  let embedded := plain ++ [String.intercalate "\n" (List.replicate (225*1024) "\tnop")]
  require (compactEmptyBranches embedded == embedded) "embedded physical lines bypassed range guard"
  IO.println "ARM empty branch edges: condition/phi/fallthrough/identical-target and expanded-range guards passed"
  let mut cases := 0
  for width in #[Width.word,Width.long] do
    let expected := encodings width
    unless expected.size == (if width == .word then 1302 else 5334) do
      throw (IO.userError "logical-immediate enumeration has the wrong cardinality")
    let check := fun (value : Int) => do
      let normalized := (Semantics.constant width value).toNat
      unless logicalImmediate width value == expected.contains normalized do
        throw (IO.userError s!"logical-immediate classification differs for {width.spelling} {value}")
    for value in [:65536] do
      check value
      cases := cases+1
    for value in expected.toArray do
      check value
      check ((value : Int)-2^width.bits)
      check ((value ^^^ 1 : Nat) : Int)
      cases := cases+3
    let mut state : UInt64 := 20261021
    for _ in [:20000] do
      state := state*6364136223846793005+1442695040888963407
      check state.toNat
      cases := cases+1
  IO.println s!"ARM64 logical immediates: {cases} dense, complete-encoding, signed-pattern, neighbor and random checks against independent enumeration"

end LeanCompilerBackend.AArch64.Tests
