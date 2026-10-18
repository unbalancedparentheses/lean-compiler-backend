import LeanCompilerBackend

open LeanCompilerBackend

private def usage : String :=
  "Lean Compiler Backend 0.1.0\n" ++
  "Usage:\n" ++
  "  lcb INPUT.ssa [-o OUTPUT.s] [--target aarch64-macos]\n" ++
  "  lcb --check INPUT.ssa\n" ++
  "  lcb --eval INPUT.ssa FUNCTION [INTEGER ...]\n" ++
  "  lcb --version | --help\n" ++
  "Initial subset: QBE w/l integers, one block, copy/add/sub/mul/and/or/xor/ret.\n"

private def loadProgram (path : String) : IO Program := do
  let source ← IO.FS.readFile path
  match Parser.parse source >>= fun p => validate p *> pure p with
  | .ok program => return program
  | .error message => throw (IO.userError s!"{path}: {message}")

private def options : List String → Except String (Option String)
  | [] => .ok none
  | "-o" :: path :: rest => do
    let more ← options rest
    if more.isSome then throw "output specified more than once"
    return some path
  | "--target" :: "aarch64-macos" :: rest => options rest
  | "--target" :: target :: _ => .error s!"unsupported target '{target}'; supported: aarch64-macos"
  | option :: _ => .error s!"unknown or incomplete option '{option}'"

private def argument (text : String) : Except String UInt64 := do
  let some n := text.toInt? | throw s!"invalid integer argument '{text}'"
  if n < -(2 ^ 63 : Int) || n > (2 ^ 64 : Int) - 1 then
    throw s!"integer argument outside supported 64-bit domain: '{text}'"
  return (BitVec.ofInt 64 n).toNat.toUInt64

private def run (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println "lean-compiler-backend 0.1.0 (experimental)"; return 0
  | [] | ["--help"] => IO.print usage; return 0
  | ["--check", path] =>
    let program ← loadProgram path
    IO.println s!"checked {program.size} function(s); initial QBE subset"
    return 0
  | "--eval" :: path :: name :: values =>
    let program ← loadProgram path
    let some f := program.find? (·.name == name)
      | throw (IO.userError s!"unknown function '${name}'")
    let result := do
      let arguments ← values.toArray.mapM argument
      Semantics.evaluate f arguments
    match result with
    | .ok value => IO.println value; return 0
    | .error message => throw (IO.userError message)
  | path :: rest =>
    if path.startsWith "-" then throw (IO.userError s!"unknown or incomplete command '{path}'")
    let output ← match options rest with
      | .ok value => pure value
      | .error message => throw (IO.userError message)
    let program ← loadProgram path
    let assembly ← match AArch64.emit program with
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
