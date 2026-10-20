import LeanCompilerBackend
import LeanCompilerBackend.Verified.Codec

open LeanCompilerBackend

private def usage : String :=
  "Lean Compiler Backend 0.1.0\n" ++
  "Usage:\n" ++
  "  lcb INPUT.ssa [-o OUTPUT.s] [--target aarch64-macos]\n" ++
  "  lcb --check INPUT.ssa\n" ++
  "  lcb --first-path INPUT.ssa [-o OUTPUT.s] [--require-proof]\n" ++
  "  lcb --first-path-eval INPUT.ssa FUNCTION [INTEGER ...]\n" ++
  "  lcb --write-job INPUT.ssa FUNCTION OUTPUT.job\n" ++
  "  lcb --replay-job INPUT.job [-o OUTPUT.s]\n" ++
  "  lcb --write-artifact INPUT.job OUTPUT.artifact\n" ++
  "  lcb --replay-artifact INPUT.artifact [-o OUTPUT.s]\n" ++
  "  lcb --job-info INPUT.job\n" ++
  "  lcb --eval INPUT.ssa FUNCTION [INTEGER ...]\n" ++
  "  lcb --version | --build-identity | --help\n" ++
  "Initial subset: QBE w/l SSA, integer/control flow, direct/indirect integer calls, loads/stores, integer data/symbols and constant/runtime-sized stack allocations.\n"

private def loadModule (path : String) : IO LeanCompilerBackend.Module := do
  let source ← IO.FS.readFile path
  match Parser.parseModule source >>= fun m => validateModule m *> pure m with
  | .ok module => return module
  | .error message => throw (IO.userError s!"{path}: {message}")

private def loadProgram (path : String) : IO Program := do
  let module ← loadModule path
  if !module.data.isEmpty then
    throw (IO.userError "module data is outside the first-path profile")
  return module.functions

private def options : List String → Except String (Option String)
  | [] => .ok none
  | "-o" :: path :: rest => do
    let more ← options rest
    if more.isSome then throw "output specified more than once"
    return some path
  | "--target" :: "aarch64-macos" :: rest => options rest
  | "--target" :: target :: _ => .error s!"unsupported target '{target}'; supported: aarch64-macos"
  | option :: _ => .error s!"unknown or incomplete option '{option}'"

private def firstPathOptions (args : List String) : Except String (Option String × Verified.EvidenceRequest) := do
  let requested := if args.contains "--require-proof" then .kernelTypedAssembly else .none
  let output ← options (args.filter (· != "--require-proof"))
  pure (output, requested)

private def firstPath (program : Program) (requested : Verified.EvidenceRequest) : Except String String := do
  let jobs ← (Verified.prepareModule program "cli" requested).mapError (fun e => toString (repr e))
  let mut fragments := []
  for job in jobs do
    let artifact ← (Verified.compileFunction job).mapError (fun e => toString (repr e))
    fragments := fragments ++ [artifact.code.fragment]
  pure ("; Uncertified first-path typed assembly; no preservation certificate\n.text\n" ++
    String.intercalate "\n" fragments ++ ".subsections_via_symbols\n")

private def readJob (path : String) : IO Verified.FunctionJob := do
  match Verified.Codec.decodeJob (← IO.FS.readBinFile path) with
  | .ok job => pure job
  | .error reason => throw (IO.userError reason)

private def compileJob (job : Verified.FunctionJob) : IO Verified.FunctionArtifact := do
  match Verified.compileFunction job with
  | .ok artifact => pure artifact
  | .error reason => throw (IO.userError (toString (repr reason)))

private def outputFragment (fragment : String) (rest : List String) : IO UInt32 := do
  let output ← match options rest with
    | .ok value => pure value
    | .error reason => throw (IO.userError reason)
  let assembly := "; Uncertified first-path replay\n.text\n" ++ fragment ++ ".subsections_via_symbols\n"
  match output with
  | some path => IO.FS.writeFile path assembly
  | none => IO.print assembly
  pure 0

private def argument (text : String) : Except String UInt64 := do
  let some n := text.toInt? | throw s!"invalid integer argument '{text}'"
  if n < -(2 ^ 63 : Int) || n > (2 ^ 64 : Int) - 1 then
    throw s!"integer argument outside supported 64-bit domain: '{text}'"
  return (BitVec.ofInt 64 n).toNat.toUInt64

private def run (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println "lean-compiler-backend 0.1.0 (experimental)"; return 0
  | ["--build-identity"] => IO.println Verified.compilerBuildIdentity; return 0
  | [] | ["--help"] => IO.print usage; return 0
  | ["--check", path] =>
    let module ← loadModule path
    IO.println s!"checked {module.functions.size} function(s), {module.data.size} data definition(s); initial QBE subset"
    return 0
  | "--first-path-eval" :: path :: name :: values =>
    let program ← loadProgram path
    let some f := program.find? (·.name == name) | throw (IO.userError s!"unknown function ${name}")
    let job ← match Verified.prepareJob f "cli" with
      | .ok job => pure job
      | .error e => throw (IO.userError (toString (repr e)))
    let artifact ← compileJob job
    let numbers ← match values.toArray.mapM argument with
      | .ok numbers => pure numbers
      | .error e => throw (IO.userError e)
    if numbers.size != job.code.body.parameters.size then throw (IO.userError "argument count mismatch")
    let args := (job.code.body.parameters.zip numbers).map fun (width, number) =>
      Verified.Source.Value.constant width number.toNat
    let result ← match Verified.Source.evaluateFunction job.code.body args 100000 with
      | .returned value => pure value
      | .exhausted _ => throw (IO.userError "source model budget exhausted; inconclusive")
      | .stuck fault => throw (IO.userError s!"source model fault: {repr fault}")
    for (stage, execution) in [
        ("MIR", Verified.Machine.evaluateMIR artifact.code.stackMIR args 1000000),
        ("assembly", Verified.Machine.evaluateAssembly artifact.code.assembly args 1000000)] do
      match execution with
      | .returned value _ =>
        if value != result then throw (IO.userError s!"{stage} model differs from source")
      | .exhausted _ => throw (IO.userError s!"{stage} model budget exhausted; inconclusive")
      | .stuck fault => throw (IO.userError s!"{stage} model fault: {fault}")
    IO.println result.toNat
    pure 0
  | ["--write-job", path, name, output] =>
    let program ← loadProgram path
    let some f := program.find? (·.name == name) | throw (IO.userError s!"unknown function ${name}")
    let job ← match Verified.prepareJob f "cli" with
      | .ok job => pure job
      | .error reason => throw (IO.userError (toString (repr reason)))
    let bytes ← match Verified.Codec.encodeJob job with
      | .ok bytes => pure bytes
      | .error reason => throw (IO.userError reason)
    IO.FS.writeBinFile output bytes
    pure 0
  | "--replay-job" :: path :: rest =>
    let artifact ← compileJob (← readJob path)
    outputFragment artifact.code.fragment rest
  | ["--write-artifact", path, output] =>
    let job ← readJob path
    let artifact ← compileJob job
    let bytes ← match Verified.Codec.encodeArtifact job artifact with
      | .ok bytes => pure bytes
      | .error reason => throw (IO.userError reason)
    IO.FS.writeBinFile output bytes
    pure 0
  | "--replay-artifact" :: path :: rest =>
    let (_, artifact) ← match Verified.Codec.decodeArtifact (← IO.FS.readBinFile path) with
      | .ok result => pure result
      | .error reason => throw (IO.userError reason)
    outputFragment artifact.code.fragment rest
  | ["--job-info", path] =>
    let artifact ← compileJob (← readJob path)
    let ids ← match Verified.Codec.fingerprints artifact with
      | .ok ids => pure ids
      | .error reason => throw (IO.userError reason)
    IO.println s!"status: uncertified\ncode-input: {ids.codeInput}\ncode: {ids.code}\ndebug: {ids.debug}\nevidence: {ids.evidence}"
    pure 0
  | "--first-path" :: path :: rest =>
    let (output, requested) ← match firstPathOptions rest with
      | .ok value => pure value
      | .error message => throw (IO.userError message)
    let program ← loadProgram path
    let assembly ← match firstPath program requested with
      | .ok text => pure text
      | .error message => throw (IO.userError message)
    match output with
    | some target => IO.FS.writeFile target assembly
    | none => IO.print assembly
    return 0
  | "--eval" :: path :: name :: values =>
    let module ← loadModule path
    let result := do
      let arguments ← values.toArray.mapM argument
      Semantics.evaluateModule module name arguments
    match result with
    | .ok (some value) => IO.println value; return 0
    | .ok none => IO.println "void"; return 0
    | .error message => throw (IO.userError message)
  | path :: rest =>
    if path.startsWith "-" then throw (IO.userError s!"unknown or incomplete command '{path}'")
    let output ← match options rest with
      | .ok value => pure value
      | .error message => throw (IO.userError message)
    let module ← loadModule path
    let assembly ← match AArch64.emitModule module with
      | .ok text => pure text
      | .error message => throw (IO.userError message)
    match output with
    | some target => IO.FS.writeFile target assembly
    | none => IO.print assembly
    return 0

def main (args : List String) : IO UInt32 := do
  try run args
  catch error =>
    IO.eprintln s!"error: {error}"
    return 1
