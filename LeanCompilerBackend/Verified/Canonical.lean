/- Reification and validation of the numbered first-path syntax. This is an
   executable boundary, not a proved importer or proof-carrying CheckedSSA. -/
import LeanCompilerBackend.Verified.Admission

namespace LeanCompilerBackend.Verified

private def valueName (id : Nat) : String := s!"v{id}"
private def blockName (id : Nat) : String := s!"b{id}"

private def reifyOperand : Source.Operand → Operand
  | .local id => .temporary (valueName id)
  | .literal value => .constant value.toNat

inductive ReifyError where
  | unsupportedBinary (op : Source.Binary)
  deriving DecidableEq, Repr

private def reifyBinary (op : Source.Binary) : Except ReifyError Binary :=
  match op with
  | .add => pure .add | .sub => pure .sub | .mul => pure .mul
  | .andBits => pure .andBits | .orBits => pure .orBits | .xorBits => pure .xorBits
  | .shiftLeft => pure .shiftLeft
  | .logicalRight => pure .logicalRight
  | .arithmeticRight => pure .arithmeticRight
  | .mulHighUnsigned => throw (.unsupportedBinary .mulHighUnsigned)
  | .mulHighSigned => throw (.unsupportedBinary .mulHighSigned)

private def reifyOperation : Source.Operation → Except ReifyError Operation
  | .copy value => pure (.copy (reifyOperand value))
  | .binary op lhs rhs => do
    pure (.binary (← reifyBinary op) (reifyOperand lhs) (reifyOperand rhs))
  | .compare op width lhs rhs =>
    pure (.compare (match op with
      | .eq => .eq | .unsignedLT => .unsignedLT | .unsignedLE => .unsignedLE
      | .signedLT => .signedLT | .signedLE => .signedLE)
      width (reifyOperand lhs) (reifyOperand rhs))
  | .divide op lhs rhs =>
    pure (.divide (match op with
      | .unsignedDiv => .unsignedDiv | .unsignedRem => .unsignedRem
      | .signedDiv => .signedDiv | .signedRem => .signedRem) (reifyOperand lhs) (reifyOperand rhs))

/-- Canonical local labels are function-local and independent of module order. -/
def reify (f : Source.Function) (name : String) (exported : Bool) :
    Except ReifyError Function := do
  let blocks ← f.blocks.mapIdxM fun i block => do
    let instructions ← block.instructions.mapM fun inst => do
      let operation ← reifyOperation inst.operation
      pure (.assign { destination := valueName inst.destination, width := inst.width, operation })
    pure {
      label := blockName i
      phis := block.phis.map fun phi => {
        destination := valueName phi.destination, width := phi.width
        incoming := phi.incoming.map fun (pred, value) => (blockName pred, reifyOperand value) }
      instructions
      terminator := match block.terminator with
        | .ret value => .ret (some (reifyOperand value))
        | .jump target => .jump (blockName target)
        | .branch value yes no => .branch (reifyOperand value) (blockName yes) (blockName no) }
  pure {
    name, exported, resultWidth := some f.resultWidth, blocks
    parameters := f.parameters.mapIdx fun i width => { name := valueName i, width } }

/-- Admission-only projection. AND has the same operand/result widths and SSA
    uses as high multiply. The projection is consumed by admission and structural
    comparison; the job retains the original source for lowering. -/
private def shape (f : Source.Function) : Except AdmissionError Source.Function := do
  let blocks ← f.blocks.mapM fun block => do
    let instructions ← block.instructions.mapM fun inst =>
      match inst.operation with
      | .binary op lhs rhs =>
        if op.isHighMultiply then
          if inst.width == .long then pure { inst with operation := .binary .andBits lhs rhs }
          else throw (.unsupportedHighMultiplyWidth op inst.width)
        else pure inst
      | .copy .. | .compare .. | .divide .. => pure inst
    pure { block with instructions }
  pure { f with blocks }

/-- Revalidate untrusted numbered input, including exact IDs, width table,
    literal widths, and canonical predecessor ordering. No proof is attached.
    Operations without a QBE spelling are reachable only through this API. -/
def validateSourceWithWork (f : Source.Function) : Except AdmissionError Nat := do
  if f.parameters.size > 8 then throw (.resourceLimit "parameters" f.parameters.size 8)
  if f.blocks.size > 64 then throw (.resourceLimit "blocks" f.blocks.size 64)
  if f.valueWidths.size > 488 then throw (.resourceLimit "values" f.valueWidths.size 488)
  let definitions := f.blocks.foldl (fun n b => n + b.phis.size + b.instructions.size) 0
  if definitions > 480 then throw (.resourceLimit "definitions" definitions 480)
  -- Limit incoming lists before reifying, even for hostile direct API values.
  for block in f.blocks do
    for phi in block.phis do
      if phi.incoming.size > 64 then
        throw (.resourceLimit "phi predecessors" phi.incoming.size 64)
  let projected ← shape f
  let named ← (reify projected "canonical" false).mapError fun e =>
    .unsupported s!"canonical admission projection: {repr e}"
  let (canonical, work) ← admitWithWork named
  if canonical != projected then throw (.invalidInput "noncanonical numbered source or inconsistent widths")

  return work

def validateSource (f : Source.Function) : Except AdmissionError Unit :=
  (validateSourceWithWork f).map (fun _ => ())

end LeanCompilerBackend.Verified
