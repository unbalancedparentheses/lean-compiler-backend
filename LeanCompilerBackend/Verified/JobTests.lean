import LeanCompilerBackend.Parser
import LeanCompilerBackend.Verified.Job
import LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified.JobTests

private def require (b : Bool) (message : String) : IO Unit :=
  unless b do throw (IO.userError message)

private def success [Repr ε] (result : Except ε α) : IO α :=
  match result with | .ok value => pure value | .error e => throw (IO.userError s!"unexpected failure: {repr e}")

private def failed : Except ε α → Bool
  | .ok _ => false | .error _ => true

private def jobFor (text : String) : IO FunctionJob := do
  let program ← success (Parser.parse text)
  let some f := program[0]? | throw (IO.userError "empty test source")
  success (prepareJob f "job-tests")

private def baseText := "export function w $add(w %a, w %b) { @entry %r =w add %a, %b ret %r }"

private def boundary : IO Unit := do
  let job ← jobFor baseText
  let artifact ← success (compileFunction job)
  let _ ← success (verifyArtifact job artifact)
  let renamed ← jobFor "export function w $add(w %left, w %right) { @start %answer =w add %left, %right ret %answer }"
  require (decide (job = renamed)) "renaming changed frozen job"
  require (decide ((← success (compileFunction renamed)) = artifact)) "renaming changed artifact"
  let debug : DebugInput := {
    sources := #[{ id := 0, logicalPath := "src/test.qbe", contentIdentity := "source-v1" }]
    origins := #[{ block := 0, kind := 1, index := 0, source := 0, line := 20, column := 3 }] }
  let debugJob := { job with debug }
  let debugArtifact ← success (compileFunction debugJob)
  require (decide (artifact.code = debugArtifact.code)) "debug edit changed code"
  require (decide (artifact.debug ≠ debugArtifact.debug)) "debug edit did not change metadata"
  require (failed (verifyArtifact job debugArtifact)) "debug artifact rebound to wrong job"
  let proofJob := { job with proof.libraryIdentity := "another-proof-library" }
  let proofArtifact ← success (compileFunction proofJob)
  require (decide (artifact.code = proofArtifact.code)) "evidence-only edit changed code"
  require (failed (verifyArtifact job proofArtifact)) "evidence profile substitution accepted"
  for request in [EvidenceRequest.kernelTypedAssembly, .nativeBinary] do
    require (match compileFunction { job with requested := request } with
      | .error (.certificationUnavailable r) => r == request | _ => false)
      "certification request silently downgraded"
    require (failed (verifyArtifact { job with requested := request } artifact))
      "uncertified artifact accepted for proof request"
  for bad in [
      { job with code.version := 2 },
      { job with code.target := "aarch64-linux" },
      { job with code.compilerRevision := "unbound-build" },
      { job with code.compilerBuild := "wrong-source-build" },
      { job with code.imports := #["hidden-callee"] },
      { job with code.consumedFacts := #["assume-no-overflow"] },
      { job with code.symbol.name := "bad\n.globl injected" },
      { job with code.abi.stackAlignment := 8 },
      { job with code.abi.clobbered := #[0, 19] },
      { job with code.abi.parameters := #[(.word, 1), (.word, 0)] },
      { job with code.layout.frameBytes := 48 },
      { job with code.layout.valueOffsets := #[0, 0, 16] },
      { job with code.body.valueWidths := #[.word, .long, .word] },
      { job with debug.sources := #[{ id := 0, logicalPath := "/host/file", contentIdentity := "x" }] },
      { job with debug.sources := #[{ id := 0, logicalPath := "../file", contentIdentity := "x" }] },
      { debugJob with debug.origins := #[{ block := 10, kind := 1, index := 0, source := 0, line := 1, column := 1 }] }] do
    require (failed (compileFunction bad)) "invalid frozen job accepted"
  for corrupt in [
      { artifact with version := 2 },
      { artifact with code.fragment := artifact.code.fragment ++ "\tbrk #0\n" },
      { artifact with debug.code.fragment := "unbound-debug" },
      { artifact with verification := .uncertified #[] }] do
    require (failed (verifyArtifact job corrupt)) "corrupt artifact accepted"
  let program ← success (Parser.parse (baseText ++ " function w $other() { @s ret 99 }"))
  let jobs ← success (prepareModule program "job-tests")
  let reversed ← success (prepareModule program.reverse "job-tests")
  let some first := jobs[0]? | throw (IO.userError "missing first job")
  let some last := reversed[1]? | throw (IO.userError "missing reordered job")
  let a ← success (compileFunction first)
  let b ← success (compileFunction last)
  require (decide (a = b)) "module order changed artifact"
  let duplicate := program.push program[0]!
  require (failed (prepareModule duplicate "job-tests")) "duplicate emitted symbol accepted"

private def mutations : IO Unit := do
  let job ← jobFor baseText
  let artifact ← success (compileFunction job)
  let mir := artifact.code.stackMIR
  let asm := artifact.code.assembly
  require (failed (StackMIR.validate { mir with layout.stageOffsets := #[0] })) "overlapping frame accepted"
  let some block := mir.blocks.find? (·.label == .body 0) | throw (IO.userError "missing MIR body")
  let earlyLoad := { block with instructions := #[.load .word .r9 (.stage 0)] ++ block.instructions }
  let badMIR := { mir with blocks := mir.blocks.map (fun b => if b.label == block.label then earlyLoad else b) }
  require (failed (StackMIR.validate badMIR)) "invalid stage load accepted"
  let noLeave := { block with instructions := block.instructions.filter (fun i => match i with | .leaveFrame _ => false | _ => true) }
  require (failed (StackMIR.validate { mir with blocks := mir.blocks.map (fun b => if b.label == block.label then noLeave else b) }))
    "missing frame teardown accepted"
  let some body := asm.blocks.find? (·.label == .body 0) | throw (IO.userError "missing assembly body")
  for instruction in [
      TypedA64.Instruction.load .long 9 1,
      .load .long 9 asm.frameBytes,
      .movk .word 9 1 32,
      .movz .long 19 1 0,
      .cset 9 .eq] do
    let badBody := { body with instructions := #[instruction] ++ body.instructions }
    require (failed (TypedA64.validate { asm with blocks := asm.blocks.map (fun b => if b.label == body.label then badBody else b) }))
      "illegal assembly mutation accepted"
  -- A legal in-bounds but wrong input offset is NOT a legality error. Exact
  -- artifact binding and semantic comparisons must detect it separately.
  let badBody := { body with instructions := body.instructions.map fun i => match i with
    | .load .word 10 8 => .load .word 10 0
    | other => other }
  let wrong := { asm with blocks := asm.blocks.map (fun b => if b.label == body.label then badBody else b) }
  let _ ← success (TypedA64.validate wrong)
  require (failed (verifyArtifact job { artifact with code.assembly := wrong })) "legal-but-wrong assembly bound as original"
  match Machine.evaluateAssembly wrong #[.word 3, .word 9] 1000 with
  | .returned value _ => require (value.toNat == 6) "corruption control did not change result"
  | other => throw (IO.userError s!"legal corruption should execute: {repr other}")
  -- Full-width slot reads must not invent the untouched upper half of a word.
  let state ← success (Machine.initial #[.word] #[.word 5] 16)
  let data := { state.data with sp := state.data.entrySP - 16, active := true }
  let data ← success (Machine.store data .word 0 5)
  require (failed (Machine.load data .long 0)) "uninitialized upper slot bytes became zero"
  -- Independent byte fixtures check reconstruction, byte order, mixed widths,
  -- and partial overlap, rather than only roundtripping the store helper.
  let fixture := { data with memory := #[some 8, some 7, some 6, some 5,
    some 4, some 3, some 2, some 1, some 255, some 254, some 253, some 252,
    some 251, some 250, some 249, some 248] }
  require ((← success (Machine.load fixture .long 0)) == 0x0102030405060708)
    "little-endian long reconstruction"
  require ((← success (Machine.load fixture .word 2)) == 0x03040506)
    "little-endian word reconstruction at byte offset"
  let overwritten ← success (Machine.store fixture .word 4 0xaabbccdd)
  require ((← success (Machine.load overwritten .long 0)) == 0xaabbccdd05060708)
    "overlapping word store changed the wrong bytes"
  require ((← success (Machine.load overwritten .long 8)) == 0xf8f9fafbfcfdfeff)
    "word store changed a disjoint long load"
  let data ← success (Machine.writeReg data .word 9 0xffffffffffffffff)
  require ((← success (Machine.readReg data .long 9)) == 4294967295) "W write failed to clear X high bits"
  for width in [Width.word, .long] do
    let flags := Machine.subtractFlags width 0 1
    require (!flags.carry && !flags.zero && flags.negative) "unsigned borrow flags"
    let flags := Machine.subtractFlags width 1 1
    require (flags.carry && flags.zero) "equality flags"

-- All API artifacts remain explicitly uncertified.
def run : IO Unit := do
  boundary
  mutations
  IO.println "function-job, typed-lowering, binding and mutation checks passed"

end LeanCompilerBackend.Verified.JobTests
