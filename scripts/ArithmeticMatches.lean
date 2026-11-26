module
import Lean

namespace LeanCompilerBackend
open Lean Elab Command

private def opcodeTypes : List Name :=
  [`LeanCompilerBackend.Binary, `LeanCompilerBackend.Unary, `LeanCompilerBackend.Division,
   `LeanCompilerBackend.Comparison, `LeanCompilerBackend.FloatBinary,
   `LeanCompilerBackend.FloatComparison, `LeanCompilerBackend.FloatConversion,
   `LeanCompilerBackend.AArch64.ALU,
   `LeanCompilerBackend.Verified.Source.Binary, `LeanCompilerBackend.Verified.Source.Comparison,
   `LeanCompilerBackend.Verified.Source.Division, `LeanCompilerBackend.Verified.TypedA64.Condition]

private def loweringModules : List Name :=
  [`LeanCompilerBackend.IR, `LeanCompilerBackend.Assembly, `LeanCompilerBackend.Selection,
   `LeanCompilerBackend.Semantics,
   `LeanCompilerBackend.AArch64, `LeanCompilerBackend.AArch64.ALU,
   `LeanCompilerBackend.AMD64, `LeanCompilerBackend.RV64,
   `LeanCompilerBackend.Verified.Source, `LeanCompilerBackend.Verified.Admission,
   `LeanCompilerBackend.Verified.Canonical, `LeanCompilerBackend.Verified.StackMIR,
   `LeanCompilerBackend.Verified.TypedA64, `LeanCompilerBackend.Verified.Machine,
   `LeanCompilerBackend.Verified.Codec]

private def dispatchTypes : List Name :=
  [`LeanCompilerBackend.Operation, `LeanCompilerBackend.Verified.Source.Operation]

open Lean.Parser.Term in
private partial def unwrapPattern (stx : Syntax) : Syntax :=
  match stx with
  | `(($inner)) | `(($inner : $_)) => unwrapPattern inner
  | `($_:ident@$inner) | `($_:ident@$_:ident:$inner) => unwrapPattern inner
  | _ => stx

open Lean.Parser.Term in
private partial def alternativePatterns (stx : Syntax) : Array Syntax :=
  let nested := stx.getArgs.flatMap alternativePatterns
  if let `(matchAltExpr| | $[$patterns,*]|* => $_) := stx then
    nested ++ patterns.flatMap (fun group => group.getElems.map (unwrapPattern ·.raw))
  else nested

private def patternHead (pattern : Syntax) : Syntax :=
  if pattern.isOfKind `Lean.Parser.Term.app then unwrapPattern pattern[0] else pattern

/-- Check source match alternatives using the types Lean assigned to their
    patterns. Opcode decisions must match the opcode directly so Lean checks
    coverage of that type. An outer dispatch may bind an opcode and pass it
    along, and selective peephole recognizers may use a refutable `let`. -/
private def arithmeticMatches : Linter where
  run stx := do
    let moduleName ← getMainModule
    unless loweringModules.contains moduleName do return
    if (← get).messages.hasErrors then return
    let patterns := alternativePatterns stx
    if patterns.isEmpty then return
    unless (← getInfoState).enabled do
      throwError "arithmetic match checking requires elaboration info"
    let ranges := patterns.filterMap Syntax.getRange?
    let heads := patterns.filterMap ((·.getRange?) ∘ patternHead)
    for tree in ← getInfoTrees do
      tree.visitM' (preNode := fun ctx info children => do
        let .ofTermInfo term := info | return true
        if let some range := term.stx.getRange? then
          let name := term.expr.getAppFn.constName
          if opcodeTypes.contains name.getPrefix && !heads.contains range && !ranges.contains range &&
              ranges.any (·.includes range) && (ctx.env.find? name).any ConstantInfo.isCtor then
            logErrorAt term.stx "match the arithmetic opcode directly to check all constructors"
        unless term.elaborator == `Lean.Elab.Term.elabMatch ||
               term.elaborator == `Lean.Elab.Do.elabDoMatch do return true
        for child in children do
          let .node (.ofTermInfo pattern) _ := child | continue
          unless pattern.isBinder do continue
          let some range := pattern.stx.getRange? | continue
          unless ranges.contains range do continue
          let .fvar id := pattern.expr | continue
          let some declaration := pattern.lctx.find? id | continue
          let type ← ctx.runMetaM pattern.lctx do
            Meta.whnf (← instantiateMVars declaration.type)
          if opcodeTypes.contains type.getAppFn.constName ||
             dispatchTypes.contains type.getAppFn.constName then
            logErrorAt pattern.stx "arithmetic lowering requires an explicit opcode constructor"
        return true)

private def installArithmeticMatches : IO Unit := addLinter arithmeticMatches

end LeanCompilerBackend

open Lean in
public unsafe def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  LeanCompilerBackend.installArithmeticMatches
  let files := if args.isEmpty then
    LeanCompilerBackend.loweringModules.map (fun m => (modToFilePath "." m "lean").toString)
  else args
  for file in files do
    enableInitializersExecution
    let name ← moduleNameOfFileName file none
    let result ← Elab.runFrontend (← IO.FS.readFile file) {} file name 0 none none false
    if result.isNone then return 1
  return 0
