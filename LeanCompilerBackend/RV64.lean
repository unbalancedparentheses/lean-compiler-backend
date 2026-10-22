/- Linux RV64 LP64D lowering; ABI reference: pinned QBE rv64/abi.c.
   Stable homes hold normalized SSA bit patterns; optional allocation uses
   callee-saved GP registers and reusable spill slots. -/
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.Allocation
import LeanCompilerBackend.Assembly
import LeanCompilerBackend.RV64ABI
import LeanCompilerBackend.Selection

namespace LeanCompilerBackend.RV64

open RV64ABI

private def align (n : Nat) : Nat := (n+15)/16*16
private def fs (w : Width) : String := if w == .word then "s" else "d"
private def norm (w : Width) (r : String) : List String :=
  if w == .word then [s!"\tslli {r}, {r}, 32", s!"\tsrli {r}, {r}, 32"] else []
private def memory (op r base : String) (offset : Int) : List String :=
  if -2048 ≤ offset && offset ≤ 2047 then [s!"\t{op} {r}, {offset}({base})"]
  else [s!"\tli t6, {offset}", s!"\tadd t6, {base}, t6", s!"\t{op} {r}, 0(t6)"]
private def address (r base : String) (offset : Int) : List String :=
  if -2048 ≤ offset && offset ≤ 2047 then [s!"\taddi {r}, {base}, {offset}"]
  else [s!"\tli t6, {offset}", s!"\tadd {r}, {base}, t6"]
private def toFloat (w : Width) (dst src : String) : List String :=
  [s!"\tfmv.{if w == .word then "w" else "d"}.x {dst}, {src}"]
private def fromFloat (w : Width) (dst src : String) : List String :=
  [s!"\tfmv.x.{if w == .word then "w" else "d"} {dst}, {src}"] ++ norm w dst

private def savedGP : Array String := #["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11"]

private structure Context where
  slots : List (String × Nat)
  registers : List (String × String)
  locals : List String
  stage : Nat
  vaOffset : Int
  wordFunctions : List String
  aliases : List (String × String)
  objects : List (String × Nat)
  types : Array Info
  resultPointer : Nat
private def slot (c : Context) (name : String) : Except String Int := do
  let some n := c.slots.lookup name | throw s!"missing RV64 slot %{name}"
  pure (-(n : Int))
private def store (c : Context) (name : String) : Except String (List String) := do
  if let some r := c.registers.lookup name then return [s!"\tmv {r}, t0"]
  return memory "sd" "t0" "s0" (← slot c name)
/-- General-dynamic TLS supports external definitions and shared libraries. -/
private def threadAddress (w : Width) (destination name : String) : List String := Id.run do
  let saved := #["ra", "t0", "t1", "t2", "t3", "t4", "t5", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7"]
  let mut lines := ["\taddi sp, sp, -304"]
  for i in [:saved.size] do lines := lines ++ memory "sd" saved[i]! "sp" (i*8)
  for i in [:12] do lines := lines ++ memory "fsd" s!"ft{i}" "sp" (120+i*8)
  for i in [:8] do lines := lines ++ memory "fsd" s!"fa{i}" "sp" (216+i*8)
  lines := lines ++ [s!"\tla.tls.gd a0, {name}", "\tcall __tls_get_addr@plt", "\tsd a0, 280(sp)"]
  for i in [:saved.size] do lines := lines ++ memory "ld" saved[i]! "sp" (i*8)
  for i in [:12] do lines := lines ++ memory "fld" s!"ft{i}" "sp" (120+i*8)
  for i in [:8] do lines := lines ++ memory "fld" s!"fa{i}" "sp" (216+i*8)
  return lines ++ [s!"\tld {destination}, 280(sp)", "\taddi sp, sp, 304"] ++ norm w destination
private def load (c : Context) (w : Width) (r : String) : Operand → Except String (List String)
  | .constant n => pure [s!"\tli {r}, {Semantics.constant w n}"]
  | .temporary name => do
    if let some home := c.registers.lookup name then return [s!"\tmv {r}, {home}"] ++ norm w r
    return memory (if w == Width.word then "lwu" else "ld") r "s0" (← slot c name)
  | .symbol name => pure ([s!"\t{if c.locals.contains name then "lla" else "la"} {r}, {name}"] ++ norm w r)
  | .threadSymbol name => pure (threadAddress w r name)
private def extend (w : Width) : Unary → List String
  | .negate => [s!"\tneg{if w == .word then "w" else ""} t0, t0"]
  | .signedByte => ["\tslli t0, t0, 56", "\tsrai t0, t0, 56"]
  | .unsignedByte => ["\tandi t0, t0, 255"]
  | .signedHalf => ["\tslli t0, t0, 48", "\tsrai t0, t0, 48"]
  | .unsignedHalf => ["\tslli t0, t0, 48", "\tsrli t0, t0, 48"]
  | .signedWord => ["\tsext.w t0, t0"]
  | .unsignedWord => norm .word "t0"
private def objectAddress (c : Context) (name r : String) : Except String (List String) := do
  let some offset := c.objects.lookup name | throw s!"missing RV64 object %{name}"
  pure (address r "s0" (-(offset : Int)))
/-- Exact fragments avoid reading beyond small objects at protected page edges. -/
private def readFragment (r : String) (offset bytes : Nat) : List String := Id.run do
  if bytes == 8 then return memory "ld" r "t2" offset
  if bytes == 4 then return memory "lwu" r "t2" offset
  let mut lines := [s!"\tli {r}, 0"]
  for i in [:bytes] do
    lines := lines ++ memory "lbu" "t1" "t2" (offset+i)
    if i != 0 then lines := lines ++ [s!"\tslli t1, t1, {i*8}"]
    lines := lines ++ [s!"\tor {r}, {r}, t1"]
  return lines
private def writeFragment (r : String) (offset bytes : Nat) : List String := Id.run do
  if bytes == 8 then return memory "sd" r "t2" offset
  if bytes == 4 then return memory "sw" r "t2" offset
  let mut lines := [s!"\tmv t1, {r}"]
  for i in [:bytes] do
    lines := lines ++ memory "sb" "t1" "t2" (offset+i)
    if i+1 < bytes then lines := lines ++ ["\tsrli t1, t1, 8"]
  return lines
private def copyBytes (bytes : Nat) : List String := Id.run do
  let mut lines := []
  for i in [:bytes/8] do lines := lines ++ memory "ld" "t0" "t2" (i*8) ++ memory "sd" "t0" "t3" (i*8)
  for i in [bytes/8*8:bytes] do lines := lines ++ memory "lbu" "t0" "t2" i ++ memory "sb" "t0" "t3" i
  return lines
private def putValue (w : Width) : Place → List String
  | .gp n => [s!"\t{if w == .word then "sext.w" else "mv"} a{n}, t0"]
  | .fp n => toFloat w s!"fa{n}" "t0"
  | .stack offset => memory "sd" "t0" "sp" offset
  | .environment => ["\tmv t5, t0"]
private def getValue (w : Width) : Place → List String
  | .gp n => [s!"\tmv t0, a{n}"]
  | .fp n => fromFloat w "t0" s!"fa{n}"
  | .stack offset => memory "ld" "t0" "s0" offset
  | .environment => ["\tmv t0, t5"]
private def returnChunks (info : Info) : Array Chunk := Id.run do
  let mut ngp := 0
  let mut nfp := 0
  let mut chunks := #[]
  for field in fields info 0 0 do
    let place := if field.floating then Place.fp nfp else .gp ngp
    if field.floating then nfp := nfp+1 else ngp := ngp+1
    chunks := chunks.push {field, place}
  return chunks
private def emitCall (c : Context) (target : CallTarget) (args : Array CallArgument) (result : Option (String × String) := none) : Except String (List String) := do
  let resultInfo ← result.mapM (fun (_,name) => RV64ABI.find c.types name)
  let p ← plan c.types args (resultInfo.any (·.indirect))
  let mut total := p.stackBytes
  let mut copies : Array Nat := #[]
  for a in args do
    total := align total
    copies := copies.push total
    if let some name := a.aggregate then
      let info ← RV64ABI.find c.types name
      if info.indirect then total := total+max 1 info.layout.size
  let bytes := align total
  let mut lines := address "sp" "sp" (-(bytes : Int))
  for i in [:args.size] do
    let a := args[i]!
    let arg := p.arguments[i]!
    if let some name := a.aggregate then
      let info ← RV64ABI.find c.types name
      lines := lines ++ (← load c .long "t2" a.value)
      if info.indirect then
        lines := lines ++ address "t3" "sp" copies[i]! ++ copyBytes info.layout.size ++ ["\tmv t0, t3"] ++ putValue .long arg.chunks[0]!.place
      else
        for chunk in arg.chunks do
          lines := lines ++ readFragment "t0" chunk.field.offset chunk.field.bytes ++ putValue chunk.field.width chunk.place
    else
      lines := lines ++ (← load c a.width "t0" a.value)
      if let some k := a.subword then lines := lines ++ extend .word k.extension
      lines := lines ++ putValue a.width arg.chunks[0]!.place
  if let some (name,_) := result then
    if resultInfo.any (·.indirect) then lines := lines ++ (← objectAddress c name "a0")
  match target with
  | .direct name => lines := lines ++ [s!"\tcall {name}"]
  | .indirect value => lines := lines ++ (← load c .long "t4" value) ++ ["\tjalr t4"]
  lines := lines ++ address "sp" "sp" bytes
  if let some (name,_) := result then
    let some info := resultInfo | throw "missing RV64 return classification"
    lines := lines ++ (← objectAddress c name "t2")
    if !info.indirect then
      for chunk in returnChunks info do
        lines := lines ++ getValue chunk.field.width chunk.place ++ writeFragment "t0" chunk.field.offset chunk.field.bytes
    lines := lines ++ ["\tmv a0, t2"]
  pure lines

private def signedComparison (op : Comparison) : Bool :=
  match op with | .signedLE | .signedLT | .signedGE | .signedGT => true | _ => false

private def comparisonOperands (c : Context) (op : Comparison) (w : Width) (x y : Operand)
    : Except String (List String) := do
  let lines := (← load c w "t0" x) ++ (← load c w "t1" y)
  pure (lines ++ if signedComparison op && w == .word then ["\tsext.w t0, t0", "\tsext.w t1, t1"] else [])

private def inverseComparisonBranch (op : Comparison) (destination : String) : String :=
  let (mnemonic, x, y) := match op with
    | .eq => ("bne", "t0", "t1") | .ne => ("beq", "t0", "t1")
    | .signedLT => ("bge", "t0", "t1") | .signedGE => ("blt", "t0", "t1")
    | .signedLE => ("blt", "t1", "t0") | .signedGT => ("bge", "t1", "t0")
    | .unsignedLT => ("bgeu", "t0", "t1") | .unsignedGE => ("bltu", "t0", "t1")
    | .unsignedLE => ("bltu", "t1", "t0") | .unsignedGT => ("bgeu", "t1", "t0")
  s!"\t{mnemonic} {x}, {y}, {destination}"

private def emitInstruction (c : Context) (inst : Instruction) : Except String (List String) := do
  let w := inst.width
  let ws := if w == .word then "w" else ""
  let mut lines := []
  match inst.operation with
  | .copy x | .cast x => lines := ← load c w "t0" x
  | .unary op x => lines := (← load c (op.inputWidth w) "t0" x) ++ extend w op
  | .binary op x y =>
    lines := (← load c w "t0" x) ++ (← load c (op.rhsWidth w) "t1" y)
    let mnemonic := match op with
      | .add => "add"++ws | .sub => "sub"++ws | .mul => "mul"++ws
      | .andBits => "and" | .orBits => "or" | .xorBits => "xor"
      | .shiftLeft => "sll"++ws | .logicalRight => "srl"++ws | .arithmeticRight => "sra"++ws
    lines := lines ++ [s!"\t{mnemonic} t0, t0, t1"]
  | .divide op x y =>
    lines := (← load c w "t0" x) ++ (← load c w "t1" y)
    let mnemonic := match op with | .signedDiv => "div" | .unsignedDiv => "divu" | .signedRem => "rem" | .unsignedRem => "remu"
    lines := lines ++ [s!"\t{mnemonic}{ws} t0, t0, t1"]
  | .compare op ow x y =>
    lines := ← comparisonOperands c op ow x y
    let cmp := if signedComparison op then "slt" else "sltu"
    lines := lines ++ (match op with
      | .eq => ["\txor t0, t0, t1", "\tseqz t0, t0"]
      | .ne => ["\txor t0, t0, t1", "\tsnez t0, t0"]
      | .signedLT | .unsignedLT => [s!"\t{cmp} t0, t0, t1"]
      | .signedGT | .unsignedGT => [s!"\t{cmp} t0, t1, t0"]
      | .signedLE | .unsignedLE => [s!"\t{cmp} t0, t1, t0", "\txori t0, t0, 1"]
      | .signedGE | .unsignedGE => [s!"\t{cmp} t0, t0, t1", "\txori t0, t0, 1"])
  | .floatBinary op x y =>
    lines := (← load c w "t0" x) ++ toFloat w "ft0" "t0" ++ (← load c w "t0" y) ++ toFloat w "ft1" "t0"
    let op := match op with | .add => "fadd" | .sub => "fsub" | .mul => "fmul" | .div => "fdiv"
    lines := lines ++ [s!"\t{op}.{fs w} ft0, ft0, ft1"] ++ fromFloat w "t0" "ft0"
  | .floatNegate x =>
    lines := (← load c w "t0" x) ++ toFloat w "ft0" "t0" ++ [s!"\tfneg.{fs w} ft0, ft0"] ++ fromFloat w "t0" "ft0"
  | .floatCompare op ow x y =>
    lines := (← load c ow "t0" x) ++ toFloat ow "ft0" "t0" ++ (← load c ow "t0" y) ++ toFloat ow "ft1" "t0"
    let s := fs ow
    lines := lines ++ (match op with
      | .eq => [s!"\tfeq.{s} t0, ft0, ft1"]
      | .ne => [s!"\tfeq.{s} t0, ft0, ft1", "\txori t0, t0, 1"]
      | .lt => [s!"\tflt.{s} t0, ft0, ft1"] | .le => [s!"\tfle.{s} t0, ft0, ft1"]
      | .gt => [s!"\tflt.{s} t0, ft1, ft0"] | .ge => [s!"\tfle.{s} t0, ft1, ft0"]
      | .ordered | .unordered => [s!"\tfeq.{s} t0, ft0, ft0", s!"\tfeq.{s} t1, ft1, ft1", "\tand t0, t0, t1"] ++
        if op == .unordered then ["\txori t0, t0, 1"] else [])
  | .convert op x =>
    let input := op.inputWidth
    lines := ← load c input "t0" x
    if op.inputFloating then lines := lines ++ toFloat input "ft0" "t0"
    match op with
    | .extendSingle => lines := lines ++ ["\tfcvt.d.s ft0, ft0"]
    | .truncateDouble => lines := lines ++ ["\tfcvt.s.d ft0, ft0, rne"]
    | .toInteger _ signed => lines := lines ++ [s!"\tfcvt.{if w == .word then "w" else "l"}{if signed then "" else "u"}.{fs input} t0, ft0, rtz"]
    | .fromInteger _ signed => lines := lines ++ [s!"\tfcvt.{fs w}.{if input == .word then "w" else "l"}{if signed then "" else "u"} ft0, t0{if w == Width.long && input == Width.word then "" else ", rne"}"]
    if op.resultFloating then lines := lines ++ fromFloat w "t0" "ft0"
  | .allocate _ size => lines := (← load c .long "t0" size) ++ ["\taddi t0, t0, 15", "\tandi t0, t0, -16", "\tsub sp, sp, t0", "\tmv t0, sp"]
  | .load kind a =>
    lines := ← load c .long "t0" a
    let op := match kind with
      | .signedByte => "lb" | .unsignedByte => "lbu" | .signedHalf => "lh" | .unsignedHalf => "lhu"
      | .signedWord => "lw" | .unsignedWord => "lwu" | .plain => if w == Width.word then "lwu" else "ld"
    lines := lines ++ [s!"\t{op} t0, 0(t0)"]
  | .call target args =>
    lines := ← emitCall c target args (inst.callAggregate.map (inst.destination, ·))
    if inst.floating then lines := lines ++ fromFloat w "t0" "fa0"
    else
      lines := lines ++ ["\tmv t0, a0"]
      let known := match target with
        | .direct name => some name
        | .indirect (.symbol name) => some name
        | .indirect (.temporary name) => c.aliases.lookup name
        | _ => none
      if known.any (c.wordFunctions.contains ·) then lines := lines ++ norm .word "t0"
    if let some k := inst.callSubword then lines := lines ++ extend .word k.extension
  | .vaArg list =>
    lines := (← load c .long "t0" list) ++ ["\tld t1, 0(t0)", "\taddi t2, t1, 8", "\tsd t2, 0(t0)", s!"\t{if w == Width.word then "lwu" else "ld"} t0, 0(t1)"]
  pure (lines ++ norm w "t0" ++ (← store c inst.destination))

private def emitStatement (c : Context) : Statement → Except String (List String)
  | .assign i => emitInstruction c i
  | .callVoid t args => emitCall c t args
  | .storeFloat w value ptr => do
    return (← load c .long "t1" ptr) ++ (← load c w "t0" value) ++ [s!"\t{if w == .word then "sw" else "sd"} t0, 0(t1)"]
  | .store w value ptr => do
    let op := match w with | .byte => "sb" | .half => "sh" | .word => "sw" | .long => "sd"
    return (← load c .long "t1" ptr) ++ (← load c w.valueWidth "t0" value) ++ [s!"\t{op} t0, 0(t1)"]
  | .blit src dst bytes => do
    if bytes == 0 then return []
    let mut lines := (← load c .long "t2" src) ++ (← load c .long "t3" dst)
    let remaining := if bytes > 128 then bytes % 8 else bytes
    if bytes > 128 then
      lines := lines ++ [s!"\tli t1, {bytes/8}", "1:", "\tld t0, 0(t2)", "\tsd t0, 0(t3)",
        "\taddi t2, t2, 8", "\taddi t3, t3, 8", "\taddi t1, t1, -1", "\tbnez t1, 1b"]
    for i in [:remaining/8] do lines := lines ++ memory "ld" "t0" "t2" (i*8) ++ memory "sd" "t0" "t3" (i*8)
    for i in [remaining/8*8:remaining] do lines := lines ++ memory "lbu" "t0" "t2" i ++ memory "sb" "t0" "t3" i
    pure lines
  | .vaStart list => do
    return (← load c .long "t0" list) ++ address "t1" "s0" c.vaOffset ++ ["\tsd t1, 0(t0)"]

/-- Fuse only an adjacent long address definition with its sole SSA use.
    The original allocation remains valid: no instruction between the base use
    and memory access can replace its home. RV64 offsets are unscaled signed12. -/
private def adjacentMemory (c : Context) (uses : Std.HashMap String Nat)
    (first second : Statement) : Except String (Option (List String)) := do
  let .assign address := first | return none
  if address.width != .long || address.floating || uses[address.destination]? != some 1 then return none
  let pair := match address.operation with
    | .binary .add pointer (.constant n) | .binary .add (.constant n) pointer => some (pointer, n)
    | .binary .sub pointer (.constant n) => some (pointer, -n)
    | _ => none
  let some (pointer, rawOffset) := pair | return none
  let access := match second with
    | .assign {operation := .load _ (.temporary name), ..} => some name
    | .store _ _ (.temporary name) | .storeFloat _ _ (.temporary name) => some name
    | _ => none
  if access != some address.destination then return none
  let offset := Semantics.signedBits 64 (Semantics.constant .long rawOffset)
  if offset < -2048 || offset > 2047 then return none
  match second with
  | .assign inst =>
    let .load kind _ := inst.operation | return none
    let op := match kind with
      | .signedByte => "lb" | .unsignedByte => "lbu" | .signedHalf => "lh" | .unsignedHalf => "lhu"
      | .signedWord => "lw" | .unsignedWord => "lwu" | .plain => if inst.width == .word then "lwu" else "ld"
    let lines ← load c .long "t0" pointer
    -- Keep word normalization, including signed loads and floating raw bits.
    return some (lines ++ memory op "t0" "t0" offset ++ norm inst.width "t0" ++ (← store c inst.destination))
  | .store width value _ =>
    let op := match width with | .byte => "sb" | .half => "sh" | .word => "sw" | .long => "sd"
    -- Value materialization may use t6 for large spill offsets or resolve TLS;
    -- neither destroys the base in t1. Allocated homes are all callee-saved.
    return some ((← load c .long "t1" pointer) ++ (← load c width.valueWidth "t0" value) ++
      memory op "t0" "t1" offset)
  | .storeFloat width value _ =>
    return some ((← load c .long "t1" pointer) ++ (← load c width "t0" value) ++
      memory (if width == .word then "sw" else "sd") "t0" "t1" offset)
  | _ => return none

private def label (f : Function) (name : String) : String := s!".L_lcb_{f.name.length}_{Assembly.localName f.name}_{name}"
private def edge (c : Context) (f : Function) (src dst : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == dst) | throw "missing RV64 edge"
  let mut lines := []
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_,v) := phi.incoming.find? (·.1 == src) | throw "missing RV64 phi incoming"
    lines := lines ++ (← load c phi.width "t0" v) ++ memory "sd" "t0" "s0" (-((c.stage+i*8) : Int))
  for i in [:block.phis.size] do
    lines := lines ++ memory "ld" "t0" "s0" (-((c.stage+i*8) : Int)) ++ (← store c block.phis[i]!.destination)
  pure lines

private def emitFunction (f : Function) (types : Array Info) (locals words : List String) (fileId : Nat) (allocate : Bool) : Except String String := do
  validateFunction f true
  Assembly.checkTargetSection false f.customSection
  let resultInfo ← f.resultAggregate.mapM (RV64ABI.find types)
  let params := f.parameters.map fun p => {width := p.width, value := Operand.temporary p.name, floating := p.floating, subword := p.subword, environment := p.environment, aggregate := p.aggregate : CallArgument}
  let incoming ← plan types params (resultInfo.any (·.indirect))
  let header := if f.variadic then 80 else 16
  let homes ← if allocate then Allocation.allocate f savedGP.size else pure (Allocation.baseline f)
  let maxPhi := f.blocks.foldl (fun n b => max n b.phis.size) 0
  let mut fixed := header+(homes.spills+maxPhi)*8
  let savedBase := fixed+8
  fixed := fixed+homes.registers*8
  let resultPointer := fixed+8
  if resultInfo.any (·.indirect) then fixed := fixed+8
  let mut objects := []
  let aggregateObjects := f.parameters.filterMap (fun p => p.aggregate.map (p.name, ·)) ++
    f.blocks.foldl (fun result b => result ++ b.instructions.filterMap (fun statement =>
      match statement with | .assign inst => inst.callAggregate.map (inst.destination, ·) | _ => none)) #[]
  for (name,typeName) in aggregateObjects do
    let info ← RV64ABI.find types typeName
    let alignment := max 8 info.layout.alignment
    fixed := (fixed+max info.layout.size 1+alignment-1)/alignment*alignment
    objects := (name,fixed) :: objects
  let frame := align fixed
  if frame > 1024*1024 then throw "RV64 frame exceeds 1 MiB"
  let aliases := f.blocks.toList.flatMap fun b => b.instructions.toList.filterMap fun s =>
    match s with | .assign {destination, operation := .copy (.symbol name), ..} => some (destination,name) | _ => none
  let c : Context := {slots := homes.homes.filterMap (fun (n,i) => if i >= homes.registerCount then some (n,header+(i-homes.registerCount+1)*8) else none), registers := homes.homes.filterMap (fun (n,i) => if i < homes.registerCount then some (n,savedGP[i]!) else none), locals, stage := header+(homes.spills+1)*8, vaOffset := if incoming.stackBytes > 0 then incoming.stackBytes else (incoming.ngp*8 : Int)-64, wordFunctions := words, aliases, objects, types, resultPointer}
  let mut lines := [f.customSection.map (Assembly.sectionDirective false) |>.getD ".text", s!".type {f.name}, @function", ".p2align 2"]
  if f.exported then lines := lines ++ [s!".globl {f.name}"]
  lines := lines ++ [s!"{f.name}:", "\tmv t0, sp"] ++ address "sp" "sp" (-(frame : Int)) ++
    memory "sd" "ra" "t0" (-((header-8) : Int)) ++ memory "sd" "s0" "t0" (-(header : Int)) ++ ["\tmv s0, t0"]
  for i in [:homes.registers] do lines := lines ++ memory "sd" savedGP[i]! "s0" (-((savedBase+i*8) : Int))
  if resultInfo.any (·.indirect) then lines := lines ++ memory "sd" "a0" "s0" (-(resultPointer : Int))
  if f.variadic then
    for i in [:8] do lines := lines ++ memory "sd" s!"a{i}" "s0" ((i*8 : Int)-64)
  for i in [:f.parameters.size] do
    let p := f.parameters[i]!
    let arg := incoming.arguments[i]!
    if let some name := p.aggregate then
      let info ← RV64ABI.find types name
      if info.indirect then
        lines := lines ++ getValue .long arg.chunks[0]!.place ++ ["\tmv t2, t0"] ++ (← objectAddress c p.name "t3") ++ copyBytes info.layout.size
      else
        lines := lines ++ (← objectAddress c p.name "t2")
        for chunk in arg.chunks do
          lines := lines ++ getValue chunk.field.width chunk.place ++ writeFragment "t0" chunk.field.offset chunk.field.bytes
      lines := lines ++ (← objectAddress c p.name "t0") ++ (← store c p.name)
      continue
    lines := lines ++ getValue p.width arg.chunks[0]!.place
    if let some k := p.subword then lines := lines ++ extend .word k.extension
    lines := lines ++ norm p.width "t0" ++ (← store c p.name)
  let uses := if allocate then Selection.useCounts f else {}
  for b in f.blocks do
    let branchCompare := if allocate then Selection.branchComparison uses b else none
    lines := lines ++ [label f b.label ++ ":"]
    let mut debugIndex := 0
    let mut pendingMemory : Option (List String) := none
    for i in [:b.instructions.size+1] do
      for _ in [:b.debugLocations.size] do
        if let some loc := b.debugLocations[debugIndex]? then
          if loc.instruction != i then break
          lines := lines ++ [s!"\t.loc {fileId} {loc.line} {loc.column}"]
          debugIndex := debugIndex+1
        else break
      if let some inst := b.instructions[i]? then
        if let some selected := pendingMemory then
          -- Emit the fused access after the memory statement's debug location.
          lines := lines ++ selected
          pendingMemory := none
        else
          if allocate then
            if let some next := b.instructions[i+1]? then
              pendingMemory ← adjacentMemory c uses inst next
          if pendingMemory.isNone then
            if let some (op, width, x, y) := branchCompare then
              if i+1 == b.instructions.size then lines := lines ++ (← comparisonOperands c op width x y)
              else lines := lines ++ (← emitStatement c inst)
            else lines := lines ++ (← emitStatement c inst)
    match b.terminator with
    | .ret value =>
      if let some v := value then
        let some w := f.resultWidth | throw "missing RV64 return type"
        if let some info := resultInfo then
          lines := lines ++ (← load c .long "t2" v)
          if info.indirect then
            lines := lines ++ memory "ld" "t3" "s0" (-(resultPointer : Int)) ++ copyBytes info.layout.size ++ ["\tmv a0, t3"]
          else
            for chunk in returnChunks info do
              lines := lines ++ readFragment "t0" chunk.field.offset chunk.field.bytes ++ putValue chunk.field.width chunk.place
        else
          lines := lines ++ (← load c w "t0" v)
          if let some k := f.resultSubword then lines := lines ++ extend .word k.extension
          if f.resultFloating then lines := lines ++ toFloat w "fa0" "t0"
          else lines := lines ++ [s!"\t{if w == .word then "sext.w" else "mv"} a0, t0"]
      for i in [:homes.registers] do lines := lines ++ memory "ld" savedGP[i]! "s0" (-((savedBase+i*8) : Int))
      lines := lines ++ memory "ld" "ra" "s0" (-((header-8) : Int)) ++ memory "ld" "t0" "s0" (-(header : Int)) ++ ["\tmv sp, s0", "\tmv s0, t0", "\tret"]
    | .halt => lines := lines ++ ["\tunimp"]
    | .jump dst => lines := lines ++ (← edge c f b.label dst) ++ [s!"\tj {label f dst}"]
    | .branch v yes no =>
      let other := s!".L_lcb_edge_{f.name.length}_{Assembly.localName f.name}_{b.label}"
      if let some (op, _, _, _) := branchCompare then
        lines := lines ++ [inverseComparisonBranch op other]
      else
        lines := lines ++ (← load c .word "t0" v) ++ [s!"\tbeqz t0, {other}"]
      lines := lines ++ (← edge c f b.label yes) ++
        [s!"\tj {label f yes}", other ++ ":"] ++ (← edge c f b.label no) ++ [s!"\tj {label f no}"]
  lines := lines ++ [s!".size {f.name}, .-{f.name}"]
  if let some name := f.debugFile then lines := [s!".file {fileId} {Assembly.debugFilename name}"] ++ lines
  pure (String.intercalate "\n" lines ++ "\n")

def emitModule (m : Module) (allocate : Bool := false) : Except String String := do
  validateModule m
  for d in m.data do Assembly.checkTargetSection false d.customSection
  let types ← RV64ABI.classify m.types
  let locals := (m.functions.filter (!·.exported)).toList.map (·.name) ++ (m.data.filter (fun d => !d.exported && !d.common)).toList.map (·.name)
  let words := (m.functions.filter (fun f => f.resultWidth == some .word && !f.resultFloating)).toList.map (·.name)
  let mut output := "# Generated by Lean Compiler Backend; Linux RV64 LP64D\n.option pic\n"
  let mut fileId := 1
  for f in m.functions do
    output := output ++ (← emitFunction f types locals words fileId allocate)
    if f.debugFile.isSome then fileId := fileId+1
  for d in m.data do output := output ++ Assembly.emitData false d
  pure (output ++ ".section .note.GNU-stack,\"\",@progbits\n")

end LeanCompilerBackend.RV64
