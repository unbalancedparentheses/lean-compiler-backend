/-
  AArch64 instruction selection and assembly emission.
  Arithmetic mnemonic selection is adapted from QBE 1.3 arm64/emit.c; the ABI
  subset follows its arm64/abi.c. Zig 0.17.0's AIR -> target-code separation
  and width-specific registers are additional references. See docs/UPSTREAM.md
  and the retained upstream licenses in third_party/.
-/
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.AggregateABI

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

/-- Resolve Darwin TLV or Linux TLSDESC while preserving live scalar argument/scratch
    registers. The baseline does not yet hoist/cache repeated TLS lookups. -/
private def threadAddress (darwin : Bool) (width : Width) (destination : Nat) (name : String) : List String := Id.run do
  let mut lines := ["\tsub sp, sp, #256"]
  for i in [:9] do
    lines := lines ++ [s!"\tstp x{2*i}, x{2*i+1}, [sp, #{16*i}]"]
  lines := lines ++ ["\tstr x30, [sp, #144]"]
  for i in [:4] do
    lines := lines ++ [s!"\tstp d{2*i}, d{2*i+1}, [sp, #{160+16*i}]"]
  if darwin then
    lines := lines ++ [s!"\tadrp x0, _{name}@TLVPPAGE", s!"\tldr x0, [x0, _{name}@TLVPPAGEOFF]",
      "\tldr x1, [x0]", "\tblr x1"]
  else
    lines := lines ++ [s!"\tadrp x0, :tlsdesc:{name}", s!"\tldr x1, [x0, :tlsdesc_lo12:{name}]",
      s!"\tadd x0, x0, :tlsdesc_lo12:{name}", s!"\t.tlsdesccall {name}", "\tblr x1",
      "\tmrs x1, tpidr_el0", "\tadd x0, x1, x0"]
  lines := lines ++ ["\tstr x0, [sp, #224]"]
  for i in [:9] do
    lines := lines ++ [s!"\tldp x{2*i}, x{2*i+1}, [sp, #{16*i}]"]
  lines := lines ++ ["\tldr x30, [sp, #144]"]
  for i in [:4] do
    lines := lines ++ [s!"\tldp d{2*i}, d{2*i+1}, [sp, #{160+16*i}]"]
  lines := lines ++ [s!"\tldr x{destination}, [sp, #224]", "\tadd sp, sp, #256"]
  if width == .word then lines := lines ++ [s!"\tmov w{destination}, w{destination}"]
  return lines

private def stackAddress (base : String) (destination offset : Nat) : List String := Id.run do
  let r := register .long destination
  if offset < 4096 then return [s!"\tadd {r}, {base}, #{offset}"]
  let mut lines := [s!"\tadd {r}, {base}, #{offset / 4096}, lsl #12"]
  if offset % 4096 != 0 then
    lines := lines ++ [s!"\tadd {r}, {r}, #{offset % 4096}"]
  return lines

/-- x15 is reserved for large frame-slot addresses, never an ABI argument. -/
private def slotAccess (instruction base register : String) (bytes offset : Nat) : List String :=
  if offset % bytes == 0 && offset / bytes < 4096 then
    [s!"\t{instruction} {register}, [{base}, #{offset}]"]
  else stackAddress base 15 offset ++ [s!"\t{instruction} {register}, [x15]"]

private def symbolName (darwin : Bool) (name : String) : String :=
  (if darwin then "_" else "") ++ name

private def load (darwin : Bool) (localSymbols : List String) (base : String) (slots : List (String × Nat)) (width : Width) (destination : Nat)
    (value : Operand) : Except String (List String) := do
  match value with
  | .constant n => return immediate width destination n
  | .threadSymbol name => pure (threadAddress darwin width destination name)
  | .symbol name =>
    -- GOT references work for both module-local and externally linked symbols.
    let r := register .long destination
    return (if darwin then [s!"\tadrp {r}, _{name}@GOTPAGE", s!"\tldr {r}, [{r}, _{name}@GOTPAGEOFF]"]
      else if localSymbols.contains name then [s!"\tadrp {r}, {name}", s!"\tadd {r}, {r}, :lo12:{name}"]
      else [s!"\tadrp {r}, :got:{name}", s!"\tldr {r}, [{r}, :got_lo12:{name}]"])
      ++ (if width == .word then [s!"\tmov {register .word destination}, {register .word destination}"] else [])
  | .temporary name =>
    match slots.lookup name with
    | some offset => return slotAccess "ldr" base (register width destination) width.bytes offset
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

/-- Split frame adjustments into the two legal AArch64 immediate scales. -/
private def adjustStack (op : String) (bytes : Nat) : List String := Id.run do
  let mut lines := []
  if bytes / 4096 != 0 then
    lines := lines ++ [s!"\t{op} sp, sp, #{bytes / 4096}, lsl #12"]
  if bytes % 4096 != 0 then
    lines := lines ++ [s!"\t{op} sp, sp, #{bytes % 4096}"]
  return lines

/-- Exact object fragments avoid QBE's known possible tail overread. x12 is the
    object pointer; x13 is scratch. Padding inside the object may be transferred. -/
private def readFragment (destination offset bytes : Nat) : List String := Id.run do
  if bytes == 8 then return [s!"\tldr x{destination}, [x12, #{offset}]"]
  if bytes == 4 then return [s!"\tldr w{destination}, [x12, #{offset}]"]
  let mut lines := [s!"\tmov x{destination}, #0"]
  for i in [:bytes] do
    lines := lines ++ [s!"\tldrb w13, [x12, #{offset+i}]",
      s!"\torr x{destination}, x{destination}, x13, lsl #{8*i}"]
  return lines

private def writeFragment (source offset bytes : Nat) : List String := Id.run do
  if bytes == 8 then return [s!"\tstr x{source}, [x12, #{offset}]"]
  if bytes == 4 then return [s!"\tstr w{source}, [x12, #{offset}]"]
  let mut lines := [s!"\tmov x13, x{source}"]
  for i in [:bytes] do
    lines := lines ++ [s!"\tstrb w13, [x12, #{offset+i}]"]
    if i + 1 < bytes then lines := lines ++ ["\tlsr x13, x13, #8"]
  return lines

/-- Copy exact bytes from x12 to x13, using x14 only. -/
private def copyAggregate (bytes : Nat) : List String := Id.run do
  let mut lines := []
  let mut offset := 0
  for size in [8, 4, 2, 1] do
    for _ in [:((bytes - offset) / size)] do
      let (read, write) := match size with
        | 8 => ("ldr x14", "str x14") | 4 => ("ldr w14", "str w14")
        | 2 => ("ldrh w14", "strh w14") | _ => ("ldrb w14", "strb w14")
      lines := lines ++ [s!"\t{read}, [x12, #{offset}]", s!"\t{write}, [x13, #{offset}]"]
      offset := offset + size
  return lines

private def parametersAsArguments (f : Function) : Array CallArgument :=
  f.parameters.map fun p =>
    { width := p.width, value := .temporary p.name,
      floating := p.floating, subword := p.subword, aggregate := p.aggregate, environment := p.environment }

private def emitCall (darwin : Bool) (localSymbols : List String) (types : Array AggregateABI.TypeInfo) (base : String)
    (slots allocations : List (String × Nat)) (target : CallTarget)
    (arguments : Array CallArgument) (result : Option (String × String) := none)
    : Except String (List String) := do
  let mut lines := []
  let plan ← AggregateABI.plan types arguments darwin
  let dynamicOutgoing := base == "x29" && plan.totalBytes != 0
  if dynamicOutgoing then lines := lines ++ adjustStack "sub" plan.totalBytes
  -- Copy indirect arguments before filling live argument registers.
  for i in [:arguments.size] do
    if let some offset := plan.arguments[i]!.copyOffset then
      let some info := plan.arguments[i]!.aggregate | throw "missing indirect aggregate type"
      lines := lines ++ (← load darwin localSymbols base slots .long 12 arguments[i]!.value)
        ++ stackAddress "sp" 13 offset ++ copyAggregate info.layout.size
  for i in [:arguments.size] do
    let argument := arguments[i]!
    if argument.environment then continue
    let entry := plan.arguments[i]!
    if let some info := entry.aggregate then
      if info.passing == .indirect then
        let some offset := entry.copyOffset | throw "missing indirect aggregate copy"
        match entry.location with
        | .general first _ => lines := lines ++ stackAddress "sp" first offset
        | .stack dest => lines := lines ++ stackAddress "sp" 12 offset ++ [s!"\tstr x12, [sp, #{dest}]"]
        | _ => throw "indirect aggregate in floating register"
      else
        lines := lines ++ (← load darwin localSymbols base slots .long 12 argument.value)
        match entry.location with
        | .general first count =>
          for j in [:count] do
            lines := lines ++ readFragment (first+j) (j*8) (min 8 (info.layout.size-j*8))
        | .floating first count width =>
          for j in [:count] do
            lines := lines ++ [s!"\tldr {floatRegister width (first+j)}, [x12, #{j*width.bytes}]"]
        | .stack offset => lines := lines ++ stackAddress "sp" 13 offset ++ copyAggregate info.layout.size
    else
      match entry.location with
      | .floating index _ _ =>
        lines := lines ++ (← load darwin localSymbols base slots argument.width 9 argument.value)
          ++ [s!"\tfmov {floatRegister argument.width index}, {register argument.width 9}"]
      | .general index _ =>
        lines := lines ++ (← load darwin localSymbols base slots argument.width index argument.value)
        if let some kind := argument.subword then lines := lines ++ [extendSubword kind index]
      | .stack offset =>
        lines := lines ++ (← load darwin localSymbols base slots argument.width 9 argument.value)
        if let some kind := argument.subword then lines := lines ++ [extendSubword kind 9]
        let instruction := if !argument.variadic then match argument.subword with
          | some kind => if kind.bytes == 1 then "strb w9" else "strh w9"
          | none => s!"str {register argument.width 9}"
          else s!"str {register argument.width 9}"
        lines := lines ++ [s!"\t{instruction}, [sp, #{offset}]"]
  if let some (destination, name) := result then
    let info ← AggregateABI.find types name
    if info.passing == .indirect then
      lines := lines ++ stackAddress base 8 (← slotOffset allocations destination)
  if let some argument := arguments[0]? then
    if argument.environment then lines := lines ++ (← load darwin localSymbols base slots .long 9 argument.value)
  lines := lines ++ (← match target with
    | .direct name => pure [s!"\tbl {symbolName darwin name}"]
    | .indirect address => pure ((← load darwin localSymbols base slots .long 16 address) ++ ["\tblr x16"]))
  if dynamicOutgoing then lines := lines ++ adjustStack "add" plan.totalBytes
  if let some (destination, name) := result then
    let info ← AggregateABI.find types name
    lines := lines ++ stackAddress base 12 (← slotOffset allocations destination)
    match info.passing with
    | .general count =>
      for j in [:count] do lines := lines ++ writeFragment j (j*8) (min 8 (info.layout.size-j*8))
    | .homogeneous width count =>
      for j in [:count] do lines := lines ++ [s!"\tstr {floatRegister width j}, [x12, #{j*width.bytes}]"]
    | .indirect => pure ()
    lines := lines ++ ["\tmov x9, x12"]
  pure lines

private def loadIncoming (width : Width) (offset : Nat) : List String :=
  if offset % width.bytes == 0 && offset / width.bytes < 4096 then
    [s!"\tldr {register width 9}, [sp, #{offset}]"]
  else stackAddress "sp" 10 offset ++ [s!"\tldr {register width 9}, [x10]"]

private def emitInstruction (darwin : Bool) (localSymbols : List String) (types : Array AggregateABI.TypeInfo) (base : String) (slots allocations : List (String × Nat)) (inst : Instruction)
    : Except String (List String) := do
  let mut lines : List String := []
  match inst.operation with
  | .convert op value =>
    lines := lines ++ (← load darwin localSymbols base slots op.inputWidth 9 value)
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
    lines := lines ++ (← load darwin localSymbols base slots inst.width 9 a) ++ (← load darwin localSymbols base slots inst.width 10 b)
    let f9 := floatRegister inst.width 16
    let f10 := floatRegister inst.width 17
    let instruction := match op with | .add => "fadd" | .sub => "fsub" | .mul => "fmul" | .div => "fdiv"
    lines := lines ++ [s!"\tfmov {f9}, {register inst.width 9}", s!"\tfmov {f10}, {register inst.width 10}",
      s!"\t{instruction} {f9}, {f9}, {f10}", s!"\tfmov {register inst.width 9}, {f9}"]
  | .floatNegate value =>
    lines := lines ++ (← load darwin localSymbols base slots inst.width 9 value)
    let r := register inst.width 9
    lines := lines ++ [s!"\teor {r}, {r}, #{2 ^ (inst.width.bits - 1)}"]
  | .floatCompare op width a b =>
    lines := lines ++ (← load darwin localSymbols base slots width 9 a) ++ (← load darwin localSymbols base slots width 10 b)
    let f9 := floatRegister width 16
    let f10 := floatRegister width 17
    lines := lines ++ [s!"\tfmov {f9}, {register width 9}", s!"\tfmov {f10}, {register width 10}",
      s!"\tfcmp {f9}, {f10}", s!"\tcset w9, {floatCondition op}"]
  | .cast value => lines := lines ++ (← load darwin localSymbols base slots inst.width 9 value)
  | .copy value => lines := lines ++ (← load darwin localSymbols base slots inst.width 9 value)
  | .binary op a b =>
    lines := lines ++ (← load darwin localSymbols base slots inst.width 9 a)
    lines := lines ++ (← load darwin localSymbols base slots (op.rhsWidth inst.width) 10 b)
    let r := register inst.width 9
    lines := lines ++ [s!"\t{mnemonic (select op)} {r}, {r}, {register inst.width 10}"]
  | .unary op value =>
    lines := lines ++ (← load darwin localSymbols base slots (op.inputWidth inst.width) 9 value)
    lines := lines ++ unaryInstruction inst.width op
  | .divide op a b =>
    lines := lines ++ (← load darwin localSymbols base slots inst.width 9 a)
    lines := lines ++ (← load darwin localSymbols base slots inst.width 10 b)
    let instruction := if op == .signedDiv || op == .signedRem then "sdiv" else "udiv"
    let r9 := register inst.width 9
    let r10 := register inst.width 10
    if op == .signedRem || op == .unsignedRem then
      let r11 := register inst.width 11
      lines := lines ++ [s!"\t{instruction} {r11}, {r9}, {r10}", s!"\tmsub {r9}, {r11}, {r10}, {r9}"]
    else lines := lines ++ [s!"\t{instruction} {r9}, {r9}, {r10}"]
  | .compare op width a b =>
    lines := lines ++ (← load darwin localSymbols base slots width 9 a)
    lines := lines ++ (← load darwin localSymbols base slots width 10 b)
    lines := lines ++ [s!"\tcmp {register width 9}, {register width 10}", s!"\tcset w9, {condition op}"]
  | .allocate _ size =>
    if base == "x29" then
      lines := lines ++ (← load darwin localSymbols base slots .long 9 size)
      lines := lines ++ ["\tadd x9, x9, #15", "\tand x9, x9, #-16",
        "\tsub sp, sp, x9", "\tmov x9, sp"]
    else
      let offset ← slotOffset allocations inst.destination
      lines := lines ++ stackAddress base 9 offset
  | .vaArg list =>
    lines := lines ++ (← load darwin localSymbols base slots .long 9 list)
    if darwin then
      lines := lines ++ ["\tldr x10, [x9]", s!"\tldr {register inst.width 11}, [x10]",
        "\tadd x10, x10, #8", "\tstr x10, [x9]", s!"\tmov {register inst.width 9}, {register inst.width 11}"]
    else
      let offset := if inst.floating then 28 else 24
      let top := if inst.floating then 16 else 8
      let step := if inst.floating then 16 else 8
      lines := lines ++ [s!"\tldrsw x10, [x9, #{offset}]", "\ttbz x10, #63, 1f",
        s!"\tldr x11, [x9, #{top}]", "\tadd x11, x11, x10", s!"\tadd w10, w10, #{step}",
        s!"\tstr w10, [x9, #{offset}]", "\tb 2f", "1:", "\tldr x11, [x9]",
        "\tadd x10, x11, #8", "\tstr x10, [x9]", "2:", s!"\tldr {register inst.width 9}, [x11]"]
  | .load kind address =>
    lines := lines ++ (← load darwin localSymbols base slots .long 9 address)
    lines := lines ++ [s!"\t{memoryLoad inst.width kind}, [x9]"]
  | .call target arguments =>
    -- Sources are stable stack slots: argument-register permutations cannot
    -- overwrite an argument that has not yet been loaded. All other live values
    -- also survive caller-saved clobbers in their own frame slots.
    lines := lines ++ (← emitCall darwin localSymbols types base slots allocations target arguments (inst.callAggregate.map (inst.destination, ·)))
    if inst.callAggregate.isNone then lines := lines ++ [if inst.floating then s!"\tfmov {register inst.width 9}, {floatRegister inst.width 0}"
      else s!"\tmov {register inst.width 9}, {register inst.width 0}"]
  let offset ← slotOffset slots inst.destination
  pure (lines ++ slotAccess "str" base (register inst.width 9) inst.width.bytes offset)

private structure VariadicFrame where
  stackOffset : Nat
  saveOffset : Nat
  gpUsed : Nat
  fpUsed : Nat

private def emitStatement (darwin : Bool) (localSymbols : List String) (types : Array AggregateABI.TypeInfo) (base : String) (slots allocations : List (String × Nat))
    (varargs : VariadicFrame) (statement : Statement) : Except String (List String) := do
  match statement with
  | .assign inst => emitInstruction darwin localSymbols types base slots allocations inst
  | .callVoid target arguments => emitCall darwin localSymbols types base slots allocations target arguments
  | .vaStart list => do
    let mut lines := (← load darwin localSymbols base slots .long 9 list) ++
      stackAddress base 10 varargs.stackOffset ++ ["\tstr x10, [x9]"]
    if !darwin then
      lines := lines ++ stackAddress base 10 (varargs.saveOffset + 64) ++ ["\tstr x10, [x9, #8]"] ++
        stackAddress base 10 (varargs.saveOffset + 192) ++ ["\tstr x10, [x9, #16]"] ++
        immediate .word 10 (((varargs.gpUsed : Int) - 8) * 8) ++ ["\tstr w10, [x9, #24]"] ++
        immediate .word 10 (((varargs.fpUsed : Int) - 8) * 16) ++ ["\tstr w10, [x9, #28]"]
    pure lines
  | .blit source destination bytes =>
    if bytes == 0 then return []
    let mut lines := (← load darwin localSymbols base slots .long 9 source) ++ (← load darwin localSymbols base slots .long 10 destination)
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
    pure ((← load darwin localSymbols base slots .long 9 address) ++ (← load darwin localSymbols base slots width 10 value) ++
      [s!"\tstr {register width 10}, [x9]"])
  | .store width value address =>
    let addressLines ← load darwin localSymbols base slots .long 9 address
    let valueLines ← load darwin localSymbols base slots width.valueWidth 10 value
    let instruction := match width with
      | .byte => "strb w10" | .half => "strh w10"
      | .word => "str w10" | .long => "str x10"
    pure (addressLines ++ valueLines ++ [s!"\t{instruction}, [x9]"])

private def blockLabel (f : Function) (label : String) : String :=
  s!"L_lcb_block_{f.name.length}_{f.name}_{label}"

private def edgeLabel (f : Function) (label : String) : String :=
  s!"L_lcb_edge_{f.name.length}_{f.name}_{label}"

/-- Phi lowering stages every source before changing any destination slot. -/
private def emitEdge (darwin : Bool) (localSymbols : List String) (base : String) (f : Function) (slots : List (String × Nat)) (stageBase : Nat)
    (predecessor target : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == target) | throw s!"unknown block @{target}"
  let mut lines := []
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_, value) := phi.incoming.find? (·.1 == predecessor)
      | throw s!"missing phi predecessor @{predecessor}"
    lines := lines ++ (← load darwin localSymbols base slots phi.width 9 value)
    lines := lines ++ slotAccess "str" base (register phi.width 9) phi.width.bytes (stageBase + i * 8)
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let offset ← slotOffset slots phi.destination
    let r := register phi.width 9
    lines := lines ++ slotAccess "ldr" base r phi.width.bytes (stageBase + i * 8) ++ slotAccess "str" base r phi.width.bytes offset
  pure lines

private def sectionDirective (darwin : Bool) (customSection : String) : String :=
  if darwin then ".section " ++ customSection
  else match customSection.splitOn "," with
    | name :: flags :: _ => s!".section {name},\"{flags}\""
    | _ => ".section " ++ customSection

private def checkTargetSection (darwin : Bool) (customSection : Option String) : Except String Unit := do
  if let some name := customSection then
    if darwin == name.startsWith "." then
      throw "custom section syntax does not match the selected object format"

/-- Quote UTF-8 bytes using assembler octal escapes, including quotes and backslashes. -/
private def debugFilename (name : String) : String :=
  "\"" ++ String.join (name.toUTF8.data.toList.map fun byte =>
    let n := byte.toNat
    "\\" ++ toString (n / 64) ++ toString (n / 8 % 8) ++ toString (n % 8)) ++ "\""

def emitFunction (f : Function) (types : Array AggregateABI.TypeInfo := #[]) (debugFileId : Nat := 1) (darwin : Bool := true) (localSymbols : List String := []) : Except String String := do
  validateFunction f true
  checkTargetSection darwin f.customSection
  let localNames := f.locals
  let dynamic := f.blocks.any fun block => block.instructions.any fun statement =>
    match statement with
    | .assign { operation := .allocate _ size, .. } =>
      block.label != f.blocks[0]!.label || match size with
        | .constant _ => false | _ => true
    | _ => false
  let dynamic := dynamic || f.blocks.any (fun block => block.instructions.any (fun statement =>
    statement.callSite.any (fun (_, args, _) => args.any (·.aggregate.isSome))))
  let base := if dynamic then "x29" else "sp"
  let mut outgoing := 0
  for block in f.blocks do
    for statement in block.instructions do
      if let some (_, arguments, _) := statement.callSite then
        outgoing := max outgoing (← AggregateABI.plan types arguments darwin).totalBytes
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
  let resultInfo ← f.resultAggregate.mapM (AggregateABI.find types)
  let resultPointer := frameEnd
  if resultInfo.any (·.passing == .indirect) then frameEnd := frameEnd + 8
  let variadicSave := alignUp frameEnd 16
  if !darwin && f.variadic then frameEnd := variadicSave + 192
  let mut allocations : List (String × Nat) := []
  for parameter in f.parameters do
    if let some name := parameter.aggregate then
      let info ← AggregateABI.find types name
      frameEnd := alignUp frameEnd 8
      allocations := (parameter.name, frameEnd) :: allocations
      frameEnd := frameEnd + max info.layout.size 1
  for block in f.blocks do
    for statement in block.instructions do
      if let .assign inst := statement then
        if let some name := inst.callAggregate then
          let info ← AggregateABI.find types name
          frameEnd := alignUp frameEnd 8
          allocations := (inst.destination, frameEnd) :: allocations
          frameEnd := frameEnd + max info.layout.size 1
  if !dynamic then
    for statement in f.blocks[0]!.instructions do
      if let .assign inst := statement then
        if let .allocate alignment (.constant size) := inst.operation then
          let offset := alignUp frameEnd alignment.bytes
          allocations := (inst.destination, offset) :: allocations
          frameEnd := offset + size.toNat
  let frame := alignUp frameEnd 16
  if frame > 1024 * 1024 then throw "stack frame exceeds the 1 MiB resource limit"
  let symbol := symbolName darwin f.name
  let mut lines := [s!"{if darwin then ";" else "//"} function {f.name}; AArch64 compatibility backend",
    f.customSection.map (sectionDirective darwin) |>.getD ".text"]
  if f.exported then lines := lines ++ [s!".globl {symbol}"]
  if !darwin then lines := lines ++ [s!".type {symbol}, %function"]
  lines := lines ++ [".p2align 2", s!"{symbol}:"]
  lines := lines ++ adjustStack "sub" frame
  if dynamic then
    lines := lines ++ ["\tstp x29, x30, [sp]", "\tmov x29, sp"]
  else if hasCalls then lines := lines ++ slotAccess "str" "sp" "x30" 8 returnAddress
  let incoming ← AggregateABI.plan types (parametersAsArguments f) darwin
  if !darwin && f.variadic then
    -- Save the argument banks before any user code or incoming-object copies.
    for i in [:8] do
      lines := lines ++ slotAccess "str" base s!"x{i}" 8 (variadicSave + i*8)
      lines := lines ++ slotAccess "str" base s!"q{i}" 16 (variadicSave + 64 + i*16)
  let varargs : VariadicFrame := { stackOffset := frame + alignUp incoming.stackUsed 8, saveOffset := variadicSave, gpUsed := incoming.gpUsed, fpUsed := incoming.fpUsed }
  if resultInfo.any (·.passing == .indirect) then
    lines := lines ++ stackAddress base 12 resultPointer ++ ["\tstr x8, [x12]"]
  if let some parameter := f.parameters[0]? then
    if parameter.environment then
      let offset ← slotOffset slots parameter.name
      lines := lines ++ slotAccess "str" base "x9" 8 offset
  for i in [:f.parameters.size] do
    let parameter := f.parameters[i]!
    if parameter.environment then continue
    let offset ← slotOffset slots parameter.name
    let entry := incoming.arguments[i]!
    if let some info := entry.aggregate then
      let objectOffset ← slotOffset allocations parameter.name
      if info.passing == .indirect then
        match entry.location with
        | .general first _ => lines := lines ++ [s!"\tmov x12, x{first}"]
        | .stack argumentOffset =>
          lines := lines ++ stackAddress "sp" 12 (frame + argumentOffset) ++ ["\tldr x12, [x12]"]
        | _ => throw "indirect parameter in floating register"
        lines := lines ++ stackAddress base 13 objectOffset ++ copyAggregate info.layout.size
      else
        match entry.location with
        | .general first count =>
          lines := lines ++ stackAddress base 12 objectOffset
          for j in [:count] do lines := lines ++ writeFragment (first+j) (j*8) (min 8 (info.layout.size-j*8))
        | .floating first count width =>
          lines := lines ++ stackAddress base 12 objectOffset
          for j in [:count] do lines := lines ++ [s!"\tstr {floatRegister width (first+j)}, [x12, #{j*width.bytes}]"]
        | .stack argumentOffset =>
          lines := lines ++ stackAddress "sp" 12 (frame + argumentOffset)
            ++ stackAddress base 13 objectOffset ++ copyAggregate info.layout.size
      lines := lines ++ stackAddress base 12 objectOffset ++ slotAccess "str" base "x12" 8 offset
    else
      match entry.location with
      | .floating index _ _ =>
        lines := lines ++ slotAccess "str" base (floatRegister parameter.width index) parameter.width.bytes offset
      | .general index _ =>
        lines := lines ++ slotAccess "str" base (register parameter.width index) parameter.width.bytes offset
      | .stack argumentOffset =>
        if let some kind := parameter.subword then
          let instruction := match kind with
            | .signedByte => "ldrsb w9" | .unsignedByte => "ldrb w9"
            | .signedHalf => "ldrsh w9" | .unsignedHalf => "ldrh w9"
          lines := lines ++ stackAddress "sp" 10 (frame + argumentOffset) ++ [s!"\t{instruction}, [x10]"]
        else lines := lines ++ loadIncoming parameter.width (frame + argumentOffset)
        lines := lines ++ slotAccess "str" base (register parameter.width 9) parameter.width.bytes offset
  for block in f.blocks do
    lines := lines ++ [blockLabel f block.label ++ ":"]
    let mut debugIndex := 0
    for instructionIndex in [:block.instructions.size + 1] do
      for _ in [:block.debugLocations.size] do
        if let some location := block.debugLocations[debugIndex]? then
          if location.instruction != instructionIndex then break
          lines := lines ++ [s!"\t.loc {debugFileId} {location.line} {location.column}"]
          debugIndex := debugIndex + 1
        else break
      if let some statement := block.instructions[instructionIndex]? then
        lines := lines ++ (← emitStatement darwin localSymbols types base slots allocations varargs statement)
    match block.terminator with
    | .ret value =>
      if let some value := value then
        let some width := f.resultWidth | throw "void function cannot return an integer"
        if let some info := resultInfo then
          lines := lines ++ (← load darwin localSymbols base slots .long 12 value)
          match info.passing with
          | .general count =>
            for j in [:count] do lines := lines ++ readFragment j (j*8) (min 8 (info.layout.size-j*8))
          | .homogeneous width count =>
            for j in [:count] do lines := lines ++ [s!"\tldr {floatRegister width j}, [x12, #{j*width.bytes}]"]
          | .indirect =>
            lines := lines ++ stackAddress base 13 resultPointer ++ ["\tldr x13, [x13]"] ++ copyAggregate info.layout.size
        else
          lines := lines ++ (← load darwin localSymbols base slots width 0 value)
          if let some kind := f.resultSubword then lines := lines ++ [extendSubword kind 0]
          if f.resultFloating then lines := lines ++ [s!"\tfmov {floatRegister width 0}, {register width 0}"]
      if dynamic then lines := lines ++ ["\tmov sp, x29", "\tldp x29, x30, [sp]"]
      else if hasCalls then lines := lines ++ slotAccess "ldr" "sp" "x30" 8 returnAddress
      lines := lines ++ adjustStack "add" frame
      lines := lines ++ ["\tret"]
    | .halt => lines := lines ++ ["\tbrk #0"]
    | .jump target =>
      lines := lines ++ (← emitEdge darwin localSymbols base f slots stageBase block.label target)
      lines := lines ++ [s!"\tb {blockLabel f target}"]
    | .branch condition yes no =>
      lines := lines ++ (← load darwin localSymbols base slots .word 9 condition)
      let otherwise := edgeLabel f block.label
      lines := lines ++ [s!"\tcbz w9, {otherwise}"]
      lines := lines ++ (← emitEdge darwin localSymbols base f slots stageBase block.label yes)
      lines := lines ++ [s!"\tb {blockLabel f yes}", otherwise ++ ":"]
      lines := lines ++ (← emitEdge darwin localSymbols base f slots stageBase block.label no)
      lines := lines ++ [s!"\tb {blockLabel f no}"]
  if !darwin then lines := lines ++ [s!".size {symbol}, .-{symbol}"]
  let file := match f.debugFile with
    | some name => s!".file {debugFileId} {debugFilename name}\n"
    | none => ""
  pure (file ++ String.intercalate "\n" (lines ++ [""]))

private def emitFunctions (program : Program) (types : Array AggregateABI.TypeInfo := #[]) (darwin : Bool := true) (localSymbols : List String := []) : Except String (List String) := do
  let mut fileId := 1
  let mut functions := []
  for f in program do
    functions := (← emitFunction f types fileId darwin localSymbols) :: functions
    if f.debugFile.isSome then fileId := fileId + 1
  pure functions.reverse

def emit (program : Program) : Except String String := do
  validate program
  let functions ← emitFunctions program
  return "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n"
    ++ String.intercalate "\n" functions
    ++ ".subsections_via_symbols\n"

private def emitData (darwin : Bool) (data : DataDefinition) : String := Id.run do
  if data.common then
    return s!".comm {symbolName darwin data.name},{data.byteSize},{if darwin then Nat.log2 data.alignment else data.alignment}\n"
  let mut lines := if data.threadLocal then
    if darwin then [".section __DATA,__thread_vars,thread_local_variables", ".p2align 3"]
    else [".section .tdata,\"awT\",%progbits", s!".type {data.name}, %tls_object"]
    else [data.customSection.map (sectionDirective darwin) |>.getD ".data"]
  if data.exported then lines := lines ++ [s!".globl {symbolName darwin data.name}"]
  let initialSymbol := if darwin && data.threadLocal then s!"_{data.name}$tlv$init" else symbolName darwin data.name
  if darwin && data.threadLocal then
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
      lines := lines ++ [s!"\t.quad {symbolName darwin name}{suffix}"]
  return String.intercalate "\n" (lines ++ [""])

def emitModule (module : Module) (darwin : Bool := true) : Except String String := do
  validateModule module
  for data in module.data do checkTargetSection darwin data.customSection
  let types ← AggregateABI.classify module.types
  let localSymbols := (module.functions.filter (!·.exported)).toList.map (·.name) ++
    (module.data.filter (fun data => !data.exported && !data.common)).toList.map (·.name)
  let functions ← emitFunctions module.functions types darwin localSymbols
  return (if darwin then "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n" else "// Generated by Lean Compiler Backend\n.text\n")
    ++ String.intercalate "\n" functions
    ++ String.intercalate "\n" (module.data.toList.map (emitData darwin))
    ++ (if darwin then ".subsections_via_symbols\n" else ".section .note.GNU-stack,\"\",%progbits\n")

end LeanCompilerBackend.AArch64
