/- Small kernel-checked facts about the actual executable target helpers.
   These do not yet compose into source-to-target preservation. -/
import LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified.Machine

theorem normalize_idempotent (width : Width) (value : UInt64) :
    normalize width (normalize width value) = normalize width value := by
  cases width with
  | word => simp only [normalize, UInt32.toUInt32_toUInt64]
  | long => rfl

/-- A same-register read sees the written width-normalized value. -/
theorem read_write_same (d : Data) (width : Width) (reg : Nat) (value : UInt64)
    (hr : reg < 31) (hs : reg < d.registers.size) :
    (writeReg d width reg value >>= fun updated => readReg updated width reg) =
      .ok (normalize width value) := by
  simp [writeReg, readReg, Nat.not_le.mpr hr, Nat.not_le.mpr hs,
    Array.getElem?_setIfInBounds_self_of_lt hs, normalize_idempotent]
  rfl

/-- W-register writes zero-extend into the aliased X register. -/
theorem word_write_long_read (d : Data) (reg : Nat) (value : UInt64)
    (hr : reg < 31) (hs : reg < d.registers.size) :
    (writeReg d .word reg value >>= fun updated => readReg updated .long reg) =
      .ok value.toUInt32.toUInt64 := by
  simp [writeReg, readReg, Nat.not_le.mpr hr, Nat.not_le.mpr hs,
    Array.getElem?_setIfInBounds_self_of_lt hs, normalize]
  rfl

/-- Registers other than the written physical register keep both width views. -/
theorem write_preserves_other (d : Data) (writeWidth readWidth : Width)
    (reg other : Nat) (value : UInt64) (hr : reg < 31) (hs : reg < d.registers.size)
    (hne : reg ≠ other) :
    (writeReg d writeWidth reg value >>= fun updated => readReg updated readWidth other) =
      readReg d readWidth other := by
  simp [writeReg, readReg, Nat.not_le.mpr hr, Nat.not_le.mpr hs,
    Array.getElem?_setIfInBounds_ne hne]

/-- Entering and leaving the fixed frame restores every component of the
    machine data, provided the frame is available and no body step intervenes. -/
theorem enter_leave (d : Data) (hsp : d.sp = d.entrySP)
    (hspace : d.frameBytes ≤ d.entrySP) (hinactive : d.active = false) :
    (enter d d.frameBytes >>= fun inside => leave inside d.frameBytes) = .ok d := by
  simp [enter, leave, hsp, hinactive, Nat.not_lt.mpr hspace, Nat.sub_add_cancel hspace]
  cases d
  simp_all
  rfl

private theorem word_embed_injective (a b : UInt32) :
    a.toUInt64 = b.toUInt64 ↔ a = b := by
  constructor
  · intro h
    have h := congrArg UInt64.toUInt32 h
    simpa only [UInt32.toUInt32_toUInt64] using h
  · intro h
    exact congrArg UInt32.toUInt64 h

/-- Target subtraction's Z flag implements equality at the selected width. -/
theorem subtract_zero_iff_equal (width : Width) (a b : UInt64) :
    (subtractFlags width a b).zero = (normalize width a == normalize width b) := by
  change (normalize width (normalize width a - normalize width b) == 0) = _
  apply Bool.eq_iff_iff.mpr
  simp only [beq_iff_eq]
  cases width with
  | word =>
    simp only [normalize, UInt64.toUInt32_sub, UInt32.toUInt32_toUInt64]
    change ((a.toUInt32 - b.toUInt32).toUInt64 = (0 : UInt32).toUInt64) ↔ _
    rw [word_embed_injective, word_embed_injective, UInt32.sub_eq_iff_eq_add]
    simp
  | long =>
    simp only [normalize, UInt64.sub_eq_iff_eq_add, UInt64.zero_add]

/-- Target subtraction's carry convention implements unsigned less-than. -/
theorem subtract_borrow_iff_less (width : Width) (a b : UInt64) :
    (!(subtractFlags width a b).carry) = decide (normalize width a < normalize width b) := by
  change (!decide (normalize width b ≤ normalize width a)) = decide (normalize width a < normalize width b)
  simp [UInt64.le_iff_toNat_le, UInt64.lt_iff_toNat_lt, ← decide_not]

/-- Relate physical register bits to the typed source value at a boundary. -/
def sourceView (w : Width) (x : UInt64) : Source.Value :=
  match w with
  | .word => .word x.toUInt32.toBitVec
  | .long => .long x.toBitVec

theorem alu_preserves (w : Width) (op : Source.Binary) (a b : UInt64) :
  Source.evaluateBinary op (sourceView w a) (sourceView w b) =
    .ok (sourceView w (alu w op a b)) := by
  cases w <;> cases op <;> simp only [sourceView, Source.evaluateBinary, Source.binaryBits, alu, normalize,
    UInt32.toUInt32_toUInt64, UInt64.toUInt32_add, UInt64.toUInt32_sub,
    UInt64.toUInt32_mul, UInt64.toUInt32_and, UInt64.toUInt32_or, UInt64.toUInt32_xor,
    UInt32.toBitVec_add, UInt32.toBitVec_sub, UInt32.toBitVec_mul,
    UInt32.toBitVec_and, UInt32.toBitVec_or, UInt32.toBitVec_xor,
    UInt64.toBitVec_add, UInt64.toBitVec_sub, UInt64.toBitVec_mul,
    UInt64.toBitVec_and, UInt64.toBitVec_or, UInt64.toBitVec_xor]

/-- Successful bounded target execution witnesses an unbounded target return. -/
theorem run_return_sound (step : State → Except String Transition) (fuel : Nat)
    (s : State) (v : Source.Value) (d : Data)
    (h : run step fuel s = .returned v d) : Returns step s v d := by
  induction fuel generalizing s with
  | zero => simp [run] at h
  | succ fuel ih =>
    cases hs : step s with
    | error fault => simp [run, hs] at h
    | ok transition =>
      cases transition with
      | returned value data =>
        have hv : value = v ∧ data = d := by simpa [run, hs] using h
        obtain ⟨rfl, rfl⟩ := hv
        exact ⟨0, s, .zero s, hs⟩
      | next t =>
        have ht : run step fuel t = .returned v d := by simpa [run, hs] using h
        obtain ⟨n, u, steps, result⟩ := ih t ht
        exact ⟨n+1, u, .succ hs steps, result⟩

/-- Exhaustion gives only a finite execution prefix, never a divergence proof. -/
theorem run_exhausted_prefix (step : State → Except String Transition) (fuel : Nat)
    (s t : State) (h : run step fuel s = .exhausted t) : Steps step fuel s t := by
  induction fuel generalizing s with
  | zero =>
    have same : s = t := by simpa [run] using h
    subst s
    exact .zero t
  | succ fuel ih =>
    cases hs : step s with
    | error fault => simp [run, hs] at h
    | ok transition =>
      cases transition with
      | returned value data => simp [run, hs] at h
      | next next =>
        have ht : run step fuel next = .exhausted t := by simpa [run, hs] using h
        exact .succ hs (ih next ht)

end LeanCompilerBackend.Verified.Machine
