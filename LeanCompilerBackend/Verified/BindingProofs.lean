/- Acceptance/binding facts, not semantic-preservation certificates. -/
import LeanCompilerBackend.Verified.Job

namespace LeanCompilerBackend.Verified

/-- Exact acceptance of a cached artifact implies it is precisely the pure
    baseline's output for the requested job. This says nothing about whether
    that baseline preserves source semantics. -/
theorem verifyArtifact_binds (job : FunctionJob) (artifact : FunctionArtifact)
    (accepted : verifyArtifact job artifact = .ok ()) :
    compileFunction job = .ok artifact := by
  cases hc : compileFunction job with
  | error error => simp [verifyArtifact, hc, bind, Except.bind] at accepted
  | ok expected =>
    by_cases same : artifact = expected
    · simp [same]
    · simp [verifyArtifact, hc, same, bind, Except.bind, throw] at accepted

/-- Unavailable certification levels cannot produce a successful artifact. -/
theorem compile_refuses_unavailable (job : FunctionJob) (artifact : FunctionArtifact)
    (required : job.requested ≠ .none) :
    compileFunction job ≠ .ok artifact := by
  cases hv : validateJob job with
  | error error => simp [compileFunction, hv, bind, Except.bind]
  | ok result =>
    cases result
    simp [compileFunction, hv, required, bind, Except.bind, throw]

end LeanCompilerBackend.Verified
