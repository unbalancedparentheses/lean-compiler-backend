/- Unbounded divergence from finite, nonempty cycles in actual machine steps. -/
import LeanCompilerBackend.Verified.MachineProofs

namespace LeanCompilerBackend.Verified.Machine

theorem steps_append (step : State → Except String Transition)
    (first : Steps step n s t) (second : Steps step m t u) : Steps step (n + m) s u := by
  induction first with
  | zero => simpa using second
  | succ head tail ih =>
    simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using (Steps.succ head (ih second))

theorem steps_take (step : State → Except String Transition)
    (whole : Steps step m s u) (bound : n ≤ m) : ∃ t, Steps step n s t := by
  induction whole generalizing n with
  | zero => have : n = 0 := by omega
            subst n
            exact ⟨_, .zero _⟩
  | succ head tail ih =>
    cases n with
    | zero => exact ⟨_, .zero _⟩
    | succ n =>
      obtain ⟨t, initialSteps⟩ := ih (n := n) (by omega)
      exact ⟨t, .succ head initialSteps⟩

/-- A closed positive-length execution supplies arbitrarily long prefixes. -/
theorem cycle_diverges (step : State → Except String Transition)
    (cycle : Steps step k s s) (positive : 0 < k) : Diverges step s := by
  have repeated : ∀ n, Steps step (n * k) s s := by
    intro n
    induction n with
    | zero => simpa using (Steps.zero (step := step) s)
    | succ n ih => simpa [Nat.succ_mul] using steps_append step ih cycle
  intro n
  exact steps_take step (repeated n) (by simpa using Nat.mul_le_mul_left n positive)

/-- A finite entry path into a divergent execution is itself divergent. -/
theorem prefix_diverges (step : State → Except String Transition)
    (initialSteps : Steps step k s t) (diverges : Diverges step t) : Diverges step s := by
  intro n
  obtain ⟨u, suffix⟩ := diverges n
  exact steps_take step (steps_append step initialSteps suffix) (by omega)

end LeanCompilerBackend.Verified.Machine
