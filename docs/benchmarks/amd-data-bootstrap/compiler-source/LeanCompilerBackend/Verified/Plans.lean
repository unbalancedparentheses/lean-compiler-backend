/- Explicit symbol, ABI and frame plans for the first-path stack baseline. -/
import LeanCompilerBackend.Verified.Canonical

namespace LeanCompilerBackend.Verified

structure Symbol where
  namespaceName : String
  name : String
  exported : Bool
  deriving DecidableEq, Repr

structure AbiPlan where
  version : Nat := 1
  profile : String := "apple-arm64-leaf-integer-v1"
  parameters : Array (Width × Nat)
  result : Width × Nat
  stackAlignment : Nat := 16
  incomingStackBytes : Nat := 0
  outgoingStackBytes : Nat := 0
  /-- Physical X-register indices; W aliases the same register. -/
  clobbered : Array Nat := #[0, 9, 10]
  preserved : Array Nat := #[18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
  wordInputHighBitsUnconstrained : Bool := true
  wordResultHighBitsZero : Bool := true
  writesFlags : Bool := true
  restoresSP : Bool := true
  deriving DecidableEq, Repr

def planAbi (f : Source.Function) : AbiPlan := {
  parameters := f.parameters.mapIdx fun i width => (width, i)
  result := (f.resultWidth, 0) }

structure FrameLayout where
  version : Nat := 1
  valueOffsets : Array Nat
  stageOffsets : Array Nat
  frameBytes : Nat
  deriving DecidableEq, Repr

def planFrame (f : Source.Function) : FrameLayout := Id.run do
  let n := f.valueWidths.size
  let p := f.blocks.foldl (fun count block => max count block.phis.size) 0
  return {
    valueOffsets := (Array.range n).map (8 * ·)
    stageOffsets := (Array.range p).map (fun i => 8 * (n + i))
    frameBytes := ((8 * (n + p) + 15) / 16) * 16 }

end LeanCompilerBackend.Verified
