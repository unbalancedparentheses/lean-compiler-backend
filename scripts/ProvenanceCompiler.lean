/- Driver for the pinned Lean frontend linked with the CSimp lookup recorder. -/
module
import all Lean.Shell
import Lean
import ArithmeticMatches

open Lean

private def arguments (opts : ShellOptions) :
    List String → IO (ShellOptions × List String)
  | [] => pure (opts, [])
  | "-o" :: value :: rest => arguments { opts with oleanFileName? := some value } rest
  | "-i" :: value :: rest => arguments { opts with ileanFileName? := some value } rest
  | "-c" :: value :: rest => arguments { opts with cFileName? := some value } rest
  | "--setup" :: value :: rest => arguments { opts with setupFileName? := some value } rest
  | "--json" :: rest => arguments { opts with jsonOutput := true } rest
  | arg :: rest => do
    if arg.startsWith "-" then
      throw (IO.userError s!"unsupported provenance compiler option: {arg}")
    let (opts, inputs) ← arguments opts rest
    return (opts, arg :: inputs)

@[extern "lean_lcb_csimp_journal"]
private opaque rewriteJournal (_ : Unit) : BaseIO String

public unsafe def main (args : List String) : IO UInt32 := do
  match args with
  | ["--githash"] => IO.println Lean.githash; return 0
  | ["--version"] => IO.println Lean.versionHeader; return 0
  | ["--print-prefix"] => IO.println (← getBuildDir); return 0
  | _ => pure ()
  initSearchPath (← getBuildDir)
  enableInitializersExecution
  LeanCompilerBackend.installArithmeticMatches
  let (opts, inputs) ← arguments {} args
  let [input] := inputs |
    throw (IO.userError "provenance compilation requires one input")
  let some artifact := opts.oleanFileName? |
    throw (IO.userError "provenance compilation requires -o")
  unless opts.setupFileName?.isNone || opts.cFileName?.isSome do
    throw (IO.userError "provenance compilation requires in-process native code generation")
  let setup ← opts.setupFileName?.mapM ModuleSetup.load
  let moduleName ← match setup with
    | some setup => pure setup.name
    | none => moduleNameOfFileName input none
  let contents ← IO.FS.readFile input
  let some env ← Elab.runFrontend contents {} input moduleName opts.trustLevel
      (some artifact) opts.ileanFileName? opts.jsonOutput (setup? := setup) |
    return 1
  if let some output := opts.cFileName? then
    let code ← (Compiler.LCNF.emitC moduleName).toIO' {fileName := input, fileMap := default} {env}
    IO.FS.writeFile output code
  let digest ← IO.Process.run {cmd := "sha256sum", args := #[artifact.toString]}
  IO.FS.writeFile (artifact.addExtension "csimp") <|
    (← rewriteJournal ()) ++ (digest.take 64).toString ++ "\n"
  return 0
