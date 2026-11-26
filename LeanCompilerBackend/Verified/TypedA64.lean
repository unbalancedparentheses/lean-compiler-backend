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

private def permitsWord : Source.Binary → Bool
  | .add | .sub | .mul | .andBits | .orBits | .xorBits
  | .shiftLeft | .logicalRight | .arithmeticRight => true
  | .mulHighUnsigned | .mulHighSigned => false

inductive Instruction where
  | subSP (bytes : Nat)
  | addSP (bytes : Nat)
  | load (width : Width) (reg offset : Nat)
  | store (width : Width) (reg offset : Nat)
  | movz (width : Width) (reg chunk shift : Nat)
  | movk (width : Width) (reg chunk shift : Nat)
  | alu (width : Width) (op : Source.Binary) (dst lhs rhs : Nat)
      (validWidth : width = .long ∨ permitsWord op = true)
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

/-- Construct an ALU instruction or report the unencodable width. -/
def Instruction.checkedALU (width : Width) (op : Source.Binary) (dst lhs rhs : Nat) :
    Except Error Instruction :=
  if widthOK : width = .long ∨ permitsWord op = true then
    .ok (.alu width op dst lhs rhs widthOK)
  else .error (.unsupportedHighMultiplyWidth op width)

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
    pure #[← Instruction.checkedALU width op dst.index lhs.index rhs.index]
  | .compare width op dst lhs rhs =>
    pure #[.cmp width lhs.index rhs.index, .cset dst.index (match op with
      | .eq => .eq | .unsignedLT => .lo | .unsignedLE => .ls | .signedLT => .lt | .signedLE => .le)]
  | .divide width op dst lhs rhs =>
    let quotient (signed : Bool) := #[Instruction.divide width signed dst.index lhs.index rhs.index]
    -- MSUB reads both original operands again after the quotient is written.
    let remainder (signed : Bool) : Except Error (Array Instruction) :=
      if dst == lhs || dst == rhs then
        .error (.invalid "remainder destination must differ from its operands")
      else .ok ((quotient signed).push (.msub width dst.index dst.index rhs.index lhs.index))
    match op with
    | .signedDiv => .ok (quotient true)
    | .unsignedDiv => .ok (quotient false)
    | .signedRem => remainder true
    | .unsignedRem => remainder false

private def selectBlock (f : StackMIR.Function) (block : StackMIR.Block) : Except Error Block := do
  let chunks ← block.instructions.toList.mapM (selectInstruction f)
  let tail := match block.terminator with
    | .jump target => #[Instruction.jump target]
    | .branch reg yes no => #[Instruction.cbnz reg.index yes, Instruction.jump no]
    | .ret _ => #[Instruction.ret]
  pure { label := block.label, instructions := (chunks.flatMap Array.toList).toArray ++ tail }

def select (f : StackMIR.Function) : Except Error Function := do
  (StackMIR.validate f).mapError Error.invalid
  let blocks ← f.blocks.toList.mapM (selectBlock f)
  pure { parameters := f.parameters, resultWidth := f.resultWidth, frameBytes := f.layout.frameBytes,
         blocks := blocks.toArray }

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
      | .alu _ _ dst lhs rhs _ =>
        if !active || left || !writable dst || !readable lhs || !readable rhs then throw (.invalid "illegal ALU operands")
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
  match op with
  | .add => "add" | .sub => "sub" | .mul => "mul"
  | .andBits => "and" | .orBits => "orr" | .xorBits => "eor"
  | .shiftLeft => "lsl" | .logicalRight => "lsr" | .arithmeticRight => "asr"
  | .mulHighUnsigned => "umulh" | .mulHighSigned => "smulh"

private def renderInstruction (symbol : String) : Instruction → String
  | .subSP bytes => s!"\tsub sp, sp, #{bytes}"
  | .addSP bytes => s!"\tadd sp, sp, #{bytes}"
  | .load width reg offset => s!"\tldr {register width reg}, [sp, #{offset}]"
  | .store width reg offset => s!"\tstr {register width reg}, [sp, #{offset}]"
  | .movz width reg chunk shift => s!"\tmovz {register width reg}, #{chunk}, lsl #{shift}"
  | .movk width reg chunk shift => s!"\tmovk {register width reg}, #{chunk}, lsl #{shift}"
  | .alu width op dst lhs rhs _ => s!"\t{mnemonic op} {register width dst}, {register width lhs}, {register width rhs}"
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
    let unsigned := Instruction.alu .long .mulHighUnsigned dst.index lhs.index rhs.index (Or.inl rfl)
    let signed := Instruction.alu .long .mulHighSigned dst.index lhs.index rhs.index (Or.inl rfl)
    selectInstruction f (.alu .long .mulHighUnsigned dst lhs rhs) = .ok #[unsigned] ∧
    selectInstruction f (.alu .long .mulHighSigned dst lhs rhs) = .ok #[signed] ∧
    renderInstruction symbol unsigned = s!"\tumulh x{dst.index}, x{lhs.index}, x{rhs.index}" ∧
    renderInstruction symbol signed = s!"\tsmulh x{dst.index}, x{lhs.index}, x{rhs.index}" :=
  by
    refine ⟨rfl, rfl, ?_, ?_⟩ <;>
      cases dst <;> cases lhs <;> cases rhs <;> rfl

private def blockLines (symbol : String) (block : Block) : List String :=
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

private def header (symbol : Symbol) : List String :=
  [s!"; function {symbol.name}; uncertified typed stack baseline"] ++
  (if symbol.exported then [s!".globl _{symbol.name}"] else []) ++
  [".p2align 2", s!"_{symbol.name}:"]

private def validName (symbol : Symbol) : Bool :=
  !symbol.name.isEmpty && symbol.name.toList.all (fun c =>
    c.toNat < 128 && (c.isAlphanum || c == '_')) &&
    (symbol.name.toList.head!.isAlpha || symbol.name.toList.head! == '_')

def renderWithWork (f : Function) (symbol : Symbol) : Except Error (String × Nat) := do
  validate f
  if validName symbol then
    let rendered := renderLines symbol.name f.blocks (header symbol)
    .ok (String.intercalate "\n" (rendered ++ [""]), rendered.length)
  else .error (.invalid "invalid assembly symbol")

def render (f : Function) (symbol : Symbol) : Except Error String :=
  (renderWithWork f symbol).map Prod.fst

private theorem mapM_split {α β ε : Type} (f : α → Except ε β)
    (before after : List α) (x : α) (ys : List β)
    (h : (before ++ x :: after).mapM f = .ok ys) :
    ∃ pre y post, before.mapM f = .ok pre ∧ f x = .ok y ∧ after.mapM f = .ok post ∧
      ys = pre ++ y :: post := by
  rw [List.mapM_append, List.mapM_cons] at h
  cases hp : before.mapM f <;> cases hx : f x <;> cases hs : after.mapM f <;>
    simp_all [Bind.bind, Except.bind, Pure.pure, Except.pure]

private theorem selectBlock_label (f : StackMIR.Function) (b : StackMIR.Block) (out : Block)
    (h : selectBlock f b = .ok out) : out.label = b.label := by
  unfold selectBlock at h
  cases hmap : b.instructions.toList.mapM (selectInstruction f) <;>
    simp_all [Bind.bind, Except.bind, Pure.pure, Except.pure]
  subst out
  rfl

private theorem selectBlock_find_none (f : StackMIR.Function) (label : Label)
    (before : List StackMIR.Block) (out : List Block)
    (h : before.mapM (selectBlock f) = .ok out)
    (noneBefore : before.find? (·.label == label) = none) :
    out.find? (·.label == label) = none := by
  induction before generalizing out with
  | nil => simp_all [Pure.pure, Except.pure]
  | cons b bs ih =>
    rw [List.mapM_cons] at h
    cases hb : selectBlock f b <;> cases hs : bs.mapM (selectBlock f) <;>
      simp [hb, hs, Bind.bind, Except.bind, Pure.pure, Except.pure] at h
    rename_i selected tail
    subst out
    have same := selectBlock_label f b selected hb
    have tailNone := ih tail hs (List.find?_eq_none.mpr fun a ha =>
      List.find?_eq_none.mp noneBefore a (List.mem_cons_of_mem _ ha))
    rw [List.find?_cons, same]
    have no := List.find?_eq_none.mp noneBefore b (by simp)
    simp [Bool.eq_false_iff.mpr no, tailNone]

/-- Locate the singleton high multiply in selection and in the checked
    renderer's complete output. The local instruction offset counts selected
    instructions, so zero- and multi-instruction expansions are included. -/
theorem select_render_highMultiply (f : StackMIR.Function) (assembly : Function)
    (symbol : Symbol) (fragment : String) (block : StackMIR.Block)
    (earlier later : List StackMIR.Block) (before after : List StackMIR.Instruction)
    (chunks : List (Array Instruction)) (dst lhs rhs : StackMIR.Register) (signed : Bool)
    (blocks : f.blocks.toList = earlier ++ block :: later)
    (first : earlier.find? (·.label == block.label) = none)
    (instructions : block.instructions.toList = before ++
      .alu .long (if signed then .mulHighSigned else .mulHighUnsigned) dst lhs rhs :: after)
    (prefixSelected : before.mapM (selectInstruction f) = .ok chunks)
    (selected : select f = .ok assembly) (rendered : render assembly symbol = .ok fragment) :
    let offset := (chunks.flatMap Array.toList).length
    ∃ target preceding localPrefix textAfter,
      assembly.blocks.find? (·.label == block.label) = some target ∧
      target.instructions[offset]? =
        some (.alu .long (if signed then .mulHighSigned else .mulHighUnsigned)
          dst.index lhs.index rhs.index (Or.inl rfl)) ∧
      fragment = String.intercalate "\n" (preceding ++ [labelName symbol.name block.label ++ ":"] ++
        localPrefix ++
        s!"\t{if signed then "smulh" else "umulh"} x{dst.index}, x{lhs.index}, x{rhs.index}" :: textAfter) ∧
      localPrefix.length = offset := by
  dsimp only
  unfold select at selected
  rw [blocks] at selected
  cases hv : (StackMIR.validate f).mapError Error.invalid <;>
    simp only [hv, Bind.bind, Except.bind, Pure.pure, Except.pure] at selected
  · contradiction
  cases hm : (earlier ++ block :: later).mapM (selectBlock f) <;> rw [hm] at selected
  · contradiction
  rename_i result mapped
  cases selected
  obtain ⟨pre, target, post, hp, ht, hs, rfl⟩ := mapM_split _ _ _ _ _ hm
  have found := selectBlock_find_none f block.label earlier pre hp first
  have label := selectBlock_label f block target ht
  let op : Source.Binary := if signed then .mulHighSigned else .mulHighUnsigned
  let inst := Instruction.alu .long op dst.index lhs.index rhs.index (Or.inl rfl)
  have opcode : selectInstruction f (.alu .long op dst lhs rhs) = .ok #[inst] := by
    cases signed <;> rfl
  have line : renderInstruction symbol.name inst =
      s!"\t{if signed then "smulh" else "umulh"} x{dst.index}, x{lhs.index}, x{rhs.index}" := by
    cases signed <;> cases dst <;> cases lhs <;> cases rhs <;> rfl
  obtain ⟨remaining, code⟩ : ∃ remaining, target.instructions.toList =
      chunks.flatMap Array.toList ++ inst :: remaining := by
    change block.instructions.toList =
      before ++ StackMIR.Instruction.alu .long op dst lhs rhs :: after at instructions
    unfold selectBlock at ht
    rw [instructions, List.mapM_append, List.mapM_cons, prefixSelected, opcode] at ht
    cases ha : after.mapM (selectInstruction f) <;>
      simp [ha, Bind.bind, Except.bind, Pure.pure, Except.pure] at ht
    subst target
    simp [List.append_assoc]
  let preceding := header symbol ++ pre.flatMap (blockLines symbol.name)
  let localPrefix := (chunks.flatMap Array.toList).map (renderInstruction symbol.name)
  let textAfter := remaining.map (renderInstruction symbol.name) ++
    post.flatMap (blockLines symbol.name) ++ [""]
  refine ⟨target, preceding, localPrefix, textAfter, ?_, ?_, ?_, by simp [localPrefix]⟩
  · simp [found, label]
  · rw [← Array.getElem?_toList, code]
    simp [inst, op]
  · unfold render renderWithWork at rendered
    cases hv : validate ({ parameters := f.parameters, resultWidth := f.resultWidth,
                           frameBytes := f.layout.frameBytes, blocks := (pre ++ target :: post).toArray } : Function) <;>
      simp only [hv, Bind.bind, Except.bind] at rendered
    · contradiction
    by_cases nameOK : validName symbol = true
    · simp [nameOK, Except.map] at rendered
      rw [← rendered, renderLines_eq_linear]
      simp [renderLinesLinear, blockLines, code, preceding, localPrefix, textAfter, label, line,
        List.append_assoc]
    · simp [nameOK, Except.map] at rendered

end LeanCompilerBackend.Verified.TypedA64
