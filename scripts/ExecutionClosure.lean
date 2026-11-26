/- Audit the kernel and native execution dependencies of the backend APIs. -/
import Lean

open Lean

namespace ExecutionClosure

def moduleOf (env : Environment) (n : Name) : Name :=
  ((env.getModuleIdxFor? n).bind fun i => env.header.moduleNames[i.toNat]?).getD .anonymous

-- The pinned Init and Std implementations provide the runtime primitives.
def runtimeModule (m : Name) : Bool :=
  m.getRoot == `Init || m.getRoot == `Std

private def backendImports : Array Import :=
  #[{module := `LeanCompilerBackend}, {module := `LeanCompilerBackend.Verified.Codec}]

def checkImports (sourceRoot : System.FilePath) (controls : List String) : IO UInt32 := do
  let mut pending := if controls.isEmpty then backendImports.toList.map (·.module)
    else controls.map String.toName
  let mut visited : Std.HashSet Name := {}
  while let m :: rest := pending do
    pending := rest
    if visited.contains m then continue
    visited := visited.insert m
    let file := modToFilePath sourceRoot m "lean"
    let (imports, _, messages) ← Elab.parseImports (← IO.FS.readFile file) (some file.toString)
    if messages.hasErrors then
      for message in messages.toList do IO.eprintln (← message.toString)
      return 1
    for entry in imports do
      let dep := entry.module
      if runtimeModule dep then continue
      if dep.getRoot == `Lean || (controls.isEmpty && dep.getRoot != `LeanCompilerBackend) then
        IO.eprintln s!"execution audit forbidden import {dep} in {m}"
        return 1
      pending := dep :: pending
  return 0

def partialImplementation? (env : Environment) (n : Name) (ci : ConstantInfo) :
    Option Name := do
  let .opaqueInfo _ := ci | none
  let helper := Compiler.mkUnsafeRecName n
  if (env.find? helper).any (·.isPartial) then some helper else none

def restrictions (env : Environment) (n : Name) (ci : ConstantInfo) :
    Array (String × String) := Id.run do
  let mut keys := #[]
  if ci.isUnsafe then keys := keys.push ("unsafe", n.toString)
  if ci.isPartial || (partialImplementation? env n ci).isSome then
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
  `LeanCompilerBackend.Parser.parseModule,
  `LeanCompilerBackend.SSA.constructModule,
  `LeanCompilerBackend.Optimize.module,
  `LeanCompilerBackend.Optimize.moduleValidated,
  `LeanCompilerBackend.Verified.Codec.fingerprints,
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

def rejectedAxioms (env : Environment) (n : Name) : IO (Array Name) := do
  let (axioms, _) ← (Lean.collectAxioms n : CoreM (Array Name)).toIO
    { fileName := "", fileMap := default } { env }
  return axioms.filter fun axiomName => !#[`propext, `Classical.choice, `Quot.sound].contains axiomName

def provesRewrite (env : Environment) (rewrite : Compiler.CSimp.Entry) : Bool :=
  match env.checked.get.find? rewrite.thmName with
  | some (.thmInfo theoremInfo) =>
    match theoremInfo.type.eq? with
    | some (_, .const fromName us, .const toName vs) =>
      let params := theoremInfo.levelParams.map Level.param
      fromName == rewrite.fromDeclName && toName == rewrite.toDeclName &&
        us == vs && us.length == params.length && params.all (us.contains ·)
    | _ => false
  | _ => false

structure Report where
  visited : Nat
  used : Std.HashSet (String × String)
  failures : Array String
  substitutions : Array String

def inspect (env : Environment) (rewrites : Rewrites) (native : NativeDecls)
    (exceptions : Std.HashSet (String × String)) (roots : Array Name) :
    IO Report := do
  let mut pending := roots.map fun n => (n, n)
  let mut seen : Std.HashSet Name := {}
  let mut used : Std.HashSet (String × String) := {}
  let mut failures := #[]
  let mut substitutions := #[]
  -- Each seed covers its entire kernel proof closure. Native-only backend
  -- callees and compiler rewrites can add seeds absent from the root terms.
  let mut proofRoots := Std.HashSet.ofArray roots
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
    let info := env.find? n
    let partialHelper := info.bind (partialImplementation? env n)
    if let some (m, decl) := ir then
      match decl with
      | .fdecl _ _ _ body _ =>
        unless runtimeModule m && partialHelper.isNone && !info.any (·.isPartial) do
          for dep in nativeCalls body do
            pending := pending.push (dep, n)
            if !runtimeModule (moduleOf env dep) then
              proofRoots := proofRoots.insert ((recursiveParent env dep).getD dep)
      | .extern _ _ _ data =>
        if !runtimeModule m && !data.entries.all (· == .opaque) then
          failures := failures.push s!"native extern	{n}	from {caller}"
    let some ci := info | do
      if ir.isNone then failures := failures.push s!"missing declaration	{n}	from {caller}"
      continue
    if proofOnly ci then continue
    if let some helper := partialHelper then
      pending := pending.push (helper, n)
    if n == `Lean.Loop.forIn || n == `repeatM then
      failures := failures.push s!"while	{n}	from {caller}"
    for (m, rewrite) in rewrites[n]?.getD #[] do
      let description := s!"{n} → {rewrite.toDeclName} by {rewrite.thmName} in {m}"
      pending := pending.push (rewrite.thmName, n)
      pending := pending.push (rewrite.toDeclName, n)
      proofRoots := (proofRoots.insert rewrite.thmName).insert rewrite.toDeclName
      if provesRewrite env rewrite then
        substitutions := substitutions.push description
      else
        failures := failures.push s!"csimp theorem	{rewrite.thmName}	missing or invalid for {description}"
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
  for n in proofRoots.toArray.qsort Name.quickLt do
    if (env.find? n).isNone then continue
    for axiomName in ← rejectedAxioms env n do
      failures := failures.push s!"proof axiom	{axiomName}	from {n}"
  return ⟨seen.size, used, failures, substitutions⟩

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

private def decodeName (parts : Array Json) : Except String Name :=
  parts.foldlM (init := .anonymous) fun parent part =>
    match part with
    | .str text => pure (.str parent text)
    | value => return .num parent (← value.getNat?)

private def parseRewrite (line : String) : Except String Compiler.CSimp.Entry := do
  let #[fromParts, toParts, theoremParts] ← (← Json.parse line).getArr? |
    throw "expected two constants and an equality theorem"
  return ⟨← decodeName (← fromParts.getArr?), ← decodeName (← toParts.getArr?),
    ← decodeName (← theoremParts.getArr?)⟩

private def readJournal (artifact : System.FilePath) : IO (Array Compiler.CSimp.Entry) := do
  let path := artifact.addExtension "csimp"
  unless ← path.pathExists do
    throw (IO.userError s!"missing compiler rewrite journal: {path}")
  let lines ← IO.FS.lines path
  let some digest := lines.back? | throw (IO.userError s!"incomplete compiler rewrite journal: {path}")
  let hashed ← IO.Process.run {cmd := "sha256sum", args := #[artifact.toString]}
  unless digest.length == 64 && hashed.startsWith (digest ++ " ") do
    throw (IO.userError s!"compiler rewrite journal does not match artifact: {path}")
  lines.pop.mapM fun line =>
    match parseRewrite line with
    | .ok rewrite => pure rewrite
    | .error reason => throw (IO.userError s!"invalid compiler rewrite journal {path}: {reason}")

private def addRewrite (rewrites : Rewrites) (m : Name)
    (entry : Compiler.CSimp.Entry) : Rewrites :=
  let known := rewrites[entry.fromDeclName]?.getD #[]
  if known.any (fun (_, previous) =>
      previous.toDeclName == entry.toDeclName && previous.thmName == entry.thmName) then
    rewrites
  else
    rewrites.insert entry.fromDeclName (known.push (m, entry))

structure BuildPair where
  stockLib : System.FilePath
  stockIR : System.FilePath
  auditLib : System.FilePath
  auditIR : System.FilePath

private def checkCorrespondence (build : BuildPair) (m : Name)
    (artifact : System.FilePath) : IO Unit := do
  let expected ← IO.FS.realPath (modToFilePath build.auditLib m "olean")
  unless artifact == expected do
    throw (IO.userError s!"execution audit imported {m} from outside the audit build: {artifact}")
  let compare (stock recorded : System.FilePath) (kind : String) : IO Unit := do
    unless (← IO.FS.readBinFile stock) == (← IO.FS.readBinFile recorded) do
      throw (IO.userError s!"execution audit build mismatch for {m}: {kind} differs from stock Lean")
  compare (modToFilePath build.stockIR m "c") (modToFilePath build.auditIR m "c") "generated C"
  for ext in ["olean", "olean.private", "olean.server", "ir", "ir.sig"] do
    let stock := modToFilePath build.stockLib m ext
    let recorded := modToFilePath build.auditLib m ext
    let hasStock ← stock.pathExists
    let hasRecorded ← recorded.pathExists
    unless hasStock == hasRecorded do
      throw (IO.userError s!"execution audit build mismatch for {m}: unequal {ext} artifact sets")
    if hasStock || ext == "olean" then
      compare stock recorded ext

def run (args : List String) (build : Option BuildPair := none) : IO UInt32 := do
  if args.isEmpty && build.isNone then
    throw (IO.userError "the backend closure audit requires a stock build for comparison")
  let exceptions ← readExceptions
  let (imports, auditRoots) ← match args with
    | [] => pure (backendImports, roots)
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
  let mut journals := #[]
  let mut invalid := false
  let mut forbiddenImport := none
  for (m, idx) in env.header.moduleNames.toList.zipIdx do
    let artifact ← IO.FS.realPath (← findOLean m)
    if artifact.toString.startsWith (runtimeRoot.toString ++ "/") then
      -- Only Init and Std are available to backend elaboration. In particular,
      -- no module in the import graph can expose the compiler mutation API.
      if build.isSome && !runtimeModule m && forbiddenImport.isNone then
        forbiddenImport := some m
    else if runtimeModule m || m.getRoot == `Lean then
      throw (IO.userError s!"{m} shadows the pinned Lean toolchain: {artifact}")
    else
      if let some build := build then
        unless !args.isEmpty || m.getRoot == `LeanCompilerBackend do
          throw (IO.userError s!"execution audit import outside LeanCompilerBackend: {m}")
        checkCorrespondence build m artifact
      for (kind, initAttr) in #[("init", regularInitAttr), ("builtin_init", builtinInitAttr)] do
        let entries := initAttr.ext.getModuleEntries env idx ++ initAttr.ext.getModuleIREntries env idx
        for (decl, action) in (Std.HashSet.ofArray entries).toArray do
          IO.eprintln s!"initializer	{kind}	{decl}	{action}	in {m}"
          invalid := true
      journals := journals.push (m, ← readJournal artifact)
    for d in IR.declMapExt.getModuleEntries env idx ++ IR.declMapExt.getModuleIREntries env idx do
      native := native.insert d.name (m, d)
    for entry in Compiler.CSimp.ext.ext.getModuleEntries env idx do
      let rewrite := match entry with
        | .global e | .scoped _ e => e
      rewrites := addRewrite rewrites m rewrite
  -- The compiler also introduces calls that have no corresponding kernel edge.
  -- Seed any newly observed replacement and check its equality even if the
  -- rewritten occurrence was subsequently inlined away.
  let mut extraRoots := #[]
  let mut observed : Std.HashSet (Name × Name × Name) := {}
  for (m, journal) in journals do
    for rewrite in journal do
      let key := (rewrite.fromDeclName, rewrite.toDeclName, rewrite.thmName)
      unless observed.contains key do
        observed := observed.insert key
        unless provesRewrite env rewrite do
          IO.eprintln s!"csimp theorem	{rewrite.thmName}	missing or invalid in compiler journal for {m}"
          invalid := true
        for axiomName in ← rejectedAxioms env rewrite.thmName do
          IO.eprintln s!"proof axiom	{axiomName}	from {rewrite.thmName}"
          invalid := true
        -- Check custom replacements even when optimization erased the call.
        unless runtimeModule (moduleOf env rewrite.thmName) do
          extraRoots := extraRoots.push rewrite.fromDeclName
        rewrites := addRewrite rewrites m rewrite
  if let some m := forbiddenImport then
    IO.eprintln s!"toolchain import outside Init and Std	{m}"
    invalid := true
  if invalid then return 1
  if build.isSome then
    IO.println s!"execution audit correspondence: {journals.size} modules match stock Lean byte-for-byte"
  let report ← inspect env rewrites native exceptions (auditRoots ++ extraRoots)
  for msg in report.failures do IO.eprintln msg
  if args.isEmpty then
    for unused in exceptions.toList.filter (!report.used.contains ·) do
      IO.eprintln s!"unused execution primitive: {unused.1} {unused.2}"
    if report.used.size != exceptions.size then return 1
  if !report.failures.isEmpty then return 1
  for substitution in report.substitutions.qsort (· < ·) do
    IO.println s!"audited csimp	{substitution}"
  IO.println s!"execution closure: {auditRoots.size} roots, {report.visited} declarations, {report.used.size} pinned Lean exceptions, {report.substitutions.size} proved csimps"
  return 0

end ExecutionClosure

namespace ExecutionSource

private def reservedAttr (stx : Syntax) : Option Name :=
  let attr := stx[1]
  let name := if attr.getKind == ``Parser.Attr.simple then attr[0].getId else .anonymous
  if [`implemented_by, `cpass, `init, `builtin_init].contains name then some name else none

private partial def reserved (stx : Syntax) : Option (Name × Syntax) :=
  if stx.getKind == ``Parser.Command.initialize then
    some (`initialize, stx)
  else if stx.getKind == ``Parser.Term.attrInstance then
    (reservedAttr stx).map (·, stx)
  else
    stx.getArgs.findSome? reserved

private def checkFile (env : Environment) (path : System.FilePath) : IO Bool := do
  let input := Parser.mkInputContext (← IO.FS.readFile path) path.toString
  let (_, initial, headerMessages) ← Parser.parseHeader input
  let mut state := initial
  let mut messages := headerMessages
  let mut rejected := false
  repeat
    let (command, next, log) := Parser.parseCommand input { env, options := {} } state messages
    state := next
    messages := log
    if let some (name, location) := reserved command then
      let pos := input.fileMap.toPosition (location.getPos?.getD 0)
      IO.eprintln s!"{path}:{pos.line}: reserved execution attribute or command {name}"
      rejected := true
    if Parser.isTerminalCommand command then break
  for message in messages.toList do
    if message.severity == .error then
      IO.eprintln (← message.toString)
      rejected := true
  return !rejected

unsafe def check (files : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  enableInitializersExecution
  let env ← importModules #[{module := `Lean}] {} (loadExts := true)
  let mut passed := true
  for file in files do
    let ok ← checkFile env file
    passed := passed && ok
  return if passed then 0 else 1

end ExecutionSource

unsafe def main (args : List String) : IO UInt32 :=
  match args with
  | "--imports" :: sourceRoot :: controls => ExecutionClosure.checkImports sourceRoot controls
  | "--sources" :: files => ExecutionSource.check files
  | "--compare" :: stockLib :: stockIR :: auditLib :: auditIR :: roots =>
    ExecutionClosure.run roots (some ⟨stockLib, stockIR, auditLib, auditIR⟩)
  | _ => ExecutionClosure.run args
