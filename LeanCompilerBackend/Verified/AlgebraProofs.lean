/- Kernel-checked local identities for the actual compatibility optimizer.
   These facts do not establish whole-pass or instruction execution preservation. -/
import LeanCompilerBackend.Optimize.Algebra

namespace LeanCompilerBackend.Verified.Algebra

/-- Copies retain result-width truncation even when the temporary stores a long. -/
theorem normalize_idempotent (width : Width) (value : UInt64) :
    Semantics.normalize width (Semantics.normalize width value) =
      Semantics.normalize width value := by
  cases width with
  | word => simp only [Semantics.normalize, UInt32.toUInt32_toUInt64]
  | long => rfl

/- Each theorem pairs an equation for the actual Algebra.operation implementation
   with its actual Semantics.binary value equation. The temporary must already
   resolve successfully to `value`; these are not claims about missing operands,
   statement execution, effects, or the complete optimization pipeline. -/

/-- Local add rewrite, including word truncation and all 64-bit input patterns. -/
theorem add_zero_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .add (.temporary name) (.constant 0)) =
        .copy (.temporary name) ∧
      Semantics.binary width .add (Semantics.normalize width value) 0 =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.add_zero, normalize_idempotent]

/-- Local add rewrite, including word truncation and all 64-bit input patterns. -/
theorem add_zero_left_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .add (.constant 0) (.temporary name)) =
        .copy (.temporary name) ∧
      Semantics.binary width .add 0 (Semantics.normalize width value) =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.zero_add, normalize_idempotent]

/-- Local sub rewrite, including word truncation and all 64-bit input patterns. -/
theorem sub_zero_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .sub (.temporary name) (.constant 0)) =
        .copy (.temporary name) ∧
      Semantics.binary width .sub (Semantics.normalize width value) 0 =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.sub_zero, normalize_idempotent]

/-- Local orBits rewrite, including word truncation and all 64-bit input patterns. -/
theorem orBits_zero_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .orBits (.temporary name) (.constant 0)) =
        .copy (.temporary name) ∧
      Semantics.binary width .orBits (Semantics.normalize width value) 0 =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.or_zero, normalize_idempotent]

/-- Local orBits rewrite, including word truncation and all 64-bit input patterns. -/
theorem orBits_zero_left_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .orBits (.constant 0) (.temporary name)) =
        .copy (.temporary name) ∧
      Semantics.binary width .orBits 0 (Semantics.normalize width value) =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.zero_or, normalize_idempotent]

/-- Local xorBits rewrite, including word truncation and all 64-bit input patterns. -/
theorem xorBits_zero_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .xorBits (.temporary name) (.constant 0)) =
        .copy (.temporary name) ∧
      Semantics.binary width .xorBits (Semantics.normalize width value) 0 =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.xor_zero, normalize_idempotent]

/-- Local xorBits rewrite, including word truncation and all 64-bit input patterns. -/
theorem xorBits_zero_left_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .xorBits (.constant 0) (.temporary name)) =
        .copy (.temporary name) ∧
      Semantics.binary width .xorBits 0 (Semantics.normalize width value) =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.zero_xor, normalize_idempotent]

/-- Local mul rewrite, including word truncation and all 64-bit input patterns. -/
theorem mul_one_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .mul (.temporary name) (.constant 1)) =
        .copy (.temporary name) ∧
      Semantics.binary width .mul (Semantics.normalize width value) 1 =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.mul_one, normalize_idempotent]

/-- Local mul rewrite, including word truncation and all 64-bit input patterns. -/
theorem mul_one_left_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .mul (.constant 1) (.temporary name)) =
        .copy (.temporary name) ∧
      Semantics.binary width .mul 1 (Semantics.normalize width value) =
        Semantics.normalize width value := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.one_mul, normalize_idempotent]

/-- Local mul rewrite, including word truncation and all 64-bit input patterns. -/
theorem mul_zero_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .mul (.temporary name) (.constant 0)) =
        .copy (.constant 0) ∧
      Semantics.binary width .mul (Semantics.normalize width value) 0 =
        0 := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.mul_zero]
    cases width <;> rfl

/-- Local mul rewrite, including word truncation and all 64-bit input patterns. -/
theorem mul_zero_left_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .mul (.constant 0) (.temporary name)) =
        .copy (.constant 0) ∧
      Semantics.binary width .mul 0 (Semantics.normalize width value) =
        0 := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.zero_mul]
    cases width <;> rfl

/-- Local andBits rewrite, including word truncation and all 64-bit input patterns. -/
theorem andBits_zero_right_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .andBits (.temporary name) (.constant 0)) =
        .copy (.constant 0) ∧
      Semantics.binary width .andBits (Semantics.normalize width value) 0 =
        0 := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.and_zero]
    cases width <;> rfl

/-- Local andBits rewrite, including word truncation and all 64-bit input patterns. -/
theorem andBits_zero_left_preserves (width : Width) (name : String) (value : UInt64) :
    Optimize.Algebra.operation width (.binary .andBits (.constant 0) (.temporary name)) =
        .copy (.constant 0) ∧
      Semantics.binary width .andBits 0 (Semantics.normalize width value) =
        0 := by
  constructor
  · cases width <;> rfl
  · simp only [Semantics.binary, UInt64.zero_and]
    cases width <;> rfl

end LeanCompilerBackend.Verified.Algebra
