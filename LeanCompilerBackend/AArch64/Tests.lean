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
