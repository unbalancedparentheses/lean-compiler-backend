/- Dispatch the Lake frontend invocation to the pinned Lean shell. Unknown
   options fail closed so an audit build cannot silently drop a build option. -/
module
import all Lean.Shell

open Lean

private def option (opts : ShellOptions) (key : Char) (value : Option String := none) :
    IO ShellOptions := do
  match ← (opts.process key value).toBaseIO with
  | .ok opts => return opts
  | .error code => IO.Process.exit code.toUInt8

private def arguments (opts : ShellOptions) :
    List String → IO (ShellOptions × List String)
  | [] => pure (opts, [])
  | "-o" :: value :: rest => do arguments (← option opts 'o' value) rest
  | "-i" :: value :: rest => do arguments (← option opts 'i' value) rest
  | "-c" :: value :: rest => do arguments (← option opts 'c' value) rest
  | "--setup" :: value :: rest => do arguments (← option opts 'u' value) rest
  | "--json" :: rest => do arguments (← option opts 'J') rest
  | arg :: rest => do
    if arg.startsWith "-" then
      throw (IO.userError s!"unsupported provenance compiler option: {arg}")
    let (opts, inputs) ← arguments opts rest
    return (opts, arg :: inputs)

public unsafe def main (args : List String) : IO UInt32 := do
  match args with
  | ["--githash"] => IO.println Lean.githash; return 0
  | ["--version"] => IO.println Lean.versionHeader; return 0
  | ["--print-prefix"] => IO.println (← getBuildDir); return 0
  | _ => pure ()
  initSearchPath (← getBuildDir)
  enableInitializersExecution
  let (opts, inputs) ← arguments {} args
  unless opts.oleanFileName?.isSome && opts.cFileName?.isSome do
    throw (IO.userError "provenance compilation requires -o and in-process C generation (-c)")
  shellMain inputs opts
