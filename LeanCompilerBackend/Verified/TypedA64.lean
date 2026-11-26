/- Typed AArch64 leaf assembly. Rendering follows legality checks; this is not
   an encoder or a proof of conformity to the ARM architectural specification. -/
import LeanCompilerBackend.Verified.StackMIR

namespace LeanCompilerBackend.Verified.TypedA64

abbrev Label := StackMIR.Label

inductive Condition where
  | eq | lo | ls | lt | le
  deriving DecidableEq, Repr

def Condition.spelling : Condition → String
  | .eq => "eq" | .lo => "lo" | .ls => "ls" | .lt => "lt" | .le => "le"

inductive Instruction where
  | subSP (bytes : Nat)
  | addSP (bytes : Nat)
  | load (width : Width) (reg offset : Nat)
  | store (width : Width) (reg offset : Nat)
  | movz (width : Width) (reg chunk shift : Nat)
  | movk (width : Width) (reg chunk shift : Nat)
  | alu (width : Width) (op : Source.Binary) (dst lhs rhs : Nat)
  /-- UDIV/SDIV dst, lhs, rhs. -/
  | divide (width : Width) (signed : Bool) (dst lhs rhs : Nat)
  /-- MSUB dst, lhs, rhs, addend: dst = addend - lhs * rhs. -/
  | msub (width : Width) (dst lhs rhs addend : Nat)
  | cmp (width : Width) (lhs rhs : Nat)
  | cset (reg : Nat) (condition : Condition)
  | cbnz (reg : Nat) (target : Label)
  | jump (target : Label)
  | ret
  deriving DecidableEq, Repr

structure Block where
  label : Label
  instructions : Array Instruction
  deriving DecidableEq, Repr

structure Function where
  parameters : Array Width
  resultWidth : Width
  frameBytes : Nat
  blocks : Array Block
  deriving DecidableEq, Repr

inductive Error where
  | invalid (reason : String)
  | unsupportedHighMultiplyWidth (op : Source.Binary) (width : Width)
  deriving DecidableEq, Repr

def Error.message : Error → String
  | .invalid reason => reason
  | .unsupportedHighMultiplyWidth op width =>
    s!"unsupported high multiply {repr op} at {repr width} width (UMULH/SMULH require X registers)"

private def checkALUWidth (op : Source.Binary) (width : Width) : Except Error Unit := do
  if width == .word && op.isHighMultiply then
    throw (.unsupportedHighMultiplyWidth op width)

private def immediate (reg : Nat) (value : Source.Value) : Array Instruction := Id.run do
  let width := value.width
  let bits := value.toNat
  let mut code := #[Instruction.movz width reg (bits % 65536) 0]
  for shift in [16:width.bits:16] do
    let chunk := (bits / 2 ^ shift) % 65536
    if chunk != 0 then code := code.push (.movk width reg chunk shift)
  return code

def selectInstruction (f : StackMIR.Function) : StackMIR.Instruction → Except Error (Array Instruction)
  | .enterFrame bytes => pure (if bytes == 0 then #[] else #[.subSP bytes])
  | .leaveFrame bytes => pure (if bytes == 0 then #[] else #[.addSP bytes])
  | .readArg width index slot => do pure #[.store width index (← (StackMIR.offset f slot).mapError Error.invalid)]
  | .constant reg value => pure (immediate reg.index value)
  | .load width reg slot => do pure #[.load width reg.index (← (StackMIR.offset f slot).mapError Error.invalid)]
  | .store width slot reg => do pure #[.store width reg.index (← (StackMIR.offset f slot).mapError Error.invalid)]
  | .alu width op dst lhs rhs => do
    checkALUWidth op width
    pure #[.alu width op dst.index lhs.index rhs.index]
  | .compare width op dst lhs rhs =>
    pure #[.cmp width lhs.index rhs.index, .cset dst.index (explicit_op% match op with
      | .eq => .eq | .unsignedLT => .lo | .unsignedLE => .ls | .signedLT => .lt | .signedLE => .le)]
  | .divide width op dst lhs rhs =>
    let signed := op.isSigned
    -- A remainder forms its quotient in its own destination, then MSUB reads
    -- both operands again, so the destination must differ from them.
    if !op.isRemainder then pure #[.divide width signed dst.index lhs.index rhs.index]
    else if dst == lhs || dst == rhs then throw (.invalid "remainder destination must differ from its operands")
    else pure #[.divide width signed dst.index lhs.index rhs.index,
      .msub width dst.index dst.index rhs.index lhs.index]

def select (f : StackMIR.Function) : Except Error Function := do
  (StackMIR.validate f).mapError Error.invalid
  let mut blocks := #[]
  for block in f.blocks do
    let mut instructions := #[]
    for inst in block.instructions do instructions := instructions ++ (← selectInstruction f inst)
    instructions := instructions ++ (match block.terminator with
      | .jump target => #[.jump target]
      | .branch reg yes no => #[.cbnz reg.index yes, .jump no]
      | .ret _ => #[.ret])
    blocks := blocks.push { label := block.label, instructions }
  pure { parameters := f.parameters, resultWidth := f.resultWidth, frameBytes := f.layout.frameBytes, blocks }

private def writable (reg : Nat) : Bool := reg == 0 || reg == 9 || reg == 10
private def readable (reg : Nat) : Bool := reg < 8 || reg == 9 || reg == 10

private def checkAccess (f : Function) (width : Width) (offset : Nat) : Except Error Unit := do
  if offset % width.bytes != 0 || offset / width.bytes >= 4096 || offset + width.bytes > f.frameBytes then
    throw (.invalid "assembly frame access is out of bounds, misaligned or unencodable")

/-- Validates legal forms and frame/control structure, not semantic value flow. -/
def validate (f : Function) : Except Error Unit := do
  if f.frameBytes > 4080 || f.frameBytes % 16 != 0 || f.parameters.size > 8 then
    throw (.invalid "invalid assembly frame/signature")
  if (f.blocks[0]?).map (·.label) != some .entry then throw (.invalid "missing assembly entry")
  let labels ← (StackMIR.labelSet (f.blocks.map (·.label)) "duplicate assembly label").mapError Error.invalid
  for block in f.blocks do
    if block.instructions.isEmpty then throw (.invalid "empty assembly block")
    let mut active := block.label != .entry || f.frameBytes == 0
    let mut left := false
    let mut flagsReady := false
    for index in [:block.instructions.size] do
      let some inst := block.instructions[index]? | throw (.invalid "missing assembly instruction")
      let last := index + 1 == block.instructions.size
      match inst with
      | .subSP bytes =>
        if block.label != .entry || index != 0 || active || bytes == 0 || bytes != f.frameBytes then
          throw (.invalid "invalid assembly prologue")
        active := true
      | .addSP bytes =>
        if !active || block.label == .entry || left || bytes == 0 || bytes != f.frameBytes ||
            index + 2 != block.instructions.size then throw (.invalid "invalid assembly epilogue")
        active := false
        left := true
      | .load width reg offset =>
        if !active || left || !writable reg then throw (.invalid "illegal load destination/frame phase")
        checkAccess f width offset
      | .store width reg offset =>
        if !active || left || !readable reg then throw (.invalid "illegal store source/frame phase")
        checkAccess f width offset
      | .movz width reg chunk shift | .movk width reg chunk shift =>
        if !active || left || !writable reg || chunk >= 65536 || shift % 16 != 0 || shift >= width.bits then
          throw (.invalid "illegal constant materialization")
      | .alu width op dst lhs rhs =>
        if !active || left || !writable dst || !readable lhs || !readable rhs then throw (.invalid "illegal ALU operands")
        checkALUWidth op width
      | .divide _ _ dst lhs rhs =>
        if !active || left || !writable dst || !readable lhs || !readable rhs then throw (.invalid "illegal division operands")
      | .msub _ dst lhs rhs addend =>
        if !active || left || !writable dst || !readable lhs || !readable rhs || !readable addend then
          throw (.invalid "illegal multiply-subtract operands")
      | .cmp _ lhs rhs =>
        if !active || left || !readable lhs || !readable rhs then throw (.invalid "illegal comparison operands")
        flagsReady := true
      | .cset reg _ =>
        if !active || left || !writable reg || !flagsReady then throw (.invalid "cset without local flags or illegal destination")
      | .cbnz reg target =>
        if !active || left || !readable reg || index + 2 != block.instructions.size ||
            target == .entry || !labels.contains target then throw (.invalid "illegal conditional branch")
        let some (.jump _) := block.instructions[index + 1]? | throw (.invalid "conditional branch must precede a jump")
      | .jump target =>
        if !last || !active || left || target == .entry || !labels.contains target then throw (.invalid "illegal jump")
      | .ret =>
        if !last || block.label == .entry || (f.frameBytes != 0 && (!left || active)) then
          throw (.invalid "return without frame restoration")
      if last then
        match inst with
        | .jump _ | .ret => pure ()
        | _ => throw (.invalid "assembly block has no terminal branch/return")

def labelName (symbol : String) : Label → String
  | .entry => s!"L_lcb_{symbol.length}_{symbol}_entry"
  | .body id => s!"L_lcb_{symbol.length}_{symbol}_body_{id}"
  | .edge pred target => s!"L_lcb_{symbol.length}_{symbol}_edge_{pred}_{target}"

private def register (width : Width) (index : Nat) : String :=
  (if width == .word then "w" else "x") ++ toString index

private def mnemonic (op : Source.Binary) : String :=
  explicit_op% match op with
  | .add => "add" | .sub => "sub" | .mul => "mul"
  | .andBits => "and" | .orBits => "orr" | .xorBits => "eor"
  | .shiftLeft => "lsl" | .logicalRight => "lsr" | .arithmeticRight => "asr"
  | .mulHighUnsigned => "umulh" | .mulHighSigned => "smulh"

def renderInstruction (symbol : String) : Instruction → String
  | .subSP bytes => s!"\tsub sp, sp, #{bytes}"
  | .addSP bytes => s!"\tadd sp, sp, #{bytes}"
  | .load width reg offset => s!"\tldr {register width reg}, [sp, #{offset}]"
  | .store width reg offset => s!"\tstr {register width reg}, [sp, #{offset}]"
  | .movz width reg chunk shift => s!"\tmovz {register width reg}, #{chunk}, lsl #{shift}"
  | .movk width reg chunk shift => s!"\tmovk {register width reg}, #{chunk}, lsl #{shift}"
  | .alu width op dst lhs rhs => s!"\t{mnemonic op} {register width dst}, {register width lhs}, {register width rhs}"
  | .divide width signed dst lhs rhs =>
    s!"\t{if signed then "sdiv" else "udiv"} {register width dst}, {register width lhs}, {register width rhs}"
  | .msub width dst lhs rhs addend =>
    s!"\tmsub {register width dst}, {register width lhs}, {register width rhs}, {register width addend}"
  | .cmp width lhs rhs => s!"\tcmp {register width lhs}, {register width rhs}"
  | .cset reg condition => s!"\tcset w{reg}, {condition.spelling}"
  | .cbnz reg target => s!"\tcbnz w{reg}, {labelName symbol target}"
  | .jump target => s!"\tb {labelName symbol target}"
  | .ret => "\tret"

/-- Selection and rendering agree on the X-register forms whose ALU values
    are related to source evaluation by `Machine.alu_preserves`. -/
theorem select_highMultiply (f : StackMIR.Function) (dst lhs rhs : StackMIR.Register) (symbol : String) :
    let unsigned := Instruction.alu .long .mulHighUnsigned dst.index lhs.index rhs.index
    let signed := Instruction.alu .long .mulHighSigned dst.index lhs.index rhs.index
    selectInstruction f (.alu .long .mulHighUnsigned dst lhs rhs) = .ok #[unsigned] ∧
    selectInstruction f (.alu .long .mulHighSigned dst lhs rhs) = .ok #[signed] ∧
    renderInstruction symbol unsigned = s!"\tumulh x{dst.index}, x{lhs.index}, x{rhs.index}" ∧
    renderInstruction symbol signed = s!"\tsmulh x{dst.index}, x{lhs.index}, x{rhs.index}" :=
  by
    refine ⟨rfl, rfl, ?_, ?_⟩ <;>
      cases dst <;> cases lhs <;> cases rhs <;> rfl

def blockLines (symbol : String) (block : Block) : List String :=
  (labelName symbol block.label ++ ":") :: block.instructions.toList.map (renderInstruction symbol)

private def renderLines (symbol : String) (blocks : Array Block) (header : List String) :
    List String :=
  blocks.foldl (fun lines block => lines ++ blockLines symbol block) header

private def renderLinesLinear (symbol : String) (blocks : Array Block) (header : List String) :
    List String :=
  header ++ blocks.toList.flatMap (blockLines symbol)

@[csimp] theorem renderLines_eq_linear : renderLines = renderLinesLinear := by
  funext symbol blocks header
  simp [renderLines, renderLinesLinear, ← Array.foldl_toList, List.flatMap]

def renderWithWork (f : Function) (symbol : Symbol) : Except Error (String × Nat) := do
  validate f
  let validName := !symbol.name.isEmpty && symbol.name.toList.all (fun c =>
    c.toNat < 128 && (c.isAlphanum || c == '_')) &&
    (symbol.name.toList.head!.isAlpha || symbol.name.toList.head! == '_')
  if !validName then throw (.invalid "invalid assembly symbol")
  let mut lines := [s!"; function {symbol.name}; uncertified typed stack baseline"]
  if symbol.exported then lines := lines ++ [s!".globl _{symbol.name}"]
  lines := lines ++ [".p2align 2", s!"_{symbol.name}:"]
  let rendered := renderLines symbol.name f.blocks lines
  pure (String.intercalate "\n" (rendered ++ [""]), rendered.length)

def render (f : Function) (symbol : Symbol) : Except Error String :=
  (renderWithWork f symbol).map Prod.fst

end LeanCompilerBackend.Verified.TypedA64
