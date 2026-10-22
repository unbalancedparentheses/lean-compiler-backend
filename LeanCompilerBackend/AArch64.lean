/-
  AArch64 instruction selection and assembly emission.
  Arithmetic mnemonic selection is adapted from QBE 1.3 arm64/emit.c; the ABI
  subset follows its arm64/abi.c. Zig 0.17.0's AIR -> target-code separation
  and width-specific registers are additional references. See docs/UPSTREAM.md
  and the retained upstream licenses in third_party/.
-/
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.AggregateABI
import LeanCompilerBackend.Selection
import LeanCompilerBackend.Allocation
import LeanCompilerBackend.Assembly

namespace LeanCompilerBackend.AArch64

open Assembly

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

/-- Choose a zero/ones fill and one initial halfword; keep the baseline emitter
    unchanged. MOVN uses the complement of its encoded halfword. -/
private def compactImmediate (width : Width) (destination : Nat) (value : Int) : List String := Id.run do
  let bits := Semantics.constant width value
  let shifts := (List.range (width.bits / 16)).map (· * 16)
  let chunk := fun shift => (bits >>> shift.toUInt64) &&& 65535
  let inverted := shifts.countP (fun shift => chunk shift != 65535) <
    shifts.countP (fun shift => chunk shift != 0)
  let fill : UInt64 := if inverted then 65535 else 0
  let first := (shifts.find? (fun shift => chunk shift != fill)).getD 0
  let initial := if inverted then 65535 - chunk first else chunk first
  let r := register width destination
  let suffix := if first == 0 then "" else s!", lsl #{first}"
  let mut result := [s!"\t{if inverted then "movn" else "movz"} {r}, #{initial}{suffix}"]
  for shift in shifts do
    if shift != first && chunk shift != fill then
      result := result ++ [s!"\tmovk {r}, #{chunk shift}, lsl #{shift}"]
  return result

/-- A logical immediate repeats a power-of-two element containing one cyclic
    run of ones and one of zeros. Zero and all-ones have no such encoding. -/
def logicalImmediate (width : Width) (value : Int) : Bool := Id.run do
  let bits := (Semantics.constant width value).toNat
  if bits == 0 || bits == 2^width.bits-1 then return false
  for size in #[2,4,8,16,32,64] do
    if size > width.bits then break
    let mask := 2^size-1
    let element := bits &&& mask
    if !(List.range (width.bits/size)).all (fun i => (bits >>> (i*size)) &&& mask == element) then
      continue
    let mut transitions := 0
    for i in [:size] do
      if (element >>> i) &&& 1 != (element >>> ((i+1)%size)) &&& 1 then
        transitions := transitions+1
    if transitions == 2 then return true
  return false

/-- Bounded immediate forms used only by the optional allocated path. The
    textual operand is independently assembled and exercised by target tests. -/
private def binaryImmediate (width : Width) (op : Binary) (value : Int) : Option (String × String) := do
  match op with
  | .add | .sub =>
    let signed := Semantics.signedBits width.bits (Semantics.constant width value)
    let magnitude := signed.natAbs
    let operand ← if magnitude ≤ 4095 then some s!"#{magnitude}"
      else if magnitude % 4096 == 0 && magnitude / 4096 ≤ 4095 then
        some s!"#{magnitude / 4096}, lsl #12"
      else none
    let subtract := (op == .sub) != (signed < 0)
    return (if subtract then "sub" else "add", operand)
  | .andBits | .orBits | .xorBits =>
    if logicalImmediate width value then
      return (mnemonic (select op), s!"#{Semantics.constant width value}")
    none
  | .shiftLeft | .logicalRight | .arithmeticRight =>
    let amount := (Semantics.constant .word value).toNat % width.bits
    return (mnemonic (select op), s!"#{amount}")
  | _ => none

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
    lines := lines ++ [s!"\tadrp x0, {symbolName true name}@TLVPPAGE", s!"\tldr x0, [x0, {symbolName true name}@TLVPPAGEOFF]",
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

private structure Homes where
  stack : List (String × Nat)
  registers : List (String × Nat)

private def operandRegister (homes : Homes) (scratch : Nat) : Operand → Nat
  | .temporary name => (homes.registers.lookup name).getD scratch
  | _ => scratch

private def storeHome (base : String) (homes : Homes) (width : Width)
    (source name : String) (floating : Bool := false) : Except String (List String) := do
  if let some n := homes.registers.lookup name then
    return [s!"\t{if floating then "fmov" else "mov"} {register width n}, {source}"]
  let some offset := homes.stack.lookup name | throw s!"missing storage home for %{name}"
  return slotAccess "str" base source width.bytes offset

private def load (darwin : Bool) (localSymbols : List String) (base : String) (slots : Homes) (width : Width) (destination : Nat)
    (value : Operand) : Except String (List String) := do
  match value with
  | .constant n => return if slots.registers.isEmpty then immediate width destination n
    else compactImmediate width destination n
  | .threadSymbol name => pure (threadAddress darwin width destination name)
  | .symbol name =>
    -- GOT references work for both module-local and externally linked symbols.
    let r := register .long destination
    return (if darwin then [s!"\tadrp {r}, {symbolName true name}@GOTPAGE", s!"\tldr {r}, [{r}, {symbolName true name}@GOTPAGEOFF]"]
      else if localSymbols.contains name then [s!"\tadrp {r}, {name}", s!"\tadd {r}, {r}, :lo12:{name}"]
      else [s!"\tadrp {r}, :got:{name}", s!"\tldr {r}, [{r}, :got_lo12:{name}]"])
      ++ (if width == .word then [s!"\tmov {register .word destination}, {register .word destination}"] else [])
  | .temporary name =>
    if let some n := slots.registers.lookup name then
      if width == .long && n == destination then return []
      return [s!"\tmov {register width destination}, {register width n}"]
    match slots.stack.lookup name with
    | some offset => return slotAccess "ldr" base (register width destination) width.bytes offset
    | none => throw s!"missing storage home for %{name}"

private def condition : Comparison → String
  | .eq => "eq" | .ne => "ne"
  | .signedLE => "le" | .signedLT => "lt" | .signedGE => "ge" | .signedGT => "gt"
  | .unsignedLE => "ls" | .unsignedLT => "lo" | .unsignedGE => "hs" | .unsignedGT => "hi"

private def inverseCondition : Comparison → String
  | .eq => "ne" | .ne => "eq"
  | .signedLE => "gt" | .signedLT => "ge" | .signedGE => "lt" | .signedGT => "le"
  | .unsignedLE => "hi" | .unsignedLT => "hs" | .unsignedGE => "lo" | .unsignedGT => "ls"

/-- Materialize integer comparison flags without consuming or changing operand homes. -/
private def comparisonFlags (darwin : Bool) (localSymbols : List String) (base : String)
    (slots : Homes) (width : Width) (a b : Operand) : Except String (List String) := do
  let left := operandRegister slots 9 a
  let right := operandRegister slots 10 b
  let encoded := if slots.registers.isEmpty then none else
    match b with | .constant value => binaryImmediate width .sub value | _ => none
  let mut lines := []
  if left == 9 then lines := (← load darwin localSymbols base slots width 9 a)
  if let some (instruction, operand) := encoded then
    -- CMN uses a nonzero magnitude; zero stays CMP for the carry flag.
    let comparison := if instruction == "add" then "cmn" else "cmp"
    lines := lines ++ [s!"\t{comparison} {register width left}, {operand}"]
  else
    if right == 10 then lines := lines ++ (← load darwin localSymbols base slots width 10 b)
    lines := lines ++ [s!"\tcmp {register width left}, {register width right}"]
  return lines

private def unaryInstruction (width : Width) (op : Unary) (destination source : Nat) : List String :=
  let output := register width destination
  let input := register width source
  match op with
  | .negate => [s!"\tneg {output}, {input}"]
  | .signedByte => [s!"\tsxtb {output}, w{source}"]
  | .unsignedByte => [s!"\tuxtb w{destination}, w{source}"]
  | .signedHalf => [s!"\tsxth {output}, w{source}"]
  | .unsignedHalf => [s!"\tuxth w{destination}, w{source}"]
  | .signedWord => [s!"\tsxtw x{destination}, w{source}"]
  | .unsignedWord =>
    -- The baseline's w9 load already normalizes; direct homes need a W write,
    -- including when source and destination are the same physical register.
    if destination == 9 && source == 9 then []
    else [s!"\tmov w{destination}, w{source}"]

private def extendSubword (kind : Subword) (index : Nat) : String :=
  let instruction := match kind with
    | .signedByte => "sxtb" | .unsignedByte => "uxtb"
    | .signedHalf => "sxth" | .unsignedHalf => "uxth"
  s!"\t{instruction} w{index}, w{index}"

private def slotOffset (slots : List (String × Nat)) (name : String) : Except String Nat :=
  match slots.lookup name with
  | some offset => .ok offset
  | none => .error s!"missing stack slot for %{name}"

private def memoryLoad (width : Width) (destination : Nat) : LoadKind → String
  | .signedByte => s!"ldrsb {register width destination}"
  | .unsignedByte => s!"ldrb w{destination}"
  | .signedHalf => s!"ldrsh {register width destination}"
  | .unsignedHalf => s!"ldrh w{destination}"
  | .signedWord => if width == .long then s!"ldrsw x{destination}" else s!"ldr w{destination}"
  | .unsignedWord => s!"ldr w{destination}"
  | .plain => s!"ldr {register width destination}"

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
    (slots : Homes) (allocations : List (String × Nat)) (target : CallTarget)
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

private def emitInstruction (darwin : Bool) (localSymbols : List String) (types : Array AggregateABI.TypeInfo) (base : String) (slots : Homes) (allocations : List (String × Nat)) (inst : Instruction)
    : Except String (List String) := do
  let mut lines : List String := []
  match inst.operation with
  | .convert op value =>
    let sourceHome := operandRegister slots 9 value
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if sourceHome == 9 then lines := lines ++ (← load darwin localSymbols base slots op.inputWidth 9 value)
    let input := register op.inputWidth sourceHome
    let output := register inst.width resultHome
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
    if resultHome != 9 then return lines
  | .floatBinary op a b =>
    let left := operandRegister slots 9 a
    let right := operandRegister slots 10 b
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if left == 9 then lines := lines ++ (← load darwin localSymbols base slots inst.width 9 a)
    if right == 10 then lines := lines ++ (← load darwin localSymbols base slots inst.width 10 b)
    let f9 := floatRegister inst.width 16
    let f10 := floatRegister inst.width 17
    let instruction := match op with | .add => "fadd" | .sub => "fsub" | .mul => "fmul" | .div => "fdiv"
    lines := lines ++ [s!"\tfmov {f9}, {register inst.width left}", s!"\tfmov {f10}, {register inst.width right}",
      s!"\t{instruction} {f9}, {f9}, {f10}", s!"\tfmov {register inst.width resultHome}, {f9}"]
    if resultHome != 9 then return lines
  | .floatNegate value =>
    let sourceHome := operandRegister slots 9 value
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if sourceHome == 9 then lines := lines ++ (← load darwin localSymbols base slots inst.width 9 value)
    lines := lines ++ [s!"\teor {register inst.width resultHome}, {register inst.width sourceHome}, #{2 ^ (inst.width.bits - 1)}"]
    if resultHome != 9 then return lines
  | .floatCompare op width a b =>
    let left := operandRegister slots 9 a
    let right := operandRegister slots 10 b
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if left == 9 then lines := lines ++ (← load darwin localSymbols base slots width 9 a)
    if right == 10 then lines := lines ++ (← load darwin localSymbols base slots width 10 b)
    let f9 := floatRegister width 16
    let f10 := floatRegister width 17
    lines := lines ++ [s!"\tfmov {f9}, {register width left}", s!"\tfmov {f10}, {register width right}",
      s!"\tfcmp {f9}, {f10}", s!"\tcset w{resultHome}, {floatCondition op}"]
    if resultHome != 9 then return lines
  | .cast value | .copy value =>
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    lines := lines ++ (← load darwin localSymbols base slots inst.width resultHome value)
    if resultHome != 9 then return lines
  | .binary op a b =>
    -- Stable GP homes can be read/written directly. Scratch registers remain
    -- reserved for constants and spilled operands; allocation already checks
    -- that overwriting a destination cannot destroy another live SSA value.
    let (a, b) := if !slots.registers.isEmpty && (op == .add || op == .andBits || op == .orBits || op == .xorBits) then
      match a with | .constant _ => (b, a) | _ => (a, b)
      else (a, b)
    let encoded := if slots.registers.isEmpty then none else
      match b with | .constant value => binaryImmediate inst.width op value | _ => none
    let left := operandRegister slots 9 a
    let right := operandRegister slots 10 b
    let destination := (slots.registers.lookup inst.destination).getD 9
    if left == 9 then lines := lines ++ (← load darwin localSymbols base slots inst.width 9 a)
    if let some (instruction, operand) := encoded then
      lines := lines ++ [s!"\t{instruction} {register inst.width destination}, {register inst.width left}, {operand}"]
    else
      if right == 10 then lines := lines ++ (← load darwin localSymbols base slots (op.rhsWidth inst.width) 10 b)
      lines := lines ++ [s!"\t{mnemonic (select op)} {register inst.width destination}, {register inst.width left}, {register inst.width right}"]
    -- Variable shifts inspect only the low 5/6 count bits, so reading an
    -- allocated count directly preserves the existing word-count normalization.
    if destination != 9 then return lines
  | .unary op value =>
    let sourceHome := operandRegister slots 9 value
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if sourceHome == 9 then lines := lines ++ (← load darwin localSymbols base slots (op.inputWidth inst.width) 9 value)
    lines := lines ++ unaryInstruction inst.width op resultHome sourceHome
    if resultHome != 9 then return lines
  | .divide op a b =>
    let left := operandRegister slots 9 a
    let right := operandRegister slots 10 b
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if left == 9 then lines := lines ++ (← load darwin localSymbols base slots inst.width 9 a)
    if right == 10 then lines := lines ++ (← load darwin localSymbols base slots inst.width 10 b)
    let instruction := if op == .signedDiv || op == .signedRem then "sdiv" else "udiv"
    let rLeft := register inst.width left
    let rRight := register inst.width right
    let output := register inst.width resultHome
    if op == .signedRem || op == .unsignedRem then
      let quotient := register inst.width 11
      lines := lines ++ [s!"\t{instruction} {quotient}, {rLeft}, {rRight}", s!"\tmsub {output}, {quotient}, {rRight}, {rLeft}"]
    else lines := lines ++ [s!"\t{instruction} {output}, {rLeft}, {rRight}"]
    if resultHome != 9 then return lines
  | .compare op width a b =>
    let destination := (slots.registers.lookup inst.destination).getD 9
    lines := lines ++ (← comparisonFlags darwin localSymbols base slots width a b)
    -- A W write zero-extends, so both word and long boolean results are exact.
    lines := lines ++ [s!"\tcset {register .word destination}, {condition op}"]
    if destination != 9 then return lines
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
    let addressHome := operandRegister slots 9 address
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    if addressHome == 9 then lines := lines ++ (← load darwin localSymbols base slots .long 9 address)
    lines := lines ++ [s!"\t{memoryLoad inst.width resultHome kind}, [x{addressHome}]"]
    if resultHome != 9 then return lines
  | .call target arguments =>
    -- Stable homes are stack slots or callee-saved registers, outside argument
    -- and scratch banks. Permutations and call clobbers preserve their values.
    lines := lines ++ (← emitCall darwin localSymbols types base slots allocations target arguments (inst.callAggregate.map (inst.destination, ·)))
    if inst.callAggregate.isNone then
      let resultHome := (slots.registers.lookup inst.destination).getD 9
      lines := lines ++ [if inst.floating then s!"\tfmov {register inst.width resultHome}, {floatRegister inst.width 0}"
        else s!"\tmov {register inst.width resultHome}, {register inst.width 0}"]
      if resultHome != 9 then return lines
  pure (lines ++ (← storeHome base slots inst.width (register inst.width 9) inst.destination))

private structure VariadicFrame where
  stackOffset : Nat
  saveOffset : Nat
  gpUsed : Nat
  fpUsed : Nat

private def emitStatement (darwin : Bool) (localSymbols : List String) (types : Array AggregateABI.TypeInfo) (base : String) (slots : Homes) (allocations : List (String × Nat))
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
    let remaining := if bytes > 128 then bytes % 8 else bytes
    if bytes > 128 then
      lines := lines ++ compactImmediate .long 12 (bytes / 8) ++
        ["1:", "\tldr x11, [x9], #8", "\tstr x11, [x10], #8",
         "\tsubs x12, x12, #1", "\tb.ne 1b"]
    let mut offset := 0
    -- Unaligned ordinary integer accesses are supported by the initial target.
    -- Partial source/destination overlap is outside QBE's defined blit domain.
    for size in [8, 4, 2, 1] do
      for _ in [:((remaining - offset) / size)] do
        let (read, write) := match size with
          | 8 => ("ldr x11", "str x11")
          | 4 => ("ldr w11", "str w11")
          | 2 => ("ldrh w11", "strh w11")
          | _ => ("ldrb w11", "strb w11")
        lines := lines ++ [s!"\t{read}, [x9, #{offset}]", s!"\t{write}, [x10, #{offset}]"]
        offset := offset + size
    pure lines
  | .storeFloat width value address => do
    let addressHome := operandRegister slots 9 address
    let valueHome := operandRegister slots 10 value
    let addressLines ← if addressHome == 9 then load darwin localSymbols base slots .long 9 address else pure []
    let valueLines ← if valueHome == 10 then load darwin localSymbols base slots width 10 value else pure []
    pure (addressLines ++ valueLines ++ [s!"\tstr {register width valueHome}, [x{addressHome}]"])
  | .store width value address => do
    let addressHome := operandRegister slots 9 address
    let valueHome := operandRegister slots 10 value
    let addressLines ← if addressHome == 9 then load darwin localSymbols base slots .long 9 address else pure []
    let valueLines ← if valueHome == 10 then load darwin localSymbols base slots width.valueWidth 10 value else pure []
    let instruction := match width with
      | .byte => s!"strb w{valueHome}" | .half => s!"strh w{valueHome}"
      | .word => s!"str w{valueHome}" | .long => s!"str x{valueHome}"
    pure (addressLines ++ valueLines ++ [s!"\t{instruction}, [x{addressHome}]"])

/-- Select an adjacent long address calculation plus its sole load/store use.
    No intervening instruction can overwrite the base's assigned home, and no
    remaining use needs the omitted address result. This deliberately does not
    extend liveness or fuse across blocks. The stack baseline stays unchanged. -/
private def adjacentMemory (darwin : Bool) (localSymbols : List String) (base : String)
    (slots : Homes) (uses : Std.HashMap String Nat) (first second : Statement)
    : Except String (Option (List String)) := do
  let .assign address := first | return none
  if address.width != .long || address.floating || uses[address.destination]? != some 1 then return none
  let pair := match address.operation with
    | .binary .add pointer (.constant n) | .binary .add (.constant n) pointer => some (pointer,n)
    | .binary .sub pointer (.constant n) => some (pointer,-n)
    | _ => none
  let some (pointer,rawOffset) := pair | return none
  let access := match second with
    | .assign {operation := .load kind (.temporary name), width, ..} => some (name,kind.bytes width)
    | .store width _ (.temporary name) => some (name,width.bytes)
    | .storeFloat width _ (.temporary name) => some (name,width.bytes)
    | _ => none
  let some (name,bytes) := access | return none
  if name != address.destination then return none
  let offset := Semantics.signedBits 64 (Semantics.constant .long rawOffset)
  let scaled := offset >= 0 && offset.toNat % bytes == 0 && offset.toNat / bytes < 4096
  if !scaled && !(offset >= -256 && offset <= 255) then return none
  let addressHome := operandRegister slots 9 pointer
  let mut lines ← if addressHome == 9 then load darwin localSymbols base slots .long 9 pointer else pure []
  let memory := fun (instruction : String) =>
    let instruction := if scaled then instruction else
      (instruction.replace "ldr" "ldur").replace "str" "stur"
    s!"\t{instruction}, [x{addressHome}, #{offset}]"
  match second with
  | .assign inst =>
    let .load kind _ := inst.operation | return none
    let resultHome := (slots.registers.lookup inst.destination).getD 9
    lines := lines ++ [memory (memoryLoad inst.width resultHome kind)]
    if resultHome == 9 then
      lines := lines ++ (← storeHome base slots inst.width (register inst.width 9) inst.destination)
  | .store width value _ =>
    let valueHome := operandRegister slots 10 value
    if valueHome == 10 then lines := lines ++ (← load darwin localSymbols base slots width.valueWidth 10 value)
    let instruction := match width with
      | .byte => s!"strb w{valueHome}" | .half => s!"strh w{valueHome}"
      | .word => s!"str w{valueHome}" | .long => s!"str x{valueHome}"
    lines := lines ++ [memory instruction]
  | .storeFloat width value _ =>
    let valueHome := operandRegister slots 10 value
    if valueHome == 10 then lines := lines ++ (← load darwin localSymbols base slots width 10 value)
    lines := lines ++ [memory s!"str {register width valueHome}"]
  | _ => return none
  return some lines

private def blockLabel (f : Function) (label : String) : String :=
  s!"L_lcb_block_{f.name.length}_{localName f.name}_{label}"

private def edgeLabel (f : Function) (label : String) : String :=
  s!"L_lcb_edge_{f.name.length}_{localName f.name}_{label}"

/-- Schedule register phi copies only when their destination is no longer a
    source of another pending copy. Stack/symbol transfers and remaining cycles
    retain simultaneous staging. Distinct destinations are checked by allocation.
    A narrowing self-copy waits for other users of its old long register bits. -/
private def emitEdge (darwin : Bool) (localSymbols : List String) (base : String) (f : Function) (slots : Homes) (stageBase : Nat)
    (predecessor target : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == target) | throw s!"unknown block @{target}"
  let mut lines := []
  let mut values : Array Operand := #[]
  let mut sources : Array (Option Nat) := #[]
  let mut destinations : Array (Option Nat) := #[]
  let mut pending : Array Nat := #[]
  let mut staged : Array Nat := #[]
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_, value) := phi.incoming.find? (·.1 == predecessor)
      | throw s!"missing phi predecessor @{predecessor}"
    values := values.push value
    sources := sources.push (match value with
      | .temporary name => slots.registers.lookup name | _ => none)
    let destination := slots.registers.lookup phi.destination
    destinations := destinations.push destination
    let direct := match value with | .temporary _ | .constant _ => true | _ => false
    if destination.isSome && direct then pending := pending.push i
    else
      lines := lines ++ (← load darwin localSymbols base slots phi.width 9 value)
      lines := lines ++ slotAccess "str" base (register phi.width 9) phi.width.bytes (stageBase + i * 8)
      staged := staged.push i
  -- At most ten phi destinations can occupy the ARM64 callee-saved bank.
  for _ in [:pending.size] do
    let ready := pending.find? fun i =>
      pending.all fun j => i == j || sources[j]! != destinations[i]!
    let some i := ready | break
    lines := lines ++ (← load darwin localSymbols base slots block.phis[i]!.width
      destinations[i]!.get! values[i]!)
    pending := pending.filter (· != i)
  -- A dependency cycle must snapshot all its old values before any commit.
  for i in pending do
    let phi := block.phis[i]!
    lines := lines ++ (← load darwin localSymbols base slots phi.width 9 values[i]!)
    lines := lines ++ slotAccess "str" base (register phi.width 9) phi.width.bytes (stageBase + i * 8)
    staged := staged.push i
  for i in staged do
    let phi := block.phis[i]!
    let r := register phi.width 9
    lines := lines ++ slotAccess "ldr" base r phi.width.bytes (stageBase + i * 8) ++ (← storeHome base slots phi.width r phi.destination)
  pure lines

def emitFunction (f : Function) (types : Array AggregateABI.TypeInfo := #[]) (debugFileId : Nat := 1) (darwin : Bool := true) (localSymbols : List String := []) (allocate : Bool := false) : Except String String := do
  validateFunction f true
  checkTargetSection darwin f.customSection
  let homes ← if allocate then Allocation.allocate f 10 else pure (Allocation.baseline f)
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
  let slots : Homes := {
    stack := homes.homes.filterMap (fun (name,i) => if i >= homes.registerCount then some (name,outgoing+(i-homes.registerCount)*8) else none)
    registers := homes.homes.filterMap (fun (name,i) => if i < homes.registerCount then some (name,19+i) else none) }
  let maxPhis := f.blocks.foldl (fun n block => max n block.phis.size) 0
  let stageBase := outgoing + homes.spills * 8
  let mut frameEnd := outgoing + (homes.spills + maxPhis) * 8
  let savedBase := frameEnd
  frameEnd := frameEnd+homes.registers*8
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
  let mut lines := Assembly.LineBuffer.ofList [s!"{if darwin then ";" else "//"} function {f.name}; AArch64 compatibility backend",
    f.customSection.map (sectionDirective darwin) |>.getD ".text"]
  if f.exported then lines := lines ++ [s!".globl {symbol}"]
  if !darwin then lines := lines ++ [s!".type {symbol}, %function"]
  lines := lines ++ [".p2align 2", s!"{symbol}:"]
  lines := lines ++ adjustStack "sub" frame
  if dynamic then
    lines := lines ++ ["\tstp x29, x30, [sp]", "\tmov x29, sp"]
  else if hasCalls then lines := lines ++ slotAccess "str" "sp" "x30" 8 returnAddress
  for i in [:homes.registers] do lines := lines ++ slotAccess "str" base s!"x{19+i}" 8 (savedBase+i*8)
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
      lines := lines ++ (← storeHome base slots .long "x9" parameter.name)
  for i in [:f.parameters.size] do
    let parameter := f.parameters[i]!
    if parameter.environment then continue
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
      lines := lines ++ stackAddress base 12 objectOffset ++ (← storeHome base slots .long "x12" parameter.name)
    else
      match entry.location with
      | .floating index _ _ =>
        lines := lines ++ (← storeHome base slots parameter.width (floatRegister parameter.width index) parameter.name true)
      | .general index _ =>
        lines := lines ++ (← storeHome base slots parameter.width (register parameter.width index) parameter.name)
      | .stack argumentOffset =>
        if let some kind := parameter.subword then
          let instruction := match kind with
            | .signedByte => "ldrsb w9" | .unsignedByte => "ldrb w9"
            | .signedHalf => "ldrsh w9" | .unsignedHalf => "ldrh w9"
          lines := lines ++ stackAddress "sp" 10 (frame + argumentOffset) ++ [s!"\t{instruction}, [x10]"]
        else lines := lines ++ loadIncoming parameter.width (frame + argumentOffset)
        lines := lines ++ (← storeHome base slots parameter.width (register parameter.width 9) parameter.name)
  let addressUses := if allocate then Selection.useCounts f else {}
  for blockIndex in [:f.blocks.size] do
    let block := f.blocks[blockIndex]!
    let next := (f.blocks[blockIndex+1]?).map (·.label)
    lines := lines ++ [blockLabel f block.label ++ ":"]
    let mut debugIndex := 0
    -- Only the final comparison may feed flags directly to the terminator.
    -- Whole-function use counts include phi edges, so no omitted boolean survives.
    let branchCompare := if allocate then Selection.branchComparison addressUses block else none
    let mut pendingMemory : Option (List String) := none
    for instructionIndex in [:block.instructions.size + 1] do
      for _ in [:block.debugLocations.size] do
        if let some location := block.debugLocations[debugIndex]? then
          if location.instruction != instructionIndex then break
          lines := lines ++ [s!"\t.loc {debugFileId} {location.line} {location.column}"]
          debugIndex := debugIndex + 1
        else break
      if let some statement := block.instructions[instructionIndex]? then
        if let some selected := pendingMemory then
          lines := lines ++ selected
          pendingMemory := none
        else
          if allocate then
            if let some next := block.instructions[instructionIndex+1]? then
              pendingMemory ← adjacentMemory darwin localSymbols base slots addressUses statement next
          if pendingMemory.isNone then
            if let some (_, width, a, b) := branchCompare then
              if instructionIndex+1 == block.instructions.size then
                lines := lines ++ (← comparisonFlags darwin localSymbols base slots width a b)
              else
                lines := lines ++ (← emitStatement darwin localSymbols types base slots allocations varargs statement)
            else
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
        else if f.resultFloating && f.resultSubword.isNone then
          let sourceHome := operandRegister slots 0 value
          if sourceHome == 0 then lines := lines ++ (← load darwin localSymbols base slots width 0 value)
          lines := lines ++ [s!"\tfmov {floatRegister width 0}, {register width sourceHome}"]
        else
          lines := lines ++ (← load darwin localSymbols base slots width 0 value)
          if let some kind := f.resultSubword then lines := lines ++ [extendSubword kind 0]
          if f.resultFloating then lines := lines ++ [s!"\tfmov {floatRegister width 0}, {register width 0}"]
      for i in [:homes.registers] do lines := lines ++ slotAccess "ldr" base s!"x{19+i}" 8 (savedBase+i*8)
      if dynamic then lines := lines ++ ["\tmov sp, x29", "\tldp x29, x30, [sp]"]
      else if hasCalls then lines := lines ++ slotAccess "ldr" "sp" "x30" 8 returnAddress
      lines := lines ++ adjustStack "add" frame
      lines := lines ++ ["\tret"]
    | .halt => lines := lines ++ ["\tbrk #0"]
    | .jump target =>
      lines := lines ++ (← emitEdge darwin localSymbols base f slots stageBase block.label target)
      if !allocate || next != some target then lines := lines ++ [s!"\tb {blockLabel f target}"]
    | .branch condition yes no =>
      let otherwise := edgeLabel f block.label
      if let some (op, _, _, _) := branchCompare then
        lines := lines ++ [s!"\tb.{inverseCondition op} {otherwise}"]
      else
        let conditionHome := operandRegister slots 9 condition
        if conditionHome == 9 then lines := lines ++ (← load darwin localSymbols base slots .word 9 condition)
        lines := lines ++ [s!"\tcbz w{conditionHome}, {otherwise}"]
      lines := lines ++ (← emitEdge darwin localSymbols base f slots stageBase block.label yes)
      lines := lines ++ [s!"\tb {blockLabel f yes}", otherwise ++ ":"]
      lines := lines ++ (← emitEdge darwin localSymbols base f slots stageBase block.label no)
      if !allocate || next != some no then lines := lines ++ [s!"\tb {blockLabel f no}"]
  if !darwin then lines := lines ++ [s!".size {symbol}, .-{symbol}"]
  let file := match f.debugFile with
    | some name => s!".file {debugFileId} {debugFilename name}\n"
    | none => ""
  pure (file ++ String.intercalate "\n" (lines ++ [""]).toList)

private def emitFunctions (program : Program) (types : Array AggregateABI.TypeInfo := #[]) (darwin : Bool := true) (localSymbols : List String := []) (allocate : Bool := false) : Except String (List String) := do
  let mut fileId := 1
  let mut functions := []
  for f in program do
    functions := (← emitFunction f types fileId darwin localSymbols allocate) :: functions
    if f.debugFile.isSome then fileId := fileId + 1
  pure functions.reverse

def emit (program : Program) : Except String String := do
  validate program
  let functions ← emitFunctions program
  return "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n"
    ++ String.intercalate "\n" functions
    ++ ".subsections_via_symbols\n"

def emitModule (module : Module) (darwin : Bool := true) (allocate : Bool := false) : Except String String := do
  validateModule module
  for data in module.data do checkTargetSection darwin data.customSection
  let types ← AggregateABI.classify module.types
  let localSymbols := (module.functions.filter (!·.exported)).toList.map (·.name) ++
    (module.data.filter (fun data => !data.exported && !data.common)).toList.map (·.name)
  let functions ← emitFunctions module.functions types darwin localSymbols allocate
  return (if darwin then "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n" else "// Generated by Lean Compiler Backend\n.text\n")
    ++ String.intercalate "\n" functions
    ++ String.intercalate "\n" (module.data.toList.map (emitData darwin))
    ++ (if darwin then ".subsections_via_symbols\n" else ".section .note.GNU-stack,\"\",%progbits\n")

end LeanCompilerBackend.AArch64
