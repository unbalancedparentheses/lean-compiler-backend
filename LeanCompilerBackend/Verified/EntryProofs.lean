/- Entry preconditions for the actual executable model initializer. -/
import LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified.Machine

theorem argumentBits_read (v : Source.Value) :
    normalize v.width (argumentBits v) = v.toNat.toUInt64 := by
  cases v with
  | word bits =>
    change ((bits.toNat.toUInt64 ||| 0xfacefeed00000000).toUInt32).toUInt64 = bits.toNat.toUInt64
    rw [UInt64.toUInt32_or]
    simp
    apply UInt64.toNat_inj.mp
    simp
  | long bits => rfl

theorem initialRegisters_size (arguments : Array Source.Value) :
    (initialRegisters arguments).size = 31 := by
  simp [initialRegisters]

theorem initial_arg (arguments : Array Source.Value) (i : Nat)
    (v : Source.Value) (hi : i < 31) (hv : arguments[i]? = some v) :
    (initialRegisters arguments)[i]? = some (argumentBits v) := by
  simp [initialRegisters, hi, hv]

/-- Every compatible signature and argument vector has a concrete MIR entry
    state. Arbitrary aligned entry addresses are allowed within the model. -/
theorem initialState_entry (parameters : Array Width) (arguments : Array Source.Value)
    (frameBytes entrySP : Nat) (signature : parameters = arguments.map Source.Value.width)
    (arity : parameters.size ≤ 8) (aligned : entrySP % 16 = 0)
    (space : frameBytes ≤ entrySP) (nowrap : entrySP < 2^64)
    (frameBound : frameBytes ≤ 4080) (frameAligned : frameBytes % 16 = 0) :
    EntryState parameters arguments frameBytes false (initialState arguments frameBytes entrySP) := by
  have sizes : parameters.size = arguments.size := by simp [signature]
  simp only [EntryState, initialState, initialRegisters_size, Array.size_replicate,
    Bool.false_and, true_and]
  refine ⟨aligned, space, nowrap, frameBound, frameAligned, sizes, arity, ?_⟩
  intro i w v hw hv
  have width : v.width = w := by
    rw [signature] at hw
    simp [hv] at hw
    exact hw
  have index : i < arguments.size := Array.getElem?_eq_some_iff.mp hv |>.1
  refine ⟨width, ?_⟩
  simp only [readReg, initial_arg arguments i v (by omega) hv]
  rw [← width, argumentBits_read]
  rfl

/-- Valid preconditions make the executable initializer succeed, rather than
    only describing a state that might not be constructible. -/
theorem initial_complete (parameters : Array Width) (arguments : Array Source.Value)
    (frameBytes entrySP : Nat) (signature : parameters = arguments.map Source.Value.width)
    (arity : parameters.size ≤ 8) (aligned : entrySP % 16 = 0)
    (space : frameBytes ≤ entrySP) (nowrap : entrySP < 2^64)
    (frameBound : frameBytes ≤ 4080) (frameAligned : frameBytes % 16 = 0) :
    initial parameters arguments frameBytes entrySP = .ok (initialState arguments frameBytes entrySP) := by
  have sizes : parameters.size = arguments.size := by simp [signature]
  have argArity : arguments.size ≤ 8 := by omega
  simp [initial, aligned, frameAligned, Nat.not_lt.mpr argArity,
    Nat.not_lt.mpr space, Nat.not_le.mpr nowrap, Nat.not_lt.mpr frameBound, signature]
  rfl

/-- Every successful initializer result establishes the MIR entry contract. -/
theorem initial_sound (parameters : Array Width) (arguments : Array Source.Value)
    (frameBytes entrySP : Nat) (s : State)
    (success : initial parameters arguments frameBytes entrySP = .ok s) :
    EntryState parameters arguments frameBytes false s := by
  simp only [initial, bind, Except.bind, throw, pure, Except.pure] at success
  split at success
  · contradiction
  next counts =>
    split at success
    · contradiction
    next frame =>
      split at success
      · contradiction
      next widths =>
        have signature : parameters = arguments.map Source.Value.width := by simpa using widths
        have arity : parameters.size ≤ 8 := by simp_all
        have frameFacts : entrySP % 16 = 0 ∧ frameBytes ≤ entrySP ∧ entrySP < 2^64 ∧
            frameBytes % 16 = 0 ∧ frameBytes ≤ 4080 := by
          simpa [Bool.or_eq_true, not_or, and_assoc] using frame
        have same : initialState arguments frameBytes entrySP = s := by simpa using success
        rw [← same]
        exact initialState_entry parameters arguments frameBytes entrySP signature arity
          frameFacts.1 frameFacts.2.1 frameFacts.2.2.1 frameFacts.2.2.2.2 frameFacts.2.2.2.1

/-- The assembly adapter establishes its phase convention, including an empty
    frame, while preserving all arguments and the entry memory/register state. -/
theorem assemblyEntry_sound (parameters : Array Width) (arguments : Array Source.Value)
    (frameBytes : Nat) (s : State) (entry : EntryState parameters arguments frameBytes false s) :
    EntryState parameters arguments frameBytes true (assemblyEntry s) := by
  rcases entry with ⟨label, position, sp, aligned, space, nowrap, bound, frameAligned,
    frame, memory, registers, saved, active, sizes, arity, args⟩
  refine ⟨label, position, sp, aligned, space, nowrap, bound, frameAligned,
    frame, memory, registers, saved, ?_, sizes, arity, ?_⟩
  · simp [assemblyEntry, frame]
  · intro i w v hw hv
    obtain ⟨width, value⟩ := args i w v hw hv
    exact ⟨width, value⟩

end LeanCompilerBackend.Verified.Machine
