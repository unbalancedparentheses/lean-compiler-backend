/- Reification and validation of the numbered first-path syntax. This is an
   executable boundary, not a proved importer or proof-carrying CheckedSSA. -/
import LeanCompilerBackend.Verified.Admission

namespace LeanCompilerBackend.Verified

private def valueName (id : Nat) : String := s!"v{id}"
private def blockName (id : Nat) : String := s!"b{id}"

private def reifyOperand : Source.Operand → Operand
  | .local id => .temporary (valueName id)
  | .literal value => .constant value.toNat

private def reifyBinary : Source.Binary → Binary
  | .add => .add | .sub => .sub | .mul => .mul
  | .andBits => .andBits | .orBits => .orBits | .xorBits => .xorBits
  | .shiftLeft => .shiftLeft | .logicalRight => .logicalRight | .arithmeticRight => .arithmeticRight
  -- QBE has no high multiply. Reification keeps only its shape; see `shape`.
  | .mulHighUnsigned | .mulHighSigned => .mul

private def reifyOperation : Source.Operation → Operation
  | .copy value => .copy (reifyOperand value)
  | .binary op lhs rhs => .binary (reifyBinary op) (reifyOperand lhs) (reifyOperand rhs)
  | .compare op width lhs rhs =>
    .compare (match op with
      | .eq => .eq | .unsignedLT => .unsignedLT | .unsignedLE => .unsignedLE
      | .signedLT => .signedLT | .signedLE => .signedLE)
      width (reifyOperand lhs) (reifyOperand rhs)
  | .divide op lhs rhs =>
    .divide (match op with
      | .unsignedDiv => .unsignedDiv | .unsignedRem => .unsignedRem
      | .signedDiv => .signedDiv | .signedRem => .signedRem) (reifyOperand lhs) (reifyOperand rhs)

/-- Canonical local labels are function-local and independent of module order. -/
def reify (f : Source.Function) (name : String) (exported : Bool) : Function := {
  name, exported, resultWidth := some f.resultWidth
  parameters := f.parameters.mapIdx fun i width => { name := valueName i, width }
  blocks := f.blocks.mapIdx fun i block => {
    label := blockName i
    phis := block.phis.map fun phi => {
      destination := valueName phi.destination, width := phi.width
      incoming := phi.incoming.map fun (pred, value) => (blockName pred, reifyOperand value) }
    instructions := block.instructions.map fun inst => .assign {
      destination := valueName inst.destination, width := inst.width
      operation := reifyOperation inst.operation }
    terminator := match block.terminator with
      | .ret value => .ret (some (reifyOperand value))
      | .jump target => .jump (blockName target)
      | .branch value yes no => .branch (reifyOperand value) (blockName yes) (blockName no) }
}

private def isHighMultiply : Source.Operation → Bool
  | .binary .mulHighUnsigned _ _ | .binary .mulHighSigned _ _ => true
  | _ => false

/-- Replace each operation that has no QBE spelling by a QBE operation with the
    same operand/result widths and the same SSA uses. Admission's checks do not
    depend on which of those operations appears, so comparing the shapes keeps
    every structural check without inventing QBE syntax. -/
private def shape (f : Source.Function) : Source.Function :=
  { f with blocks := f.blocks.map fun block => { block with
      instructions := block.instructions.map fun inst => match inst.operation with
        | .binary .mulHighUnsigned lhs rhs | .binary .mulHighSigned lhs rhs =>
          { inst with operation := .binary .mul lhs rhs }
        | _ => inst } }

/-- Revalidate untrusted numbered input, including exact IDs, width table,
    literal widths, and canonical predecessor ordering. No proof is attached.
    Operations without a QBE spelling are reachable only through this API. -/
def validateSource (f : Source.Function) : Except AdmissionError Unit := do
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
  for block in f.blocks do
    for inst in block.instructions do
      if isHighMultiply inst.operation && inst.width != .long then
        throw (.unsupported "word-width high multiply; AArch64 UMULH/SMULH are 64-bit only")
  let canonical ← admit (reify f "canonical" false)
  if canonical != shape f then throw (.invalidInput "noncanonical numbered source or inconsistent widths")

end LeanCompilerBackend.Verified
