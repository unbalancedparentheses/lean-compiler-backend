/- Concrete witnesses for entry-precondition satisfiability. These are not
   source-to-target execution theorems. -/
import LeanCompilerBackend.Verified.EntryProofs

set_option maxRecDepth 10000

namespace LeanCompilerBackend.Verified.EntryExamples

open Source

def emptyFrame : Source.Function := {
  resultWidth := .word, parameters := #[], valueWidths := #[],
  blocks := #[{ phis := #[], instructions := #[], terminator := .ret (.literal (.word 7)) }] }

def loop : Source.Function := {
  resultWidth := .word, parameters := #[.word], valueWidths := Array.replicate 6 .word,
  blocks := #[
    { phis := #[], instructions := #[], terminator := .jump 1 },
    { phis := #[
        { destination := 1, width := .word, incoming := #[(0, .literal (.word 0)), (2, .local 4)] },
        { destination := 2, width := .word, incoming := #[(0, .literal (.word 0)), (2, .local 5)] }],
      instructions := #[{ destination := 3, width := .word, operation := .compare .unsignedLT .word (.local 1) (.local 0) }],
      terminator := .branch (.local 3) 2 3 },
    { phis := #[], instructions := #[
        { destination := 4, width := .word, operation := .binary .add (.local 1) (.literal (.word 1)) },
        { destination := 5, width := .word, operation := .binary .add (.local 2) (.local 1) }],
      terminator := .jump 1 },
    { phis := #[], instructions := #[], terminator := .ret (.local 2) }] }

def cyclicPhi : Source.Function := {
  resultWidth := .word, parameters := #[.word], valueWidths := Array.replicate 6 .word,
  blocks := #[
    { phis := #[], instructions := #[], terminator := .jump 1 },
    { phis := #[
        { destination := 1, width := .word, incoming := #[(0, .literal (.word 11)), (2, .local 2)] },
        { destination := 2, width := .word, incoming := #[(0, .literal (.word 22)), (2, .local 1)] },
        { destination := 3, width := .word, incoming := #[(0, .literal (.word 0)), (2, .local 5)] }],
      instructions := #[{ destination := 4, width := .word, operation := .compare .unsignedLT .word (.local 3) (.local 0) }],
      terminator := .branch (.local 4) 2 3 },
    { phis := #[], instructions := #[
        { destination := 5, width := .word, operation := .binary .add (.local 3) (.literal (.word 1)) }],
      terminator := .jump 1 },
    { phis := #[], instructions := #[], terminator := .ret (.local 1) }] }

def maximumFrame : Source.Function := {
  resultWidth := .word, parameters := #[], valueWidths := Array.replicate 255 .word,
  blocks := #[
    { phis := #[], instructions := #[], terminator := .jump 1 },
    { phis := (Array.range 255).map fun i => {
        destination := i, width := .word, incoming := #[(0, .literal (.word (BitVec.ofNat 32 i)))] },
      instructions := #[], terminator := .ret (.local 254) }] }

/-- The actual initializer supplies both entry contracts for this planned frame. -/
def Witness (f : Source.Function) (args : Array Source.Value) : Prop :=
  ∃ s, Machine.initial f.parameters args (planFrame f).frameBytes = .ok s ∧
    Machine.EntryState f.parameters args (planFrame f).frameBytes false s ∧
    Machine.EntryState f.parameters args (planFrame f).frameBytes true (Machine.assemblyEntry s)

theorem empty_entry : Witness emptyFrame #[] := by
  apply Machine.bounded_entry_exists <;> decide +kernel

theorem loop_entry : Witness loop #[.word 10] := by
  apply Machine.bounded_entry_exists <;> decide +kernel

theorem cyclic_entry : Witness cyclicPhi #[.word 5] := by
  apply Machine.bounded_entry_exists <;> decide +kernel

theorem maximum_entry : Witness maximumFrame #[] := by
  apply Machine.bounded_entry_exists <;> decide +kernel

theorem maximum_frame_bytes : (planFrame maximumFrame).frameBytes = 4080 := by decide +kernel

end LeanCompilerBackend.Verified.EntryExamples
