import LeanCompilerBackend.AArch64

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
