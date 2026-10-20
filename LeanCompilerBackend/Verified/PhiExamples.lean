/- A fully admitted loop whose backedge instantiates the cyclic-transfer proof. -/
import LeanCompilerBackend.Verified.PhiSwapProof

set_option maxRecDepth 10000

namespace LeanCompilerBackend.Verified.PhiExamples

private def exceptDecidable [DecidableEq ε] [DecidableEq α] : (a b : Except ε α) → Decidable (a = b)
  | .error a, .error b => if h : a = b then .isTrue (congrArg Except.error h)
      else .isFalse (fun eq => h (Except.error.inj eq))
  | .ok a, .ok b => if h : a = b then .isTrue (congrArg Except.ok h)
      else .isFalse (fun eq => h (Except.ok.inj eq))
  | .error _, .ok _ => .isFalse (by intro eq; cases eq)
  | .ok _, .error _ => .isFalse (by intro eq; cases eq)

local instance [DecidableEq ε] [DecidableEq α] : DecidableEq (Except ε α) := exceptDecidable


/-- Initialization supplies 11/22; the self backedge exchanges the two values. -/
def cycleSource (w : Width) : Source.Function := {
  resultWidth := w, parameters := #[], valueWidths := #[w, w],
  blocks := #[
    { phis := #[], instructions := #[], terminator := .jump 1 },
    { phis := Machine.swapPhis w
        #[(0, .literal (Source.Value.constant w 11)), (1, .local 1)]
        #[(0, .literal (Source.Value.constant w 22)), (1, .local 0)],
      instructions := #[], terminator := .jump 1 }] }

def cycleMIR (w : Width) : StackMIR.Function :=
  match StackMIR.lower (cycleSource w) (planFrame (cycleSource w)) with
  | .ok f => f
  | .error _ => { parameters := #[], resultWidth := w, valueWidths := #[],
                  layout := { valueOffsets := #[], stageOffsets := #[], frameBytes := 0 }, blocks := #[] }

theorem cycle_admitted (w : Width) : validateSource (cycleSource w) = .ok () := by
  cases w <;> decide +kernel

theorem cycle_lowered (w : Width) :
    StackMIR.lower (cycleSource w) (planFrame (cycleSource w)) = .ok (cycleMIR w) := by
  cases w <;> decide +kernel

theorem cycle_legal (w : Width) : StackMIR.validate (cycleMIR w) = .ok () := by
  cases w <;> decide +kernel

theorem cycle_layout (w : Width) :
    StackMIR.offset (cycleMIR w) (.value 0) = .ok 0 ∧
    StackMIR.offset (cycleMIR w) (.value 1) = .ok 8 ∧
    StackMIR.offset (cycleMIR w) (.stage 0) = .ok 16 ∧
    StackMIR.offset (cycleMIR w) (.stage 1) = .ok 24 ∧
    (cycleMIR w).layout.frameBytes = 32 := by
  cases w <;> decide +kernel

theorem cycle_edge (w : Width) :
    (cycleMIR w).blocks.find? (·.label == .edge 1 1) = some {
      label := .edge 1 1, instructions := (Machine.swapCode w).toArray,
      terminator := .jump (.body 1) } := by
  cases w <;> decide +kernel

/-- A universally quantified execution result for the admitted fixture, not a
    computation on just its 11/22 sample values. -/
theorem cycle_transfer (w : Width) (d : Machine.Data) (a b : UInt64)
    (ready : Machine.FrameReady d) (frame : d.frameBytes = 32)
    (read0 : Machine.load d w 0 = .ok a) (read1 : Machine.load d w 8 = .ok b) :
    ∃ after, Machine.Steps (Machine.stepMIR (cycleMIR w)) 8
        { label := .edge 1 1, data := d } { label := .edge 1 1, position := 8, data := after } ∧
      Machine.load after w 0 = .ok (Machine.normalize w b) ∧
      Machine.load after w 8 = .ok (Machine.normalize w a) ∧ Machine.FrameReady after ∧
      ∀ reg, reg ≠ 9 → after.registers[reg]? = d.registers[reg]? := by
  obtain ⟨v0, v1, s0, s1, _⟩ := cycle_layout w
  exact Machine.phi_swap_steps (cycleMIR w) d w a b 1 1 ready (by omega)
    v0 v1 s0 s1 read0 read1 (cycle_edge w)

end LeanCompilerBackend.Verified.PhiExamples
