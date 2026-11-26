/-
  Frozen, pure per-function compilation boundary (F02).
  Exact structural values are identities until the versioned F03 wire format.
  The current result is explicitly uncertified; no theorem name is a certificate.
-/
import LeanCompilerBackend.Verified.Plans
import LeanCompilerBackend.Verified.BuildIdentity
import LeanCompilerBackend.Verified.TypedA64

namespace LeanCompilerBackend.Verified

structure CodeInput where
  version : Nat := 1
  sourceSemantics : String := "ssa-int-v2"
  targetSemantics : String := "a64-leaf-v2"
  target : String := "aarch64-apple-darwin-leaf-int-v1"
  pipeline : String := "stack-baseline-v1"
  /-- An explicit development implementation revision, not a content hash. -/
  compilerRevision : String := "lcb-foundations-dev1"
  /-- Content identity of compiler sources and pinned build configuration. -/
  compilerBuild : String := compilerBuildIdentity
  symbol : Symbol
  body : Source.Function
  abi : AbiPlan
  layout : FrameLayout
  imports : Array String := #[]
  consumedFacts : Array String := #[]
  deriving DecidableEq, Repr

inductive EvidenceRequest where
  | none | kernelTypedAssembly | nativeBinary
  deriving DecidableEq, Repr

structure ProofProfile where
  libraryIdentity : String := "unavailable"
  leanVersion : String := "4.34.1"
  allowedAxioms : Array String := #["propext", "Quot.sound"]
  deriving DecidableEq, Repr

structure DebugOrigin where
  block : Nat
  /-- 0 = phi, 1 = body instruction, 2 = terminator. -/
  kind : Nat
  index : Nat
  source : Nat
  line : Nat
  column : Nat
  deriving DecidableEq, Repr

structure DebugSource where
  id : Nat
  logicalPath : String
  contentIdentity : String
  deriving DecidableEq, Repr

structure DebugInput where
  sources : Array DebugSource := #[]
  origins : Array DebugOrigin := #[]
  deriving DecidableEq, Repr

structure FunctionJob where
  code : CodeInput
  debug : DebugInput := {}
  requested : EvidenceRequest := .none
  proof : ProofProfile := {}
  deriving DecidableEq, Repr

inductive CompileError where
  | admission (error : AdmissionError)
  | invalidJob (reason : String)
  | unsupported (feature : String)
  | unsupportedTarget (target : String)
  | certificationUnavailable (request : EvidenceRequest)
  | verificationFailed (stage reason : String)
  deriving DecidableEq, Repr

def CompileError.message : CompileError → String
  | .admission error => error.message
  | .invalidJob reason => s!"invalid job: {reason}"
  | .unsupported feature => s!"unsupported: {feature}"
  | .unsupportedTarget target => s!"unsupported target: {target}"
  | .certificationUnavailable request =>
    let profile := match request with
      | .none => "none" | .kernelTypedAssembly => "kernelTypedAssembly" | .nativeBinary => "nativeBinary"
    s!"certificationUnavailable: {profile}"
  | .verificationFailed stage reason => s!"{stage}: {reason}"

/-- No constructor for a certificate exists before the relevant proof exists. -/
inductive VerificationResult where
  | uncertified (structuralChecks : Array String)
  deriving DecidableEq, Repr

structure CodeArtifact where
  input : CodeInput
  stackMIR : StackMIR.Function
  assembly : TypedA64.Function
  fragment : String
  deriving DecidableEq, Repr

structure DebugArtifact where
  /-- Exact binding, never digest-only equality. -/
  code : CodeArtifact
  input : DebugInput
  deriving DecidableEq, Repr

structure FunctionArtifact where
  version : Nat := 1
  code : CodeArtifact
  debug : DebugArtifact
  proofProfile : ProofProfile
  verification : VerificationResult
  deriving DecidableEq, Repr

private def validSymbol (name : String) : Bool :=
  !name.isEmpty && name.toList.all (fun c => c.toNat < 128 && (c.isAlphanum || c == '_'))
    && (name.toList.head!.isAlpha || name.toList.head! == '_')

private def validPath (path : String) : Bool :=
  let chars := path.toList
  !chars.contains '\\' && !chars.contains ':' && !chars.contains '\x00' &&
    (List.splitOnPTR (· == '/') chars).all (fun part =>
      !part.isEmpty && part != ['.'] && part != ['.', '.'])

private def originKey (o : DebugOrigin) : Nat × Nat × Nat := (o.block, o.kind, o.index)

private def validateDebug (f : Source.Function) (debug : DebugInput) : Except CompileError Unit := do
  if debug.sources.size > 1024 || debug.origins.size > 1024 then
    throw (.invalidJob "debug record limit exceeded")
  let mut lastSource : Option Nat := none
  for source in debug.sources do
    if !validPath source.logicalPath || source.contentIdentity.isEmpty then
      throw (.invalidJob "invalid debug logical path or content identity")
    if let some last := lastSource then
      if source.id <= last then throw (.invalidJob "debug sources must have sorted unique IDs")
    lastSource := some source.id
  let mut lastOrigin : Option (Nat × Nat × Nat) := none
  for origin in debug.origins do
    let some block := f.blocks[origin.block]? | throw (.invalidJob "debug origin block does not exist")
    let valid := match origin.kind with
      | 0 => origin.index < block.phis.size
      | 1 => origin.index < block.instructions.size
      | 2 => origin.index == 0
      | _ => false
    if !valid || origin.line == 0 || origin.column == 0 ||
        !debug.sources.any (·.id == origin.source) then
      throw (.invalidJob "invalid debug origin or source binding")
    if let some last := lastOrigin then
      let key := originKey origin
      let ordered := last.1 < key.1 || (last.1 == key.1 &&
        (last.2.1 < key.2.1 || (last.2.1 == key.2.1 && last.2.2 < key.2.2)))
      if !ordered then throw (.invalidJob "debug origins must be sorted and unique")
    lastOrigin := some (originKey origin)

/-- Checking input is independent of module state and does not grant evidence. -/
def validateJobWithWork (job : FunctionJob) : Except CompileError Nat := do
  let c := job.code
  if c.target != "aarch64-apple-darwin-leaf-int-v1" then throw (.unsupportedTarget c.target)
  if c.version != 1 || c.sourceSemantics != "ssa-int-v2" || c.targetSemantics != "a64-leaf-v2" ||
      c.pipeline != "stack-baseline-v1" ||
      c.compilerRevision != "lcb-foundations-dev1" || c.compilerBuild != compilerBuildIdentity then
    throw (.unsupported "job version, semantics or compiler revision")
  if !validSymbol c.symbol.name || c.symbol.namespaceName.isEmpty then
    throw (.invalidJob "invalid symbol identity")
  if !c.imports.isEmpty || !c.consumedFacts.isEmpty then
    throw (.unsupported "imports or optimization facts in a leaf job")
  let work ← (validateSourceWithWork c.body).mapError CompileError.admission
  if c.abi != planAbi c.body then throw (.invalidJob "ABI plan does not match source signature/profile")
  if c.layout != planFrame c.body then throw (.invalidJob "frame plan does not match source definitions")
  validateDebug c.body job.debug
  return work

def validateJob (job : FunctionJob) : Except CompileError Unit :=
  (validateJobWithWork job).map (fun _ => ())

theorem validateJobWithWork_result (job : FunctionJob) :
    (validateJobWithWork job).map (fun _ => ()) = validateJob job := rfl

/-- The driver freezes all inputs. Workers receive this record, never a module. -/
def prepareJob (f : Function) (namespaceName : String) (requested := EvidenceRequest.none)
    (debug : DebugInput := {}) (proof : ProofProfile := {}) : Except CompileError FunctionJob := do
  let body ← match admit f with
    | .ok body => pure body
    | .error e => throw (.admission e)
  let job := {
    code := { symbol := { namespaceName, name := f.name, exported := f.exported },
              body, abi := planAbi body, layout := planFrame body }
    debug, requested, proof : FunctionJob }
  validateJob job
  pure job

private def assemblyError (stage : String) : TypedA64.Error → CompileError
  | .invalid reason => .verificationFailed stage reason
  | .unsupportedHighMultiplyWidth op width => .admission (.unsupportedHighMultiplyWidth op width)

private def loweringError : StackMIR.LoweringError → CompileError
  | .admission e => .admission e
  | .invalid reason => .verificationFailed "stack-lowering" reason

/-- Pure compilation through checked structural boundaries. Successful output
    is still uncertified: these executable checks are not preservation proofs. -/
def compileFunctionWithWork (job : FunctionJob) : Except CompileError (FunctionArtifact × Nat) := do
  let work ← validateJobWithWork job
  if job.requested != .none then throw (.certificationUnavailable job.requested)
  let stackMIR ← (StackMIR.lower job.code.body job.code.layout).mapError loweringError
  (StackMIR.validate stackMIR).mapError (CompileError.verificationFailed "stack-legality")
  let assembly ← (TypedA64.select stackMIR).mapError (assemblyError "selection")
  (TypedA64.validate assembly).mapError (assemblyError "assembly-legality")
  let (fragment, lines) ← (TypedA64.renderWithWork assembly job.code.symbol).mapError
    (assemblyError "rendering")
  let code := { input := job.code, stackMIR, assembly, fragment : CodeArtifact }
  pure ({
    code, debug := { code, input := job.debug }, proofProfile := job.proof
    verification := .uncertified #["source-profile", "abi-plan", "frame-plan", "stack-legality", "assembly-legality"]
  }, work + lines)

def compileFunction (job : FunctionJob) : Except CompileError FunctionArtifact :=
  (compileFunctionWithWork job).map Prod.fst

/-- The assembly and text stored in a successful job are precisely the
    results of whole-function selection and checked rendering. -/
theorem compileFunction_emission (job : FunctionJob) (artifact : FunctionArtifact)
    (compiled : compileFunction job = .ok artifact) :
    TypedA64.select artifact.code.stackMIR = .ok artifact.code.assembly ∧
    TypedA64.render artifact.code.assembly job.code.symbol = .ok artifact.code.fragment := by
  unfold compileFunction compileFunctionWithWork at compiled
  cases valid : validateJobWithWork job <;> simp only [valid] at compiled
  · contradiction
  by_cases requested : job.requested = .none
  · simp only [requested, bne_self_eq_false, Bool.false_eq_true, ↓reduceIte,
      Bind.bind, Except.bind] at compiled
    cases lowered : (StackMIR.lower job.code.body job.code.layout).mapError loweringError <;>
      simp only [lowered] at compiled
    · contradiction
    rename_i work mir
    cases legal : (StackMIR.validate mir).mapError
        (CompileError.verificationFailed "stack-legality") <;> simp only [legal] at compiled
    · contradiction
    cases selected : TypedA64.select mir with
    | error e => simp [selected, Except.mapError, Except.map] at compiled
    | ok assembly =>
      simp only [selected, Except.mapError] at compiled
      cases legalAssembly : TypedA64.validate assembly <;> simp only [legalAssembly] at compiled
      · contradiction
      cases rendered : TypedA64.renderWithWork assembly job.code.symbol with
      | error e => simp [rendered, Except.map] at compiled
      | ok output =>
        obtain ⟨fragment, lines⟩ := output
        simp [rendered, Except.map, Pure.pure, Except.pure] at compiled
        subst artifact
        exact ⟨selected, by simp [TypedA64.render, rendered, Except.map]⟩
  · simp [requested, Bind.bind, Except.bind, Except.map, throw] at compiled

theorem compileFunctionWithWork_result (job : FunctionJob) :
    (compileFunctionWithWork job).map Prod.fst = compileFunction job := rfl

/-- Acceptance recomputes the pure baseline and compares the exact complete
    artifact. This binds input/output but is not a semantic-preservation checker. -/
def verifyArtifact (job : FunctionJob) (artifact : FunctionArtifact) : Except CompileError Unit := do
  let expected ← compileFunction job
  if artifact != expected then throw (.verificationFailed "artifact-binding" "artifact does not match job and baseline")

/-- Planning catches linker-name collisions, even across distinct namespaces. -/
def prepareModule (functions : Program) (namespaceName : String)
    (requested := EvidenceRequest.none) : Except CompileError (Array FunctionJob) := do
  let mut jobs := #[]
  for f in functions do
    if jobs.any (fun j : FunctionJob => j.code.symbol.name == f.name) then
      throw (.invalidJob s!"duplicate emitted symbol _{f.name}")
    jobs := jobs.push (← prepareJob f namespaceName requested)
  pure jobs

end LeanCompilerBackend.Verified
