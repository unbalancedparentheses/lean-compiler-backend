/- Baseline Linux/macOS AMD64/System V lowering. ABI reference: pinned QBE amd64/sysv.c.
   Baseline values use unique stack slots; optional allocation uses checked
   target-admitted GP homes and reusable spill slots (including floating bit patterns). -/
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.Selection
import LeanCompilerBackend.Allocation
import LeanCompilerBackend.Assembly
import LeanCompilerBackend.AMD64ABI

namespace LeanCompilerBackend.AMD64

open AMD64ABI

private def align (n : Nat) : Nat := (n + 15) / 16 * 16
private def suffix (w : Width) : String := if w == .word then "l" else "q"
private def fsuffix (w : Width) : String := if w == .word then "ss" else "sd"
private def reg (w : Width) (r : String) : String :=
  "%" ++ if w == .long then r else match r with
    | "rax" => "eax" | "rcx" => "ecx" | "rdx" => "edx"
    | "rdi" => "edi" | "rsi" => "esi" | "rbx" => "ebx" | _ => r ++ "d"
private def gp : Array String := #["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

private def savedGP : Array String := #["rbx", "r12", "r13", "r14", "r15"]

private structure Context where
  darwin : Bool
  slots : Std.HashMap String Nat
  registers : Std.HashMap String String
  objects : List (String × Nat)
  types : Array AMD64ABI.Info
  resultPointer : Nat
  locals : List String
  stage : Nat
  saveArea : Nat
  stackArgs : Nat
  gpUsed : Nat
  fpUsed : Nat

private def slot (c : Context) (name : String) : Except String String := do
  let some offset := c.slots[name]? | throw s!"missing AMD64 stack slot %{name}"
  pure s!"-{offset}(%rbp)"

private def store (c : Context) (name : String) : Except String (List String) := do
  if let some r := c.registers[name]? then return [s!"\tmovq %rax, %{r}"]
  return [s!"\tmovq %rax, {← slot c name}"]

/-- ELF TLSDESC or Darwin TLV lookup, preserving live GP/FP call arguments. -/
private def threadAddress (darwin : Bool) (w : Width) (destination name : String) : List String := Id.run do
  let saved := #["rax", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11"]
  let mut lines := ["\tsubq $224, %rsp"]
  for i in [:saved.size] do lines := lines ++ [s!"\tmovq %{saved[i]!}, {i*8}(%rsp)"]
  for i in [:8] do lines := lines ++ [s!"\tmovdqu %xmm{i}, {80+i*16}(%rsp)"]
  let symbol := Assembly.symbolName darwin name
  lines := lines ++ (if darwin then
    [s!"\tmovq {symbol}@TLVP(%rip), %rdi", "\tcall *(%rdi)"]
    else [s!"\tleaq {symbol}@TLSDESC(%rip), %rax", s!"\tcall *{symbol}@TLSCALL(%rax)", "\taddq %fs:0, %rax"])
  lines := lines ++ ["\tmovq %rax, 208(%rsp)"]
  for i in [:saved.size] do lines := lines ++ [s!"\tmovq {i*8}(%rsp), %{saved[i]!}"]
  for i in [:8] do lines := lines ++ [s!"\tmovdqu {80+i*16}(%rsp), %xmm{i}"]
  lines := lines ++ [s!"\tmovq 208(%rsp), %{destination}", "\taddq $224, %rsp"]
  if w == .word then lines := lines ++ [s!"\tmovl {reg .word destination}, {reg .word destination}"]
  return lines

private def load (c : Context) (w : Width) (r : String) : Operand → Except String (List String)
  | .constant n => pure [s!"\tmov{if w == .long then "absq" else "l"} ${Semantics.constant w n}, {reg w r}"]
  | .temporary name => do
    if let some home := c.registers[name]? then
      return [s!"\tmov{suffix w} {reg w home}, {reg w r}"]
    return [s!"\tmov{suffix w} {← slot c name}, {reg w r}"]
  | .symbol name =>
    let symbol := Assembly.symbolName c.darwin name
    let address := if c.locals.contains name then s!"\tleaq {symbol}(%rip), %{r}"
      else s!"\tmovq {symbol}@GOTPCREL(%rip), %{r}"
    pure ([address] ++ if w == .word then [s!"\tmovl {reg .word r}, {reg .word r}"] else [])
  | .threadSymbol name => pure (threadAddress c.darwin w r name)

private def extend (w : Width) : Unary → List String
  | .negate => [s!"\tneg{suffix w} {reg w "rax"}"]
  | .signedByte => [s!"\tmovsb{suffix w} %al, {reg w "rax"}"]
  | .unsignedByte => ["\tmovzbl %al, %eax"]
  | .signedHalf => [s!"\tmovsw{suffix w} %ax, {reg w "rax"}"]
  | .unsignedHalf => ["\tmovzwl %ax, %eax"]
  | .signedWord => if w == .long then ["\tmovslq %eax, %rax"] else ["\tmovl %eax, %eax"]
  | .unsignedWord => ["\tmovl %eax, %eax"]

private def objectAddress (c : Context) (name r : String) : Except String (List String) := do
  let some offset := c.objects.lookup name | throw s!"missing AMD64 aggregate object %{name}"
  pure [s!"\tleaq -{offset}(%rbp), %{r}"]

/-- Exact-width transfer: r10 addresses the object; r11 is scratch. -/
private def readFragment (destination : String) (offset bytes : Nat) : List String := Id.run do
  if bytes == 8 then return [s!"\tmovq {offset}(%r10), %{destination}"]
  if bytes == 4 then return [s!"\tmovl {offset}(%r10), {reg .word destination}"]
  let mut lines := [s!"\txorq %{destination}, %{destination}"]
  for i in [:bytes] do
    lines := lines ++ [s!"\tmovzbq {offset+i}(%r10), %r11"]
    if i != 0 then lines := lines ++ [s!"\tshlq ${i*8}, %r11"]
    lines := lines ++ [s!"\torq %r11, %{destination}"]
  return lines

private def writeFragment (source : String) (offset bytes : Nat) : List String := Id.run do
  if bytes == 8 then return [s!"\tmovq %{source}, {offset}(%r10)"]
  if bytes == 4 then return [s!"\tmovl {reg .word source}, {offset}(%r10)"]
  let mut lines := [s!"\tmovq %{source}, %r11"]
  for i in [:bytes] do
    lines := lines ++ [s!"\tmovb %r11b, {offset+i}(%r10)"]
    if i+1 < bytes then lines := lines ++ ["\tshrq $8, %r11"]
  return lines

/-- Copy forward from r10 to r11, preserving bases and ABI argument registers.
    Large copies use reserved caller-saved XMM15 as raw data scratch. -/
private def copyBytes (bytes : Nat) : List String := Id.run do
  if bytes > 128 then
    -- XMM15 is caller-saved, outside XMM0..7 arguments, and never an allocated home.
    -- RAX is already scratch here; emitCall sets AL/environment only after copies.
    let full := bytes / 8 * 8
    let mut lines := ["\txorq %rax, %rax", "8:",
      "\tmovq (%r10,%rax), %xmm15", "\tmovq %xmm15, (%r11,%rax)",
      "\taddq $8, %rax", s!"\tcmpq ${full}, %rax", "\tjb 8b"]
    for i in [full:bytes] do
      lines := lines ++ [s!"\tmovb {i}(%r10), %al", s!"\tmovb %al, {i}(%r11)"]
    return lines
  let mut lines := []
  for i in [:bytes/8] do
    lines := lines ++ [s!"\tmovq {i*8}(%r10), %rax", s!"\tmovq %rax, {i*8}(%r11)"]
  for i in [bytes/8*8:bytes] do
    lines := lines ++ [s!"\tmovb {i}(%r10), %al", s!"\tmovb %al, {i}(%r11)"]
  return lines

private def returnChunks (info : Info) : Array (Bool × String × Nat) := Id.run do
  let mut ngp := 0
  let mut nfp := 0
  let mut chunks := #[]
  for i in [:info.classes.size] do
    match info.classes[i]! with
    | .integer => chunks := chunks.push (false, if ngp == 0 then "rax" else "rdx", i*8); ngp := ngp+1
    | .floating => chunks := chunks.push (true,s!"xmm{nfp}",i*8); nfp := nfp+1
    | .empty => pure ()
  return chunks

private def emitCall (c : Context) (target : CallTarget) (args : Array CallArgument) (result : Option (String × String) := none) (variadicCall : Bool := false) : Except String (List String) := do
  let resultInfo ← result.mapM (fun (_, name) => AMD64ABI.find c.types name)
  let p ← plan c.types args (resultInfo.any (·.memory)) variadicCall
  let bytes := align p.stackBytes
  if bytes > 1024 * 1024 then throw "AMD64 outgoing argument area exceeds 1 MiB"
  let mut lines := if bytes != 0 then [s!"\tsubq ${bytes}, %rsp"] else []
  for i in [:args.size] do
    let arg := args[i]!
    if arg.environment then continue
    if let some name := arg.aggregate then
      let info ← AMD64ABI.find c.types name
      lines := lines ++ (← load c .long "r10" arg.value)
      match p.places[i]! with
      | .aggregate chunks =>
        for (floating,index,offset) in chunks do
          let destination := if floating then "rax" else gp[index]!
          lines := lines ++ readFragment destination offset (min 8 (info.layout.size-offset))
          if floating then lines := lines ++ [s!"\tmovq %rax, %xmm{index}"]
      | .stack offset => lines := lines ++ [s!"\tleaq {offset}(%rsp), %r11"] ++ copyBytes info.layout.size
      | _ => throw "invalid AMD64 aggregate argument location"
      continue
    lines := lines ++ (← load c arg.width "rax" arg.value)
    if let some kind := arg.subword then lines := lines ++ extend .word kind.extension
    match p.places[i]! with
    | .integer index => lines := lines ++ [s!"\tmovq %rax, %{gp[index]!}"]
    | .floating index => lines := lines ++ [s!"\tmov{if arg.width == .word then "d" else "q"} {reg arg.width "rax"}, %xmm{index}"]
    | .stack offset => lines := lines ++ [s!"\tmovq %rax, {offset}(%rsp)"]
    | .environment => pure ()
    | .aggregate _ => throw "scalar argument in aggregate registers"
  if let some (destination, _) := result then
    if resultInfo.any (·.memory) then lines := lines ++ (← objectAddress c destination "rdi")
  if let .indirect address := target then lines := lines ++ (← load c .long "r11" address)
  if let some arg := args.find? (·.environment) then lines := lines ++ (← load c .long "rax" arg.value)
  else if variadicCall || args.any (·.variadic) then lines := lines ++ [s!"\tmovl ${p.nfp}, %eax"]
  lines := lines ++ [match target with | .direct name => s!"\tcall {Assembly.symbolName c.darwin name}" | .indirect _ => "\tcall *%r11"]
  if bytes != 0 then lines := lines ++ [s!"\taddq ${bytes}, %rsp"]
  if let some (destination, _) := result then
    let some info := resultInfo | throw "missing AMD64 result classification"
    lines := lines ++ (← objectAddress c destination "r10")
    if !info.memory then
      for (floating,source,offset) in returnChunks info do
        if floating then lines := lines ++ [s!"\tmovq %{source}, %rcx"]
        lines := lines ++ writeFragment (if floating then "rcx" else source) offset (min 8 (info.layout.size-offset))
    lines := lines ++ ["\tmovq %r10, %rax"]
  pure lines

private def condition : Comparison → String
  | .eq => "e" | .ne => "ne" | .signedLE => "le" | .signedLT => "l" | .signedGE => "ge" | .signedGT => "g"
  | .unsignedLE => "be" | .unsignedLT => "b" | .unsignedGE => "ae" | .unsignedGT => "a"

private def inverseCondition : Comparison → String
  | .eq => "ne" | .ne => "e" | .signedLE => "g" | .signedLT => "ge" | .signedGE => "l" | .signedGT => "le"
  | .unsignedLE => "a" | .unsignedLT => "ae" | .unsignedGE => "b" | .unsignedGT => "be"

private def comparisonFlags (c : Context) (width : Width) (x y : Operand)
    : Except String (List String) := do
  return (← load c width "rax" x) ++ (← load c width "rcx" y) ++
    [s!"\tcmp{suffix width} {reg width "rcx"}, {reg width "rax"}"]

/-- Arithmetic immediates are sign-extended from 32 bits in long operations.
    Word operations accept every low-32-bit pattern. Shift counts have exactly
    the same modulo-width semantics as the existing register-count form. -/
private def binaryImmediate (w : Width) (op : Binary) (n : Int) : Option String := do
  let s := suffix w
  let destination := reg w "rax"
  let value := Semantics.signedBits w.bits (Semantics.constant w n)
  let shift := (Semantics.constant (op.rhsWidth w) n).toNat % w.bits
  match op with
  | .shiftLeft => return s!"\tshl{s} ${shift}, {destination}"
  | .logicalRight => return s!"\tshr{s} ${shift}, {destination}"
  | .arithmeticRight => return s!"\tsar{s} ${shift}, {destination}"
  | _ => pure ()
  if value < -(2 ^ 31 : Int) || value >= 2 ^ 31 then none
  else
    match op with
    | .mul => some s!"\timul{s} ${value}, {destination}, {destination}"
    | .add => some s!"\tadd{s} ${value}, {destination}"
    | .sub => some s!"\tsub{s} ${value}, {destination}"
    | .andBits => some s!"\tand{s} ${value}, {destination}"
    | .orBits => some s!"\tor{s} ${value}, {destination}"
    | .xorBits => some s!"\txor{s} ${value}, {destination}"
    | _ => none

private def emitInstruction (c : Context) (inst : Instruction) : Except String (List String) := do
  let w := inst.width
  let s := suffix w
  let a := reg w "rax"
  let b := reg w "rcx"
  let mut lines := []
  match inst.operation with
  | .copy x | .cast x => lines := ← load c w "rax" x
  | .binary op x y =>
    let immediate := match y with
      | .constant n => binaryImmediate w op n
      | _ => none
    lines := ← load c w "rax" x
    if let some instruction := immediate then
      lines := lines ++ [instruction]
    else
      lines := lines ++ (← load c (op.rhsWidth w) "rcx" y)
      let mnemonic := match op with
        | .add => "add" | .sub => "sub" | .mul => "imul" | .andBits => "and" | .orBits => "or" | .xorBits => "xor"
        | .shiftLeft => "shl" | .logicalRight => "shr" | .arithmeticRight => "sar"
      let operand := match op with | .shiftLeft | .logicalRight | .arithmeticRight => "%cl" | _ => b
      lines := lines ++ [s!"\t{mnemonic}{s} {operand}, {a}"]
  | .unary op x => lines := (← load c (op.inputWidth w) "rax" x) ++ extend w op
  | .divide op x y =>
    lines := (← load c w "rax" x) ++ (← load c w "rcx" y)
    let signed := op == .signedDiv || op == .signedRem
    lines := lines ++ (if signed then [if w == .long then "\tcqto" else "\tcltd"] else ["\txorl %edx, %edx"])
      ++ [s!"\t{if signed then "idiv" else "div"}{s} {b}"]
    if op == .signedRem || op == .unsignedRem then lines := lines ++ [s!"\tmov{s} {reg w "rdx"}, {a}"]
  | .compare op width x y =>
    lines := (← comparisonFlags c width x y) ++ [s!"\tset{condition op} %al", "\tmovzbl %al, %eax"]
  | .floatBinary op x y =>
    lines := (← load c w "rax" x) ++ (← load c w "rcx" y) ++
      [s!"\tmov{if w == .word then "d" else "q"} {a}, %xmm0", s!"\tmov{if w == .word then "d" else "q"} {b}, %xmm1"]
    let mnemonic := match op with | .add => "add" | .sub => "sub" | .mul => "mul" | .div => "div"
    lines := lines ++ [s!"\t{mnemonic}{fsuffix w} %xmm1, %xmm0", s!"\tmov{if w == .word then "d" else "q"} %xmm0, {a}"]
  | .floatNegate x =>
    lines := (← load c w "rax" x) ++ (← load c w "rcx" (.constant (2^(w.bits-1)))) ++ [s!"\txor{s} {b}, {a}"]
  | .floatCompare op width x y =>
    let r := reg width "rax"
    let t := reg width "rcx"
    let m := if width == .word then "d" else "q"
    lines := (← load c width "rax" x) ++ (← load c width "rcx" y) ++
      [s!"\tmov{m} {r}, %xmm0", s!"\tmov{m} {t}, %xmm1", s!"\tucomi{fsuffix width} %xmm1, %xmm0"]
    lines := lines ++ (match op with
      | .eq => ["\tsete %al", "\tsetnp %cl", "\tandb %cl, %al"]
      | .ne => ["\tsetne %al", "\tsetp %cl", "\torb %cl, %al"]
      | .lt => ["\tsetb %al", "\tsetnp %cl", "\tandb %cl, %al"]
      | .le => ["\tsetbe %al", "\tsetnp %cl", "\tandb %cl, %al"]
      | .gt => ["\tseta %al"] | .ge => ["\tsetae %al"]
      | .ordered => ["\tsetnp %al"] | .unordered => ["\tsetp %al"])
      ++ ["\tmovzbl %al, %eax"]
  | .convert op x =>
    let input := op.inputWidth
    lines := ← load c input "rax" x
    if op.inputFloating then lines := lines ++ [s!"\tmov{if input == .word then "d" else "q"} {reg input "rax"}, %xmm0"]
    match op with
    | .extendSingle => lines := lines ++ ["\tcvtss2sd %xmm0, %xmm0"]
    | .truncateDouble => lines := lines ++ ["\tcvtsd2ss %xmm0, %xmm0"]
    | .toInteger _ signed =>
      let cvt := s!"\tcvtt{fsuffix input}2si{if !signed || w == .long then "q" else "l"} %xmm0, {if !signed then "%rax" else a}"
      if signed || w == .word then lines := lines ++ [cvt]
      else
        let bits := if input == .word then 1593835520 else 4890909195324358656
        lines := lines ++ (← load c input "rcx" (.constant bits)) ++
          [s!"\tmov{if input == .word then "d" else "q"} {reg input "rcx"}, %xmm1",
           s!"\tucomi{fsuffix input} %xmm1, %xmm0", "\tjb 1f", s!"\tsub{fsuffix input} %xmm1, %xmm0",
           cvt, "\tbtcq $63, %rax", "\tjmp 2f", "1:", cvt, "2:"]
    | .fromInteger _ signed =>
      let cvt := s!"\tcvtsi2{fsuffix w}{if !signed || input == .long then "q" else "l"} {if !signed then "%rax" else reg input "rax"}, %xmm0"
      if signed || input == .word then lines := lines ++ [cvt]
      else lines := lines ++ ["\ttestq %rax, %rax", "\tjns 1f", "\tmovq %rax, %rcx", "\tandl $1, %ecx",
        "\tshrq $1, %rax", "\torq %rcx, %rax", cvt, s!"\tadd{fsuffix w} %xmm0, %xmm0", "\tjmp 2f", "1:", cvt, "2:"]
    if op.resultFloating then lines := lines ++ [s!"\tmov{if w == .word then "d" else "q"} %xmm0, {a}"]
  | .allocate _ size =>
    lines := (← load c .long "rax" size) ++ ["\taddq $15, %rax", "\tandq $-16, %rax", "\tsubq %rax, %rsp", "\tmovq %rsp, %rax"]
  | .load kind address =>
    lines := ← load c .long "rax" address
    let instruction := match kind with
      | .signedByte => s!"movsb{s}" | .unsignedByte => "movzbl"
      | .signedHalf => s!"movsw{s}" | .unsignedHalf => "movzwl"
      | .signedWord => if w == Width.long then "movslq" else "movl"
      | .unsignedWord => "movl" | .plain => "mov" ++ s
    let destination := if kind == .unsignedByte || kind == .unsignedHalf || kind == .unsignedWord then "%eax" else a
    lines := lines ++ [s!"\t{instruction} (%rax), {destination}"]
  | .call target args variadic =>
    lines := ← emitCall c target args (inst.callAggregate.map (inst.destination, ·)) variadic
    if inst.floating then lines := lines ++ [s!"\tmov{if w == .word then "d" else "q"} %xmm0, {a}"]
    if let some kind := inst.callSubword then lines := lines ++ extend .word kind.extension
  | .vaArg list =>
    lines := ← load c .long "rax" list
    let field := if inst.floating then 4 else 0
    let limit := if inst.floating then 176 else 48
    let step := if inst.floating then 16 else 8
    lines := lines ++ [s!"\tmovl {field}(%rax), %ecx", s!"\tcmpl ${limit}, %ecx", "\tjae 1f", "\tmovq 16(%rax), %rdx",
      "\taddq %rcx, %rdx", s!"\taddl ${step}, %ecx", s!"\tmovl %ecx, {field}(%rax)", "\tjmp 2f", "1:",
      "\tmovq 8(%rax), %rdx", "\tleaq 8(%rdx), %rcx", "\tmovq %rcx, 8(%rax)", "2:", s!"\tmov{s} (%rdx), {a}"]
  -- These paths write EAX, or use load's explicit word normalization for
  -- symbols/TLS. Keep call/allocation/conversion and other paths conservative.
  let normalized := match inst.operation with
    | .copy .. | .cast .. | .binary .. | .unary .. | .load .. => true
    | _ => false
  if w == .word && !normalized then lines := lines ++ ["\tmovl %eax, %eax"]
  pure (lines ++ (← store c inst.destination))

private def emitStatement (c : Context) : Statement → Except String (List String)
  | .assign inst => emitInstruction c inst
  | .callVoid target args variadic => emitCall c target args none variadic
  | .storeFloat width value address => do
    return (← load c .long "r10" address) ++ (← load c width "rax" value) ++ [s!"\tmov{suffix width} {reg width "rax"}, (%r10)"]
  | .store width value address => do
    let (s, r) := match width with | .byte => ("b", "%al") | .half => ("w", "%ax") | .word => ("l", "%eax") | .long => ("q", "%rax")
    return (← load c .long "r10" address) ++ (← load c width.valueWidth "rax" value) ++ [s!"\tmov{s} {r}, (%r10)"]
  | .blit source destination bytes => do
    if bytes == 0 then return []
    let mut lines := (← load c .long "r10" source) ++ (← load c .long "r11" destination)
    let remaining := if bytes > 128 then bytes % 8 else bytes
    if bytes > 128 then
      lines := lines ++ [s!"\tmovq ${bytes / 8}, %rcx", "1:",
        "\tmovq (%r10), %rax", "\tmovq %rax, (%r11)",
        "\taddq $8, %r10", "\taddq $8, %r11", "\tsubq $1, %rcx", "\tjne 1b"]
    for offset in [0:remaining / 8] do
      lines := lines ++ [s!"\tmovq {offset*8}(%r10), %rax", s!"\tmovq %rax, {offset*8}(%r11)"]
    for offset in [remaining / 8 * 8:remaining] do
      lines := lines ++ [s!"\tmovb {offset}(%r10), %al", s!"\tmovb %al, {offset}(%r11)"]
    pure lines
  | .vaStart list => do
    return (← load c .long "rax" list) ++ [s!"\tmovl ${c.gpUsed*8}, (%rax)", s!"\tmovl ${48+c.fpUsed*16}, 4(%rax)",
      s!"\tleaq {16+c.stackArgs}(%rbp), %rcx", "\tmovq %rcx, 8(%rax)", s!"\tleaq -{c.saveArea}(%rbp), %rcx", "\tmovq %rcx, 16(%rax)"]

/-- Fuse only an adjacent long address definition with its sole SSA use.
    The original allocation remains valid: no instruction between the base use
    and memory access can replace its home. AMD64 displacements are signed32. -/
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
  if offset < -2147483648 || offset > 2147483647 then return none
  match second with
  | .assign inst =>
    let .load kind _ := inst.operation | return none
    let w := inst.width
    let s := suffix w
    let instruction := match kind with
      | .signedByte => s!"movsb{s}" | .unsignedByte => "movzbl"
      | .signedHalf => s!"movsw{s}" | .unsignedHalf => "movzwl"
      | .signedWord => if w == Width.long then "movslq" else "movl"
      | .unsignedWord => "movl" | .plain => "mov" ++ s
    let destination := if kind == .unsignedByte || kind == .unsignedHalf || kind == .unsignedWord then "%eax" else reg w "rax"
    let lines ← load c .long "rax" pointer
    -- Every word-result load above writes EAX, which already clears RAX's
    -- upper half, including raw single-precision floating bits. Keep the
    -- original signed/unsigned opcode and long-result behavior unchanged.
    return some (lines ++ [s!"\t{instruction} {offset}(%rax), {destination}"] ++
      (← store c inst.destination))
  | .store width value _ =>
    let (s, r) := match width with | .byte => ("b", "%al") | .half => ("w", "%ax") | .word => ("l", "%eax") | .long => ("q", "%rax")
    -- Materializing the value preserves r10, including TLS resolution.
    -- Allocated homes remain outside the reserved scratch bank.
    return some ((← load c .long "r10" pointer) ++ (← load c width.valueWidth "rax" value) ++
      [s!"\tmov{s} {r}, {offset}(%r10)"])
  | .storeFloat width value _ =>
    return some ((← load c .long "r10" pointer) ++ (← load c width "rax" value) ++
      [s!"\tmov{suffix width} {reg width "rax"}, {offset}(%r10)"])
  | _ => return none

private def label (darwin : Bool) (f : Function) (name : String) : String := s!"{if darwin then "L" else ".L"}_lcb_{f.name.length}_{Assembly.localName f.name}_{name}"
private def edge (c : Context) (f : Function) (source target : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == target) | throw "missing edge target"
  let mut lines := []
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_, value) := phi.incoming.find? (·.1 == source) | throw "missing phi incoming"
    lines := lines ++ (← load c phi.width "rax" value) ++ [s!"\tmovq %rax, -{c.stage+i*8}(%rbp)"]
  for i in [:block.phis.size] do
    lines := lines ++ [s!"\tmovq -{c.stage+i*8}(%rbp), %rax"] ++ (← store c block.phis[i]!.destination)
  pure lines

private def leafGP : Array String := savedGP ++ #["r8", "r9"]

/-- No explicit calls or TLS materialization in any operand context. -/
def leafBankEligible (f : Function) : Bool :=
  let tls := fun v => match v with | Operand.threadSymbol _ => true | _ => false
  !(f.blocks.any fun b =>
    b.instructions.any (fun s => s.callSite.isSome || s.operands.any tls) ||
    b.phis.any (fun p => p.incoming.any (fun (_,v) => tls v)) ||
    match b.terminator with
    | .ret (some v) | .branch v .. => tls v
    | _ => false)

private def parameterArguments (f : Function) : Array CallArgument :=
  f.parameters.map fun p => { width := p.width, value := Operand.temporary p.name, floating := p.floating, subword := p.subword, environment := p.environment, aggregate := p.aggregate }

/-- Check physical homes independently of allocation. Recompute the incoming ABI
    plan: an early home write must not overwrite a later named r8/r9 argument.
    Hidden result pointers and aggregate rollback are included by the ABI plan.
    Variadic argument banks are saved before any home write. -/
def checkPhysicalBank (f : Function) (types : Array Info) (bank : Array String) : Except String Unit := do
  if bank == savedGP then return ()
  if bank != leafGP then throw "AMD64 physical register bank is not supported"
  if !leafBankEligible f then throw "AMD64 caller-saved bank requires a call-free TLS-free function"
  let resultInfo ← f.resultAggregate.mapM (AMD64ABI.find types)
  let incoming ← plan types (parameterArguments f) (resultInfo.any (·.memory))
  if incoming.ngp > 4 then throw "AMD64 caller-saved bank overlaps incoming GP arguments"

private def emitFunction (f : Function) (types : Array Info) (locals : List String) (fileId : Nat) (darwin : Bool) (allocate : Bool) : Except String String := do
  validateFunction f true
  Assembly.checkTargetSection darwin f.customSection
  -- RAX carries the environment while AL carries the variadic FP count.
  -- An unused environment needs no binding, so ordinary variadic callers can
  -- use this definition. Keep used environments and explicit variadic env
  -- call sites outside the supported AMD64 ABI domain.
  let f ← if f.variadic && f.parameters.any (·.environment) then
      match calleeForEnvironment f false with
      | .ok ordinary => pure ordinary
      | .error _ => throw "AMD64 System V does not support variadic functions with a used environment parameter"
    else pure f
  let resultInfo ← f.resultAggregate.mapM (AMD64ABI.find types)
  let params := parameterArguments f
  let incoming ← plan types params (resultInfo.any (·.memory))
  let bank := if allocate && leafBankEligible f && incoming.ngp <= 4 then leafGP else savedGP
  checkPhysicalBank f types bank
  let homes ← if allocate then Allocation.allocate f bank.size else pure (Allocation.baseline f)
  let saved := savedGP.extract 0 (min homes.registers savedGP.size)
  let maxPhi := f.blocks.foldl (fun n b => max n b.phis.size) 0
  let mut fixed := (homes.spills + maxPhi)*8
  let savedBase := fixed+8
  fixed := fixed+saved.size*8
  let resultPointer := fixed + 8
  if resultInfo.any (·.memory) then fixed := fixed+8
  let mut objects := []
  let aggregateObjects := f.parameters.filterMap (fun p => p.aggregate.map (p.name, ·)) ++
    f.blocks.foldl (fun result b => result ++ b.instructions.filterMap (fun statement =>
      match statement with | .assign inst => inst.callAggregate.map (inst.destination, ·) | _ => none)) #[]
  for (name,typeName) in aggregateObjects do
    let info ← AMD64ABI.find types typeName
    let alignment := max 8 info.layout.alignment
    fixed := (fixed + max info.layout.size 1 + alignment-1)/alignment*alignment
    objects := (name,fixed) :: objects
  let saveArea := align fixed + 176
  let frame := align (if f.variadic then saveArea else fixed)
  if frame > 1024*1024 then throw "AMD64 frame exceeds 1 MiB"
  -- Lookup-only tables preserve layout order; reversing retains List.lookup first-match behavior.
  let c : Context := { darwin, slots := Std.HashMap.ofList ((homes.homes.filterMap (fun (n,i) => if i >= homes.registerCount then some (n,(i-homes.registerCount+1)*8) else none)).reverse), registers := Std.HashMap.ofList ((homes.homes.filterMap (fun (n,i) => if i < homes.registerCount then some (n,bank[i]!) else none)).reverse), objects, types, resultPointer, locals, stage := (homes.spills+1)*8, saveArea, stackArgs := incoming.stackBytes, gpUsed := incoming.ngp, fpUsed := incoming.nfp }
  let symbol := Assembly.symbolName darwin f.name
  let mut lines := Assembly.LineBuffer.ofList [f.customSection.map (Assembly.sectionDirective darwin) |>.getD ".text", ".p2align 4"]
  if !darwin then lines := lines ++ [s!".type {symbol}, @function"]
  if f.exported then lines := lines ++ [s!".globl {symbol}"]
  lines := lines ++ [s!"{symbol}:", "\tpushq %rbp", "\tmovq %rsp, %rbp"]
  if frame != 0 then lines := lines ++ [s!"\tsubq ${frame}, %rsp"]
  for i in [:saved.size] do lines := lines ++ [s!"\tmovq %{saved[i]!}, -{savedBase+i*8}(%rbp)"]
  if resultInfo.any (·.memory) then lines := lines ++ [s!"\tmovq %rdi, -{resultPointer}(%rbp)"]
  if f.variadic then
    for i in [:6] do lines := lines ++ [s!"\tmovq %{gp[i]!}, -{saveArea-i*8}(%rbp)"]
    for i in [:8] do lines := lines ++ [s!"\tmovdqu %xmm{i}, -{saveArea-48-i*16}(%rbp)"]
  for i in [:f.parameters.size] do
    let p := f.parameters[i]!
    if let some name := p.aggregate then
      let info ← AMD64ABI.find types name
      match incoming.places[i]! with
      | .aggregate chunks =>
        lines := lines ++ (← objectAddress c p.name "r10")
        for (floating,index,offset) in chunks do
          if floating then lines := lines ++ [s!"\tmovq %xmm{index}, %rax"]
          lines := lines ++ writeFragment (if floating then "rax" else gp[index]!) offset (min 8 (info.layout.size-offset))
      | .stack offset =>
        lines := lines ++ [s!"\tleaq {16+offset}(%rbp), %r10"] ++ (← objectAddress c p.name "r11") ++ copyBytes info.layout.size
      | _ => throw "invalid AMD64 aggregate parameter location"
      lines := lines ++ (← objectAddress c p.name "rax") ++ (← store c p.name)
      continue
    match incoming.places[i]! with
    | .integer index => lines := lines ++ [s!"\tmovq %{gp[index]!}, %rax"]
    | .floating index => lines := lines ++ [s!"\tmov{if p.width == .word then "d" else "q"} %xmm{index}, {reg p.width "rax"}"]
    | .stack offset => lines := lines ++ [s!"\tmovq {16+offset}(%rbp), %rax"]
    | .environment => pure ()
    | .aggregate _ => throw "scalar parameter in aggregate registers"
    if let some kind := p.subword then lines := lines ++ extend .word kind.extension
    if p.width == .word then lines := lines ++ ["\tmovl %eax, %eax"]
    lines := lines ++ (← store c p.name)
  let uses := if allocate then Selection.useCounts f else {}
  for blockIndex in [:f.blocks.size] do
    let block := f.blocks[blockIndex]!
    let next := (f.blocks[blockIndex+1]?).map (·.label)
    let branchCompare := if allocate then Selection.branchComparison uses block else none
    lines := lines ++ [label darwin f block.label ++ ":"]
    let mut debugIndex := 0
    let mut pendingMemory : Option (List String) := none
    for i in [:block.instructions.size+1] do
      for _ in [:block.debugLocations.size] do
        if let some loc := block.debugLocations[debugIndex]? then
          if loc.instruction != i then break
          lines := lines ++ [s!"\t.loc {fileId} {loc.line} {loc.column}"]
          debugIndex := debugIndex + 1
        else break
      if let some inst := block.instructions[i]? then
        if let some selected := pendingMemory then
          -- Emit the fused access after the memory statement's debug location.
          lines := lines ++ selected
          pendingMemory := none
        else
          if allocate then
            if let some next := block.instructions[i+1]? then
              pendingMemory ← adjacentMemory c uses inst next
          if pendingMemory.isNone then
            if let some (_, width, x, y) := branchCompare then
              if i+1 == block.instructions.size then lines := lines ++ (← comparisonFlags c width x y)
              else lines := lines ++ (← emitStatement c inst)
            else lines := lines ++ (← emitStatement c inst)
    match block.terminator with
    | .ret value =>
      if let some value := value then
        let some width := f.resultWidth | throw "missing return type"
        if let some info := resultInfo then
          lines := lines ++ (← load c .long "r10" value)
          if info.memory then
            lines := lines ++ [s!"\tmovq -{resultPointer}(%rbp), %r11"] ++ copyBytes info.layout.size ++ ["\tmovq %r11, %rax"]
          else
            for (floating,destination,offset) in returnChunks info do
              lines := lines ++ readFragment (if floating then "rcx" else destination) offset (min 8 (info.layout.size-offset))
              if floating then lines := lines ++ [s!"\tmovq %rcx, %{destination}"]
        else
          lines := lines ++ (← load c width "rax" value)
          if let some kind := f.resultSubword then lines := lines ++ extend .word kind.extension
          if f.resultFloating then lines := lines ++ [s!"\tmov{if width == .word then "d" else "q"} {reg width "rax"}, %xmm0"]
      for i in [:saved.size] do lines := lines ++ [s!"\tmovq -{savedBase+i*8}(%rbp), %{saved[i]!}"]
      lines := lines ++ ["\tleave", "\tret"]
    | .halt => lines := lines ++ ["\tud2"]
    | .jump target =>
      lines := lines ++ (← edge c f block.label target)
      if !allocate || next != some target then lines := lines ++ [s!"\tjmp {label darwin f target}"]
    | .branch value yes no =>
      let other := s!"{if darwin then "L" else ".L"}_lcb_edge_{f.name.length}_{Assembly.localName f.name}_{block.label}"
      if let some (op, _, _, _) := branchCompare then
        lines := lines ++ [s!"\tj{inverseCondition op} {other}"]
      else
        lines := lines ++ (← load c .word "rax" value) ++ ["\ttestl %eax, %eax", s!"\tjz {other}"]
      lines := lines ++ (← edge c f block.label yes) ++ [s!"\tjmp {label darwin f yes}", other ++ ":"] ++ (← edge c f block.label no)
      if !allocate || next != some no then lines := lines ++ [s!"\tjmp {label darwin f no}"]
  if !darwin then lines := lines ++ [s!".size {symbol}, .-{symbol}"]
  if let some name := f.debugFile then lines := [s!".file {fileId} {Assembly.debugFilename name}"] ++ lines
  pure (String.intercalate "\n" lines.toList ++ "\n")

def emitModule (m : Module) (darwin : Bool := false) (allocate : Bool := false) : Except String String := do
  validateModule m
  for data in m.data do Section.checkDataTarget darwin data.threadLocal data.customSection
  let types ← AMD64ABI.classify m.types
  let locals := (m.functions.filter (!·.exported)).toList.map (·.name) ++
    (m.data.filter (fun d => !d.exported && !d.common)).toList.map (·.name)
  let mut output := s!"# Generated by Lean Compiler Backend; {if darwin then "macOS" else "Linux"} AMD64 System V\n"
  let mut fileId := 1
  for f in m.functions do
    output := output ++ (← emitFunction f types locals fileId darwin allocate)
    if f.debugFile.isSome then fileId := fileId + 1
  for data in m.data do output := output ++ Assembly.emitData darwin data
  pure (output ++ if darwin then ".subsections_via_symbols\n" else ".section .note.GNU-stack,\"\",@progbits\n")

end LeanCompilerBackend.AMD64
