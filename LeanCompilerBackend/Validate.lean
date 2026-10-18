/-
  Admission checks for the initial QBE subset. QBE's SSA classes and use-before-
  definition checks are the reference; see docs/UPSTREAM.md (QBE parse.c/all.h).
  This checker admits straight-line leaf functions, not the complete QBE IL.
-/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend

private def validName (name : String) : Bool :=
  !name.isEmpty && name.toList.all (fun c => c.toNat < 128 && (c.isAlphanum || c == '_'))
    && (name.toList.head!.isAlpha || name.toList.head! == '_')

private def checkOperand (locals : List (String × Width)) (width : Width)
    (operand : Operand) : Except String Unit := do
  match operand with
  | .constant _ => return
  | .temporary name =>
    match locals.lookup name with
    | none => throw s!"undefined temporary %{name}"
    | some actual =>
      -- QBE permits using the low word of a long in a word context.
      if actual == .word && width == .long then
        throw s!"%{name}: implicit w-to-l extension is unsupported; use an explicit conversion"

def validateFunction (f : Function) : Except String Unit := do
  if !validName f.name || !validName f.entryLabel then throw "unsupported function/block name"
  if f.parameters.size > 8 then
    throw "initial AArch64 ABI subset supports at most eight integer parameters"
  if f.instructions.size > 480 then throw "function exceeds initial 480-instruction limit"
  let mut locals : List (String × Width) := []
  for p in f.parameters do
    if !validName p.name then throw "unsupported parameter name"
    if locals.any (fun (n, _) => n == p.name) then throw s!"duplicate parameter %{p.name}"
    locals := (p.name, p.width) :: locals
  for inst in f.instructions do
    if !validName inst.destination then throw "unsupported temporary name"
    if locals.any (fun (n, _) => n == inst.destination) then
      throw s!"duplicate SSA definition %{inst.destination}"
    match inst.operation with
    | .copy v => checkOperand locals inst.width v
    | .binary _ a b =>
      checkOperand locals inst.width a
      checkOperand locals inst.width b
    locals := (inst.destination, inst.width) :: locals
  checkOperand locals f.resultWidth f.result

def validate (program : Program) : Except String Unit := do
  if program.isEmpty then throw "program contains no functions"
  if program.size > 64 then throw "program exceeds initial 64-function limit"
  let mut names : List String := []
  for f in program do
    if names.contains f.name then throw s!"duplicate function ${f.name}"
    names := f.name :: names
    match validateFunction f with
    | .ok () => pure ()
    | .error message => throw s!"function ${f.name}: {message}"

end LeanCompilerBackend
