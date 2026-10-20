/-
  AArch64 instruction selection and assembly emission.
  Arithmetic mnemonic selection is adapted from QBE 1.3 arm64/emit.c; the ABI
  subset follows its arm64/abi.c. Zig 0.17.0's AIR -> target-code separation
  and width-specific registers are additional references. See docs/UPSTREAM.md
  and the retained upstream licenses in third_party/.
-/
import LeanCompilerBackend.Semantics

namespace LeanCompilerBackend.AArch64

inductive ALU where
  | add | sub | mul | and_ | orr | eor
  | lsl | lsr | asr
  deriving DecidableEq, Repr

def select (op : Binary) : ALU :=
  match op with
  | .add => .add
  | .sub => .sub
  | .mul => .mul
  | .andBits => .and_
  | .orBits => .orr
  | .xorBits => .eor
  | .shiftLeft => .lsl
  | .logicalRight => .lsr
  | .arithmeticRight => .asr

def mnemonic : ALU → String
  | .add => "add"
  | .sub => "sub"
  | .mul => "mul"
  | .and_ => "and"
  | .orr => "orr"
  | .eor => "eor"
  | .lsl => "lsl"
  | .lsr => "lsr"
  | .asr => "asr"

/-- An abstract target ALU specification; not a decoder for emitted bytes. -/
def evaluateALU (width : Width) (op : ALU) (a b : UInt64) : UInt64 :=
  Semantics.normalize width <| match op with
  | .add => a + b
  | .sub => a - b
  | .mul => a * b
  | .and_ => a &&& b
  | .orr => a ||| b
  | .eor => a ^^^ b
  | .lsl => a <<< (b &&& (width.bits - 1).toUInt64)
  | .lsr => a >>> (b &&& (width.bits - 1).toUInt64)
  | .asr => Semantics.constant width (Semantics.signedBits width.bits a / (2 ^ (b.toNat % width.bits) : Int))

/-- Only the primitive opcode-selection relation is proved here. Stack lowering,
    parsing, assembly rendering and assembler/linker behavior are separate gaps. -/
theorem select_preserves (width : Width) (op : Binary) (a b : UInt64) :
    evaluateALU width (select op) a b = Semantics.binary width op a b := by
  cases op <;> rfl

private def register (width : Width) (n : Nat) : String :=
  (if width == .word then "w" else "x") ++ toString n

private def floatRegister (width : Width) (n : Nat) : String :=
  (if width == .word then "s" else "d") ++ toString n

private def floatCondition : FloatComparison → String
  | .eq => "eq" | .ne => "ne" | .le => "ls" | .lt => "mi"
  | .ge => "ge" | .gt => "gt" | .ordered => "vc" | .unordered => "vs"

private def immediate (width : Width) (destination : Nat) (value : Int) : List String := Id.run do
  let bits := Semantics.constant width value
  let r := register width destination
  let mut result := [s!"\tmovz {r}, #{bits &&& 65535}"]
  for shift in [16:width.bits:16] do
    let chunk := (bits >>> shift.toUInt64) &&& 65535
    if chunk != 0 then result := result ++ [s!"\tmovk {r}, #{chunk}, lsl #{shift}"]
  return result

/-- Resolve a Darwin TLV descriptor while preserving live scalar argument/scratch
    registers. The baseline does not yet hoist/cache repeated TLS lookups. -/
private def threadAddress (width : Width) (destination : Nat) (name : String) : List String := Id.run do
  let mut lines := ["\tsub sp, sp, #256"]
  for i in [:9] do
    lines := lines ++ [s!"\tstp x{2*i}, x{2*i+1}, [sp, #{16*i}]"]
  lines := lines ++ ["\tstr x30, [sp, #144]"]
  for i in [:4] do
    lines := lines ++ [s!"\tstp d{2*i}, d{2*i+1}, [sp, #{160+16*i}]"]
  lines := lines ++ [s!"\tadrp x0, _{name}@TLVPPAGE", s!"\tldr x0, [x0, _{name}@TLVPPAGEOFF]",
    "\tldr x1, [x0]", "\tblr x1", "\tstr x0, [sp, #224]"]
  for i in [:9] do
    lines := lines ++ [s!"\tldp x{2*i}, x{2*i+1}, [sp, #{16*i}]"]
  lines := lines ++ ["\tldr x30, [sp, #144]"]
  for i in [:4] do
    lines := lines ++ [s!"\tldp d{2*i}, d{2*i+1}, [sp, #{160+16*i}]"]
  lines := lines ++ [s!"\tldr x{destination}, [sp, #224]", "\tadd sp, sp, #256"]
  if width == .word then lines := lines ++ [s!"\tmov w{destination}, w{destination}"]
  return lines

private def load (base : String) (slots : List (String × Nat)) (width : Width) (destination : Nat)
    (value : Operand) : Except String (List String) := do
  match value with
  | .constant n => return immediate width destination n
  | .threadSymbol name => pure (threadAddress width destination name)
  | .symbol name =>
    -- GOT references work for both module-local and externally linked symbols.
    let r := register .long destination
    return [s!"\tadrp {r}, _{name}@GOTPAGE", s!"\tldr {r}, [{r}, _{name}@GOTPAGEOFF]"]
      ++ (if width == .word then [s!"\tmov {register .word destination}, {register .word destination}"] else [])
  | .temporary name =>
    match slots.lookup name with
    | some offset => return [s!"\tldr {register width destination}, [{base}, #{offset}]"]
    | none => throw s!"missing stack slot for %{name}"

private def condition : Comparison → String
  | .eq => "eq" | .ne => "ne"
  | .signedLE => "le" | .signedLT => "lt" | .signedGE => "ge" | .signedGT => "gt"
  | .unsignedLE => "ls" | .unsignedLT => "lo" | .unsignedGE => "hs" | .unsignedGT => "hi"

private def unaryInstruction (width : Width) (op : Unary) : List String :=
  let r := register width 9
  match op with
  | .negate => [s!"\tneg {r}, {r}"]
  | .signedByte => [s!"\tsxtb {r}, w9"]
  | .unsignedByte => ["\tuxtb w9, w9"]
  | .signedHalf => [s!"\tsxth {r}, w9"]
  | .unsignedHalf => ["\tuxth w9, w9"]
  | .signedWord => ["\tsxtw x9, w9"]
  | .unsignedWord => [] -- the w9 load has already cleared x9's high bits

private def extendSubword (kind : Subword) (index : Nat) : String :=
  let instruction := match kind with
    | .signedByte => "sxtb" | .unsignedByte => "uxtb"
    | .signedHalf => "sxth" | .unsignedHalf => "uxth"
  s!"\t{instruction} w{index}, w{index}"

private def slotOffset (slots : List (String × Nat)) (name : String) : Except String Nat :=
  match slots.lookup name with
  | some offset => .ok offset
  | none => .error s!"missing stack slot for %{name}"

private def memoryLoad (width : Width) : LoadKind → String
  | .signedByte => s!"ldrsb {register width 9}"
  | .unsignedByte => "ldrb w9"
  | .signedHalf => s!"ldrsh {register width 9}"
  | .unsignedHalf => "ldrh w9"
  | .signedWord => if width == .long then "ldrsw x9" else "ldr w9"
  | .unsignedWord => "ldr w9"
  | .plain => s!"ldr {register width 9}"

/-- Apple ARM64 packs non-variadic stack scalars at their natural size/alignment.
    In particular consecutive words occupy four bytes each, not eight. This
    follows QBE 1.3 arm64/abi.c argsclass/selcall/selpar. -/
inductive ArgumentLocation where
  | register (index : Nat)
  | floatRegister (index : Nat)
  | stack (offset : Nat)
  deriving Repr, Inhabited

structure ArgumentLayout where
  locations : Array ArgumentLocation
  stackBytes : Nat
  stackUsedBytes : Nat

def argumentLayout (widths : Array Width) (variadicFrom : Nat := widths.size)
    (environment : Bool := false) (floating : Array Bool := #[]) (subwords : Array (Option Subword) := #[]) : ArgumentLayout := Id.run do
  let mut locations := #[]
  let mut offset := 0
  let mut gp := 0
  let mut fp := 0
  for i in [:widths.size] do
    if environment && i == 0 then locations := locations.push (.register 9)
    else if (floating[i]?).getD false && fp < 8 && i < variadicFrom then
      locations := locations.push (.floatRegister fp)
      fp := fp + 1
    else if !((floating[i]?).getD false) && gp < 8 && i < variadicFrom then
      locations := locations.push (.register gp)
      gp := gp + 1
    else
      let bytes := if i >= variadicFrom then 8 else (((subwords[i]?).getD none).map (·.bytes)).getD widths[i]!.bytes
      offset := alignUp offset bytes
      locations := locations.push (.stack offset)
      offset := offset + bytes
  return { locations, stackBytes := alignUp offset 16, stackUsedBytes := offset }

private def emitCall (base : String) (slots : List (String × Nat)) (target : CallTarget)
    (arguments : Array CallArgument) : Except String (List String) := do
  let mut lines := []
  let layout := argumentLayout (arguments.map (·.width)) ((arguments.findIdx? (·.variadic)).getD arguments.size) ((arguments[0]?).any (·.environment)) (arguments.map (·.floating)) (arguments.map (·.subword))
  let dynamicOutgoing := base == "x29" && layout.stackBytes != 0
  if dynamicOutgoing then lines := lines ++ [s!"\tsub sp, sp, #{layout.stackBytes}"]
  for i in [:arguments.size] do
    let argument := arguments[i]!
    if argument.environment then continue
    match layout.locations[i]! with
    | .floatRegister index =>
      lines := lines ++ (← load base slots argument.width 9 argument.value)
      lines := lines ++ [s!"\tfmov {floatRegister argument.width index}, {register argument.width 9}"]
    | .register index =>
      lines := lines ++ (← load base slots argument.width index argument.value)
      if let some kind := argument.subword then lines := lines ++ [extendSubword kind index]
    | .stack offset =>
      lines := lines ++ (← load base slots argument.width 9 argument.value)
      if let some kind := argument.subword then lines := lines ++ [extendSubword kind 9]
      let instruction := if !argument.variadic then match argument.subword with
        | some kind => if kind.bytes == 1 then "strb w9" else "strh w9"
        | none => s!"str {register argument.width 9}"
        else s!"str {register argument.width 9}"
      lines := lines ++ [s!"\t{instruction}, [sp, #{offset}]"]
  if let some argument := arguments[0]? then
    if argument.environment then lines := lines ++ (← load base slots .long 9 argument.value)
  let branch ← match target with
    | .direct name => pure [s!"\tbl _{name}"]
    | .indirect address =>
      -- Load the target after argument setup; x16 is reserved as call scratch.
      pure ((← load base slots .long 16 address) ++ ["\tblr x16"])
  let restore := if dynamicOutgoing then [s!"\tadd sp, sp, #{layout.stackBytes}"] else []
  pure (lines ++ branch ++ restore)

/-- Split frame adjustments into the two legal AArch64 immediate scales. -/
private def adjustStack (op : String) (bytes : Nat) : List String := Id.run do
  let mut lines := []
  if bytes / 4096 != 0 then
    lines := lines ++ [s!"\t{op} sp, sp, #{bytes / 4096}, lsl #12"]
  if bytes % 4096 != 0 then
    lines := lines ++ [s!"\t{op} sp, sp, #{bytes % 4096}"]
  return lines

private def stackAddress (base : String) (destination offset : Nat) : List String := Id.run do
  let r := register .long destination
  if offset < 4096 then return [s!"\tadd {r}, {base}, #{offset}"]
  let mut lines := [s!"\tadd {r}, {base}, #{offset / 4096}, lsl #12"]
  if offset % 4096 != 0 then
    lines := lines ++ [s!"\tadd {r}, {r}, #{offset % 4096}"]
  return lines

private def loadIncoming (width : Width) (offset : Nat) : List String :=
  if offset % width.bytes == 0 && offset / width.bytes < 4096 then
    [s!"\tldr {register width 9}, [sp, #{offset}]"]
  else stackAddress "sp" 10 offset ++ [s!"\tldr {register width 9}, [x10]"]

private def emitInstruction (base : String) (slots allocations : List (String × Nat)) (inst : Instruction)
    : Except String (List String) := do
  let mut lines : List String := []
  match inst.operation with
  | .convert op value =>
    lines := lines ++ (← load base slots op.inputWidth 9 value)
    let input := register op.inputWidth 9
    let output := register inst.width 9
    let source := floatRegister op.inputWidth 16
    let destination := floatRegister inst.width 17
    match op with
    | .extendSingle | .truncateDouble =>
      lines := lines ++ [s!"\tfmov {source}, {input}", s!"\tfcvt {destination}, {source}", s!"\tfmov {output}, {destination}"]
    | .toInteger _ signed =>
      let instruction := if signed then "fcvtzs" else "fcvtzu"
      lines := lines ++ [s!"\tfmov {source}, {input}", s!"\t{instruction} {output}, {source}"]
    | .fromInteger _ signed =>
      let instruction := if signed then "scvtf" else "ucvtf"
      lines := lines ++ [s!"\t{instruction} {destination}, {input}", s!"\tfmov {output}, {destination}"]
  | .floatBinary op a b =>
    lines := lines ++ (← load base slots inst.width 9 a) ++ (← load base slots inst.width 10 b)
    let f9 := floatRegister inst.width 16
    let f10 := floatRegister inst.width 17
    let instruction := match op with | .add => "fadd" | .sub => "fsub" | .mul => "fmul" | .div => "fdiv"
    lines := lines ++ [s!"\tfmov {f9}, {register inst.width 9}", s!"\tfmov {f10}, {register inst.width 10}",
      s!"\t{instruction} {f9}, {f9}, {f10}", s!"\tfmov {register inst.width 9}, {f9}"]
  | .floatNegate value =>
    lines := lines ++ (← load base slots inst.width 9 value)
    let r := register inst.width 9
    lines := lines ++ [s!"\teor {r}, {r}, #{2 ^ (inst.width.bits - 1)}"]
  | .floatCompare op width a b =>
    lines := lines ++ (← load base slots width 9 a) ++ (← load base slots width 10 b)
    let f9 := floatRegister width 16
    let f10 := floatRegister width 17
    lines := lines ++ [s!"\tfmov {f9}, {register width 9}", s!"\tfmov {f10}, {register width 10}",
      s!"\tfcmp {f9}, {f10}", s!"\tcset w9, {floatCondition op}"]
  | .cast value => lines := lines ++ (← load base slots inst.width 9 value)
  | .copy value => lines := lines ++ (← load base slots inst.width 9 value)
  | .binary op a b =>
    lines := lines ++ (← load base slots inst.width 9 a)
    lines := lines ++ (← load base slots (op.rhsWidth inst.width) 10 b)
    let r := register inst.width 9
    lines := lines ++ [s!"\t{mnemonic (select op)} {r}, {r}, {register inst.width 10}"]
  | .unary op value =>
    lines := lines ++ (← load base slots (op.inputWidth inst.width) 9 value)
    lines := lines ++ unaryInstruction inst.width op
  | .divide op a b =>
    lines := lines ++ (← load base slots inst.width 9 a)
    lines := lines ++ (← load base slots inst.width 10 b)
    let instruction := if op == .signedDiv || op == .signedRem then "sdiv" else "udiv"
    let r9 := register inst.width 9
    let r10 := register inst.width 10
    if op == .signedRem || op == .unsignedRem then
      let r11 := register inst.width 11
      lines := lines ++ [s!"\t{instruction} {r11}, {r9}, {r10}", s!"\tmsub {r9}, {r11}, {r10}, {r9}"]
    else lines := lines ++ [s!"\t{instruction} {r9}, {r9}, {r10}"]
  | .compare op width a b =>
    lines := lines ++ (← load base slots width 9 a)
    lines := lines ++ (← load base slots width 10 b)
    lines := lines ++ [s!"\tcmp {register width 9}, {register width 10}", s!"\tcset w9, {condition op}"]
  | .allocate _ size =>
    if base == "x29" then
      lines := lines ++ (← load base slots .long 9 size)
      lines := lines ++ ["\tadd x9, x9, #15", "\tand x9, x9, #-16",
        "\tsub sp, sp, x9", "\tmov x9, sp"]
    else
      let offset ← slotOffset allocations inst.destination
      lines := lines ++ stackAddress base 9 offset
  | .vaArg list =>
    lines := lines ++ (← load base slots .long 9 list)
    lines := lines ++ ["\tldr x10, [x9]", s!"\tldr {register inst.width 11}, [x10]",
      "\tadd x10, x10, #8", "\tstr x10, [x9]", s!"\tmov {register inst.width 9}, {register inst.width 11}"]
  | .load kind address =>
    lines := lines ++ (← load base slots .long 9 address)
    lines := lines ++ [s!"\t{memoryLoad inst.width kind}, [x9]"]
  | .call target arguments =>
    -- Sources are stable stack slots: argument-register permutations cannot
    -- overwrite an argument that has not yet been loaded. All other live values
    -- also survive caller-saved clobbers in their own frame slots.
    lines := lines ++ (← emitCall base slots target arguments)
    lines := lines ++ [if inst.floating then s!"\tfmov {register inst.width 9}, {floatRegister inst.width 0}"
      else s!"\tmov {register inst.width 9}, {register inst.width 0}"]
  let offset ← slotOffset slots inst.destination
  pure (lines ++ [s!"\tstr {register inst.width 9}, [{base}, #{offset}]"])

private def emitStatement (base : String) (slots allocations : List (String × Nat))
    (varargsOffset : Nat) (statement : Statement) : Except String (List String) := do
  match statement with
  | .assign inst => emitInstruction base slots allocations inst
  | .callVoid target arguments => emitCall base slots target arguments
  | .vaStart list =>
    pure ((← load base slots .long 9 list) ++ stackAddress base 10 varargsOffset ++ ["\tstr x10, [x9]"])
  | .blit source destination bytes =>
    if bytes == 0 then return []
    let mut lines := (← load base slots .long 9 source) ++ (← load base slots .long 10 destination)
    let mut offset := 0
    -- Unaligned ordinary integer accesses are supported by the initial target.
    -- Partial source/destination overlap is outside QBE's defined blit domain.
    for size in [8, 4, 2, 1] do
      for _ in [:((bytes - offset) / size)] do
        let (read, write) := match size with
          | 8 => ("ldr x11", "str x11")
          | 4 => ("ldr w11", "str w11")
          | 2 => ("ldrh w11", "strh w11")
          | _ => ("ldrb w11", "strb w11")
        lines := lines ++ [s!"\t{read}, [x9, #{offset}]", s!"\t{write}, [x10, #{offset}]"]
        offset := offset + size
    pure lines
  | .storeFloat width value address =>
    pure ((← load base slots .long 9 address) ++ (← load base slots width 10 value) ++
      [s!"\tstr {register width 10}, [x9]"])
  | .store width value address =>
    let addressLines ← load base slots .long 9 address
    let valueLines ← load base slots width.valueWidth 10 value
    let instruction := match width with
      | .byte => "strb w10" | .half => "strh w10"
      | .word => "str w10" | .long => "str x10"
    pure (addressLines ++ valueLines ++ [s!"\t{instruction}, [x9]"])

private def blockLabel (f : Function) (label : String) : String :=
  s!"L_lcb_block_{f.name.length}_{f.name}_{label}"

private def edgeLabel (f : Function) (label : String) : String :=
  s!"L_lcb_edge_{f.name.length}_{f.name}_{label}"

/-- Phi lowering stages every source before changing any destination slot. -/
private def emitEdge (base : String) (f : Function) (slots : List (String × Nat)) (stageBase : Nat)
    (predecessor target : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == target) | throw s!"unknown block @{target}"
  let mut lines := []
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_, value) := phi.incoming.find? (·.1 == predecessor)
      | throw s!"missing phi predecessor @{predecessor}"
    lines := lines ++ (← load base slots phi.width 9 value)
    lines := lines ++ [s!"\tstr {register phi.width 9}, [{base}, #{stageBase + i * 8}]"]
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let offset ← slotOffset slots phi.destination
    let r := register phi.width 9
    lines := lines ++ [s!"\tldr {r}, [{base}, #{stageBase + i * 8}]", s!"\tstr {r}, [{base}, #{offset}]"]
  pure lines

def emitFunction (f : Function) : Except String String := do
  validateFunction f
  let localNames := f.locals
  let dynamic := f.blocks.any fun block => block.instructions.any fun statement =>
    match statement with
    | .assign { operation := .allocate _ size, .. } =>
      block.label != f.blocks[0]!.label || match size with
        | .constant _ => false | _ => true
    | _ => false
  let base := if dynamic then "x29" else "sp"
  let mut outgoing := 0
  for block in f.blocks do
    for statement in block.instructions do
      if let some (_, arguments, _) := statement.callSite then
        outgoing := max outgoing (argumentLayout (arguments.map (·.width)) ((arguments.findIdx? (·.variadic)).getD arguments.size) ((arguments[0]?).any (·.environment)) (arguments.map (·.floating)) (arguments.map (·.subword))).stackBytes
  -- Dynamic functions reserve a canonical FP/LR record here and place outgoing
  -- arguments at each call's current SP, below any dynamic objects.
  if dynamic then outgoing := 16
  -- The outgoing argument area is below all locals, phi staging, saved LR and
  -- allocation objects. Calls can overwrite it without destroying live values.
  let slots := localNames.toList.zipIdx.map fun ((name, _), i) => (name, outgoing + i * 8)
  let maxPhis := f.blocks.foldl (fun n block => max n block.phis.size) 0
  let stageBase := outgoing + localNames.size * 8
  let mut frameEnd := outgoing + (localNames.size + maxPhis) * 8
  let hasCalls := f.blocks.any fun block => block.instructions.any (·.callSite.isSome)
  let returnAddress := frameEnd
  if hasCalls && !dynamic then frameEnd := frameEnd + 8
  let mut allocations : List (String × Nat) := []
  if !dynamic then
    for statement in f.blocks[0]!.instructions do
      if let .assign inst := statement then
        if let .allocate alignment (.constant size) := inst.operation then
          let offset := alignUp frameEnd alignment.bytes
          allocations := (inst.destination, offset) :: allocations
          frameEnd := offset + size.toNat
  let frame := alignUp frameEnd 16
  if frame > 1024 * 1024 then throw "stack frame exceeds the 1 MiB resource limit"
  let symbol := "_" ++ f.name
  let mut lines := [s!"; function {f.name}; target aarch64-macos; QBE integer SSA subset"]
  if f.exported then lines := lines ++ [s!".globl {symbol}"]
  lines := lines ++ [".p2align 2", s!"{symbol}:"]
  lines := lines ++ adjustStack "sub" frame
  if dynamic then
    lines := lines ++ ["\tstp x29, x30, [sp]", "\tmov x29, sp"]
  else if hasCalls then lines := lines ++ [s!"\tstr x30, [sp, #{returnAddress}]"]
  let incoming := argumentLayout (f.parameters.map (·.width)) f.parameters.size
    ((f.parameters[0]?).any (·.environment)) (f.parameters.map (·.floating)) (f.parameters.map (·.subword))
  if let some parameter := f.parameters[0]? then
    if parameter.environment then
      let offset ← slotOffset slots parameter.name
      lines := lines ++ [s!"\tstr x9, [{base}, #{offset}]"]
  for i in [:f.parameters.size] do
    let parameter := f.parameters[i]!
    if parameter.environment then continue
    let offset ← slotOffset slots parameter.name
    match incoming.locations[i]! with
    | .floatRegister index =>
      lines := lines ++ [s!"\tstr {floatRegister parameter.width index}, [{base}, #{offset}]"]
    | .register index =>
      lines := lines ++ [s!"\tstr {register parameter.width index}, [{base}, #{offset}]"]
    | .stack argumentOffset =>
      if let some kind := parameter.subword then
        let instruction := match kind with
          | .signedByte => "ldrsb w9" | .unsignedByte => "ldrb w9"
          | .signedHalf => "ldrsh w9" | .unsignedHalf => "ldrh w9"
        lines := lines ++ stackAddress "sp" 10 (frame + argumentOffset) ++ [s!"\t{instruction}, [x10]"]
      else lines := lines ++ loadIncoming parameter.width (frame + argumentOffset)
      lines := lines ++ [s!"\tstr {register parameter.width 9}, [{base}, #{offset}]"]
  for block in f.blocks do
    lines := lines ++ [blockLabel f block.label ++ ":"]
    for statement in block.instructions do
      lines := lines ++ (← emitStatement base slots allocations (frame + alignUp incoming.stackUsedBytes 8) statement)
    match block.terminator with
    | .ret value =>
      if let some value := value then
        let some width := f.resultWidth | throw "void function cannot return an integer"
        lines := lines ++ (← load base slots width 0 value)
        if let some kind := f.resultSubword then lines := lines ++ [extendSubword kind 0]
        if f.resultFloating then lines := lines ++ [s!"\tfmov {floatRegister width 0}, {register width 0}"]
      if dynamic then lines := lines ++ ["\tmov sp, x29", "\tldp x29, x30, [sp]"]
      else if hasCalls then lines := lines ++ [s!"\tldr x30, [sp, #{returnAddress}]"]
      lines := lines ++ adjustStack "add" frame
      lines := lines ++ ["\tret"]
    | .halt => lines := lines ++ ["\tbrk #0"]
    | .jump target =>
      lines := lines ++ (← emitEdge base f slots stageBase block.label target)
      lines := lines ++ [s!"\tb {blockLabel f target}"]
    | .branch condition yes no =>
      lines := lines ++ (← load base slots .word 9 condition)
      let otherwise := edgeLabel f block.label
      lines := lines ++ [s!"\tcbz w9, {otherwise}"]
      lines := lines ++ (← emitEdge base f slots stageBase block.label yes)
      lines := lines ++ [s!"\tb {blockLabel f yes}", otherwise ++ ":"]
      lines := lines ++ (← emitEdge base f slots stageBase block.label no)
      lines := lines ++ [s!"\tb {blockLabel f no}"]
  pure (String.intercalate "\n" (lines ++ [""]))

def emit (program : Program) : Except String String := do
  validate program
  let functions ← program.toList.mapM emitFunction
  return "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n"
    ++ String.intercalate "\n" functions
    ++ ".subsections_via_symbols\n"

private def emitData (data : DataDefinition) : String := Id.run do
  let mut lines := if data.threadLocal then [".section __DATA,__thread_vars,thread_local_variables", ".p2align 3"] else [".data"]
  if data.exported then lines := lines ++ [s!".globl _{data.name}"]
  let initialSymbol := if data.threadLocal then s!"_{data.name}$tlv$init" else s!"_{data.name}"
  if data.threadLocal then
    lines := lines ++ [s!"_{data.name}:", "\t.quad __tlv_bootstrap", "\t.quad 0", s!"\t.quad {initialSymbol}",
      ".section __DATA,__thread_data,thread_local_regular"]
  lines := lines ++ [s!".balign {data.alignment}", s!"{initialSymbol}:"]
  for item in data.items do
    match item with
    | .integer width value =>
      let directive := match width with
        | .byte => ".byte" | .half => ".short" | .word => ".long" | .long => ".quad"
      let bits := (BitVec.ofInt (width.bytes * 8) value).toNat
      lines := lines ++ [s!"\t{directive} {bits}"]
    | .zeroes bytes => lines := lines ++ [s!"\t.zero {bytes}"]
    | .byteString values =>
      -- Emit decoded bytes, avoiding assembler-specific string escape semantics.
      for start in [0:values.size:16] do
        let chunk := (values.extract start (start + 16)).toList.map (fun v => toString v.toNat)
        lines := lines ++ ["\t.byte " ++ String.intercalate ", " chunk]
    | .address name offset =>
      let suffix := if offset < 0 then toString offset else "+" ++ toString offset
      lines := lines ++ [s!"\t.quad _{name}{suffix}"]
  return String.intercalate "\n" (lines ++ [""])

def emitModule (module : Module) : Except String String := do
  validateModule module
  let functions ← module.functions.toList.mapM emitFunction
  return "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n"
    ++ String.intercalate "\n" functions
    ++ String.intercalate "\n" (module.data.toList.map emitData)
    ++ ".subsections_via_symbols\n"

end LeanCompilerBackend.AArch64
