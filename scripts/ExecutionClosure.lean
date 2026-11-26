/- Audit the kernel and native execution dependencies of the backend APIs. -/
import Lean

open Lean

namespace ExecutionClosure

def moduleOf (env : Environment) (n : Name) : Name :=
  ((env.getModuleIdxFor? n).bind fun i => env.header.moduleNames[i.toNat]?).getD .anonymous

-- The pinned Init and Std implementations provide the runtime primitives.
def runtimeModule (m : Name) : Bool :=
  m.getRoot == `Init || m.getRoot == `Std

def restrictions (env : Environment) (n : Name) (ci : ConstantInfo) :
    Array (String × String) := Id.run do
  let mut keys := #[]
  if ci.isUnsafe then keys := keys.push ("unsafe", n.toString)
  if ci.isPartial || ((ci matches .opaqueInfo _) &&
      (env.find? (Compiler.mkUnsafeRecName n)).any (·.isPartial)) then
    keys := keys.push ("partial", n.toString)
  if let some replacement := Compiler.getImplementedBy? env n then
    keys := keys.push ("implemented_by", s!"{n} → {replacement}")
  if (getExternAttrData? env n).isSome then keys := keys.push ("extern", n.toString)
  if isNoncomputable env n then keys := keys.push ("noncomputable", n.toString)
  if ci matches .opaqueInfo _ then keys := keys.push ("opaque", n.toString)
  if ci matches .axiomInfo _ then keys := keys.push ("axiom", n.toString)
  return keys

def stageEffect (env : Environment) (caller callee : Name) : Bool :=
  let pinnedCaller := runtimeModule (moduleOf env caller)
  [`IO, `BaseIO, `EIO, `ST, `EST, `Task].any (·.isPrefixOf callee) ||
    callee == `runST || callee == `runEST ||
    ((`System.Platform).isPrefixOf callee &&
      !(pinnedCaller && callee == `System.Platform.numBits && (`USize).isPrefixOf caller) &&
      !(pinnedCaller && callee == `System.Platform.getNumBits && caller == `System.Platform.numBits))

-- Compiler-generated recursion helpers implement the checked kernel definition.
-- Audit their callers through the safe parent; handwritten lookalikes have a range.
def recursiveParent (env : Environment) (n : Name) : Option Name := do
  let parent ← Compiler.isUnsafeRecName? n
  let .defnInfo d ← env.find? parent | none
  if d.safety == .safe && moduleOf env parent == moduleOf env n &&
      (declRangeExt.find? (level := .private) env n).isNone &&
      (declRangeExt.find? (level := .server) env n).isNone then some parent
  else none

def proofOnly (ci : ConstantInfo) : Bool :=
  (ci matches .thmInfo _) || ci.type.getForallBody == .sort .zero

abbrev Rewrites := Std.HashMap Name (Array (Name × Compiler.CSimp.Entry))
abbrev NativeDecls := Std.HashMap Name (Name × IR.Decl)

-- Local compiler rewrites can disappear from extension metadata at end of
-- scope. Follow calls and closures in the emitted IR as well as kernel edges.
partial def nativeCalls (body : IR.FnBody) (calls : Array Name := #[]) : Array Name :=
  match body with
  | .vdecl _ _ (.fap n _) next | .vdecl _ _ (.pap n _) next => nativeCalls next (calls.push n)
  | .jdecl _ _ body next => nativeCalls next (nativeCalls body calls)
  | .case _ _ _ branches => branches.foldl (fun acc alt => nativeCalls alt.body acc) calls
  | .ret _ | .jmp .. | .unreachable => calls
  | .vdecl _ _ _ next | .set _ _ _ next | .setTag _ _ next |
    .uset _ _ _ next | .sset _ _ _ _ _ next | .inc _ _ _ _ next |
    .dec _ _ _ _ next | .del _ next => nativeCalls next calls

def roots : Array Name := #[
  `LeanCompilerBackend.Verified.validateSource,
  `LeanCompilerBackend.Verified.reify,
  `LeanCompilerBackend.Verified.admit,
  `LeanCompilerBackend.Verified.validateJob,
  `LeanCompilerBackend.Verified.prepareJob,
  `LeanCompilerBackend.Verified.prepareModule,
  `LeanCompilerBackend.Verified.compileFunction,
  `LeanCompilerBackend.Verified.verifyArtifact,
  `LeanCompilerBackend.validateModule,
  `LeanCompilerBackend.AArch64.emitModule,
  `LeanCompilerBackend.AArch64.emitModuleValidated,
  `LeanCompilerBackend.AMD64.emitModule,
  `LeanCompilerBackend.AMD64.emitModuleValidated,
  `LeanCompilerBackend.RV64.emitModule,
  `LeanCompilerBackend.RV64.emitModuleValidated,
  `LeanCompilerBackend.Verified.Codec.encodeJob,
  `LeanCompilerBackend.Verified.Codec.decodeJob,
  `LeanCompilerBackend.Verified.Codec.encodeArtifact,
  `LeanCompilerBackend.Verified.Codec.decodeArtifact,
  `LeanCompilerBackend.Verified.Codec.decodeArtifactFor
]

def inspect (env : Environment) (rewrites : Rewrites) (native : NativeDecls)
    (exceptions : Std.HashSet (String × String)) (roots : Array Name) :
    IO (Nat × Std.HashSet (String × String) × Array String) := do
  let mut pending := roots.map fun n => (n, n)
  let mut seen : Std.HashSet Name := {}
  let mut used : Std.HashSet (String × String) := {}
  let mut failures := #[]
  let mut idx := 0
  while idx < pending.size do
    let (n, caller) := pending[idx]!
    idx := idx + 1
    if stageEffect env caller n then
      failures := failures.push s!"stage effect	{n}	from {caller}"
      continue
    if seen.contains n then continue
    seen := seen.insert n
    let owner := moduleOf env n
    let ir := native[n]?
    if let some (m, decl) := ir then
      match decl with
      | .fdecl _ _ _ body _ =>
        unless runtimeModule m do
          for dep in nativeCalls body do pending := pending.push (dep, n)
      | .extern _ _ _ data =>
        if !runtimeModule m && !data.entries.all (· == .opaque) then
          failures := failures.push s!"native extern	{n}	from {caller}"
    let some ci := env.find? n | do
      if ir.isNone then failures := failures.push s!"missing declaration	{n}	from {caller}"
      continue
    if proofOnly ci then continue
    if n == `Lean.Loop.forIn || n == `repeatM then
      failures := failures.push s!"while	{n}	from {caller}"
    for (m, rewrite) in rewrites[n]?.getD #[] do
      let key := ("csimp", s!"{n} → {rewrite.toDeclName}")
      if runtimeModule m && runtimeModule owner && exceptions.contains key then
        used := used.insert key
      else failures := failures.push s!"{key.1}	{key.2}	registered by {rewrite.thmName} in {m}"
      pending := pending.push (rewrite.toDeclName, n)
    if let some implementation := Compiler.getImplementedBy? env n then
      pending := pending.push (implementation, n)
    if let some parent := recursiveParent env n then
      pending := pending.push (parent, n)
      continue
    for key in restrictions env n ci do
      if runtimeModule owner && exceptions.contains key then used := used.insert key
      else failures := failures.push s!"{key.1}	{key.2}	from {caller}"
    let mut deps := ci.getUsedConstantsAsSet
    if let .recInfo r := ci then
      for rule in r.rules do
        for dep in rule.rhs.getUsedConstants do deps := deps.insert dep
    for dep in deps do
      -- Native specializations use word-sized array indices and hash buckets.
      -- A backend kernel definition may not make its result depend on them.
      if !runtimeModule owner && [`USize, `ISize].any (·.isPrefixOf dep) then
        failures := failures.push s!"host word size	{dep}	from {n}"
      pending := pending.push (dep, n)
  return (seen.size, used, failures)

def readExceptions : IO (Std.HashSet (String × String)) := do
  let mut entries := {}
  for line in (← IO.FS.readFile "scripts/execution-primitives.tsv").splitOn "\n" do
    if line.isEmpty || line.startsWith "#" then continue
    let [kind, name, justification] := line.splitOn "\t" |
      throw (IO.userError s!"malformed execution primitive entry: {line}")
    if justification.isEmpty || entries.contains (kind, name) then
      throw (IO.userError s!"missing justification or duplicate primitive: {line}")
    entries := entries.insert (kind, name)
  return entries

def run (args : List String) : IO UInt32 := do
  let exceptions ← readExceptions
  let (imports, auditRoots) ← match args with
    | [] => pure (#[{module := `LeanCompilerBackend}, {module := `LeanCompilerBackend.Verified.Codec}], roots)
    | module :: root :: rest => pure (#[{module := module.toName}], (root :: rest).toArray.map String.toName)
    | _ => throw (IO.userError "expected a control module followed by one or more roots")
  initSearchPath (← findSysroot)
  let runtimeRoot ← IO.FS.realPath ((← findSysroot) / "lib" / "lean")
  let env ← importModules imports {}
  for root in auditRoots do
    unless (env.find? root).any (!proofOnly ·) do
      throw (IO.userError s!"invalid execution root {root}")
  let mut rewrites : Rewrites := {}
  let mut native : NativeDecls := {}
  for (m, idx) in env.header.moduleNames.toList.zipIdx do
    if runtimeModule m then
      let artifact ← IO.FS.realPath (← findOLean m)
      unless artifact.toString.startsWith (runtimeRoot.toString ++ "/") do
        throw (IO.userError s!"{m} shadows the pinned Lean runtime: {artifact}")
    for d in IR.declMapExt.getModuleEntries env idx ++ IR.declMapExt.getModuleIREntries env idx do
      native := native.insert d.name (m, d)
    for entry in Compiler.CSimp.ext.ext.getModuleEntries env idx do
      let rewrite := match entry with
        | .global e | .scoped _ e => e
      rewrites := rewrites.insert rewrite.fromDeclName
        ((rewrites[rewrite.fromDeclName]?.getD #[]).push (m, rewrite))
  let (visited, used, failures) ← inspect env rewrites native exceptions auditRoots
  for msg in failures do IO.eprintln msg
  if !failures.isEmpty then return 1
  if args.isEmpty then
    for unused in exceptions.toList.filter (!used.contains ·) do
      IO.eprintln s!"unused execution primitive: {unused.1} {unused.2}"
    if used.size != exceptions.size then return 1
  IO.println s!"execution closure: {auditRoots.size} roots, {visited} declarations, {used.size} pinned Lean exceptions"
  return 0

end ExecutionClosure

def main := ExecutionClosure.run
