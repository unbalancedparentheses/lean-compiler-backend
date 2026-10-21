/- Baseline Linux AMD64/System V lowering. ABI reference: pinned QBE amd64/sysv.c.
   Every SSA value has a stable frame slot; this is not register allocation. -/
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.Assembly

namespace LeanCompilerBackend.AMD64

private def align (n : Nat) : Nat := (n + 15) / 16 * 16
private def suffix (w : Width) : String := if w == .word then "l" else "q"
private def fsuffix (w : Width) : String := if w == .word then "ss" else "sd"
private def reg (w : Width) (r : String) : String :=
  "%" ++ if w == .long then r else match r with
    | "rax" => "eax" | "rcx" => "ecx" | "rdx" => "edx"
    | "rdi" => "edi" | "rsi" => "esi" | _ => r ++ "d"
private def gp : Array String := #["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

private structure Context where
  slots : List (String × Nat)
  locals : List String
  stage : Nat
  saveArea : Nat
  stackArgs : Nat
  gpUsed : Nat
  fpUsed : Nat

private def slot (c : Context) (name : String) : Except String String := do
  let some offset := c.slots.lookup name | throw s!"missing AMD64 stack slot %{name}"
  pure s!"-{offset}(%rbp)"

private def load (c : Context) (w : Width) (r : String) : Operand → Except String (List String)
  | .constant n => pure [s!"\tmov{if w == .long then "absq" else "l"} ${Semantics.constant w n}, {reg w r}"]
  | .temporary name => return [s!"\tmov{suffix w} {← slot c name}, {reg w r}"]
  | .symbol name =>
    let address := if c.locals.contains name then s!"\tleaq {name}(%rip), %{r}"
      else s!"\tmovq {name}@GOTPCREL(%rip), %{r}"
    pure ([address] ++ if w == .word then [s!"\tmovl {reg .word r}, {reg .word r}"] else [])
  | .threadSymbol _ => throw "Linux AMD64 TLS is not yet implemented"

private def extend (w : Width) : Unary → List String
  | .negate => [s!"\tneg{suffix w} {reg w "rax"}"]
  | .signedByte => [s!"\tmovsb{suffix w} %al, {reg w "rax"}"]
  | .unsignedByte => ["\tmovzbl %al, %eax"]
  | .signedHalf => [s!"\tmovsw{suffix w} %ax, {reg w "rax"}"]
  | .unsignedHalf => ["\tmovzwl %ax, %eax"]
  | .signedWord => if w == .long then ["\tmovslq %eax, %rax"] else ["\tmovl %eax, %eax"]
  | .unsignedWord => ["\tmovl %eax, %eax"]

private inductive Location where
  | integer (index : Nat) | floating (index : Nat) | stack (offset : Nat) | environment
  deriving Inhabited
private structure Plan where
  places : Array Location := #[]
  ngp : Nat := 0
  nfp : Nat := 0
  stackBytes : Nat := 0

private def plan (args : Array CallArgument) : Except String Plan := do
  let mut p : Plan := {}
  if args.any (·.environment) && args.any (·.variadic) then
    throw "AMD64 System V does not support variadic environment calls"
  for arg in args do
    if arg.aggregate.isSome then throw "Linux AMD64 aggregate ABI is not yet implemented"
    if arg.environment then p := { p with places := p.places.push .environment }
    else if arg.floating && p.nfp < 8 then
      p := { p with places := p.places.push (.floating p.nfp), nfp := p.nfp + 1 }
    else if !arg.floating && p.ngp < 6 then
      p := { p with places := p.places.push (.integer p.ngp), ngp := p.ngp + 1 }
    else p := { p with places := p.places.push (.stack p.stackBytes), stackBytes := p.stackBytes + 8 }
  pure p

private def emitCall (c : Context) (target : CallTarget) (args : Array CallArgument) : Except String (List String) := do
  let p ← plan args
  let bytes := align p.stackBytes
  let mut lines := if bytes != 0 then [s!"\tsubq ${bytes}, %rsp"] else []
  for i in [:args.size] do
    let arg := args[i]!
    if arg.environment then continue
    lines := lines ++ (← load c arg.width "rax" arg.value)
    if let some kind := arg.subword then lines := lines ++ extend .word kind.extension
    match p.places[i]! with
    | .integer index => lines := lines ++ [s!"\tmovq %rax, %{gp[index]!}"]
    | .floating index => lines := lines ++ [s!"\tmov{if arg.width == .word then "d" else "q"} {reg arg.width "rax"}, %xmm{index}"]
    | .stack offset => lines := lines ++ [s!"\tmovq %rax, {offset}(%rsp)"]
    | .environment => pure ()
  if let .indirect address := target then lines := lines ++ (← load c .long "r11" address)
  if let some arg := args.find? (·.environment) then lines := lines ++ (← load c .long "rax" arg.value)
  else if args.any (·.variadic) then lines := lines ++ [s!"\tmovl ${p.nfp}, %eax"]
  lines := lines ++ [match target with | .direct name => s!"\tcall {name}" | .indirect _ => "\tcall *%r11"]
  if bytes != 0 then lines := lines ++ [s!"\taddq ${bytes}, %rsp"]
  pure lines

private def condition : Comparison → String
  | .eq => "e" | .ne => "ne" | .signedLE => "le" | .signedLT => "l" | .signedGE => "ge" | .signedGT => "g"
  | .unsignedLE => "be" | .unsignedLT => "b" | .unsignedGE => "ae" | .unsignedGT => "a"

private def emitInstruction (c : Context) (inst : Instruction) : Except String (List String) := do
  if inst.callAggregate.isSome then throw "Linux AMD64 aggregate ABI is not yet implemented"
  let w := inst.width
  let s := suffix w
  let a := reg w "rax"
  let b := reg w "rcx"
  let mut lines := []
  match inst.operation with
  | .copy x | .cast x => lines := ← load c w "rax" x
  | .binary op x y =>
    lines := (← load c w "rax" x) ++ (← load c (op.rhsWidth w) "rcx" y)
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
    lines := (← load c width "rax" x) ++ (← load c width "rcx" y) ++
      [s!"\tcmp{suffix width} {reg width "rcx"}, {reg width "rax"}", s!"\tset{condition op} %al", "\tmovzbl %al, %eax"]
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
  | .call target args =>
    lines := ← emitCall c target args
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
  if w == .word then lines := lines ++ ["\tmovl %eax, %eax"]
  pure (lines ++ [s!"\tmovq %rax, {← slot c inst.destination}"])

private def emitStatement (c : Context) : Statement → Except String (List String)
  | .assign inst => emitInstruction c inst
  | .callVoid target args => emitCall c target args
  | .storeFloat width value address => do
    return (← load c .long "r10" address) ++ (← load c width "rax" value) ++ [s!"\tmov{suffix width} {reg width "rax"}, (%r10)"]
  | .store width value address => do
    let (s, r) := match width with | .byte => ("b", "%al") | .half => ("w", "%ax") | .word => ("l", "%eax") | .long => ("q", "%rax")
    return (← load c .long "r10" address) ++ (← load c width.valueWidth "rax" value) ++ [s!"\tmov{s} {r}, (%r10)"]
  | .blit source destination bytes => do
    if bytes == 0 then return []
    let mut lines := (← load c .long "r10" source) ++ (← load c .long "r11" destination)
    for offset in [0:bytes / 8] do
      lines := lines ++ [s!"\tmovq {offset*8}(%r10), %rax", s!"\tmovq %rax, {offset*8}(%r11)"]
    for offset in [bytes / 8 * 8:bytes] do
      lines := lines ++ [s!"\tmovb {offset}(%r10), %al", s!"\tmovb %al, {offset}(%r11)"]
    pure lines
  | .vaStart list => do
    return (← load c .long "rax" list) ++ [s!"\tmovl ${c.gpUsed*8}, (%rax)", s!"\tmovl ${48+c.fpUsed*16}, 4(%rax)",
      s!"\tleaq {16+c.stackArgs}(%rbp), %rcx", "\tmovq %rcx, 8(%rax)", s!"\tleaq -{c.saveArea}(%rbp), %rcx", "\tmovq %rcx, 16(%rax)"]

private def label (f : Function) (name : String) : String := s!".L_lcb_{f.name.length}_{f.name}_{name}"
private def edge (c : Context) (f : Function) (source target : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == target) | throw "missing edge target"
  let mut lines := []
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_, value) := phi.incoming.find? (·.1 == source) | throw "missing phi incoming"
    lines := lines ++ (← load c phi.width "rax" value) ++ [s!"\tmovq %rax, -{c.stage+i*8}(%rbp)"]
  for i in [:block.phis.size] do
    lines := lines ++ [s!"\tmovq -{c.stage+i*8}(%rbp), %rax", s!"\tmovq %rax, {← slot c block.phis[i]!.destination}"]
  pure lines

private def emitFunction (f : Function) (locals : List String) (fileId : Nat) : Except String String := do
  validateFunction f true
  Assembly.checkTargetSection false f.customSection
  if f.resultAggregate.isSome then throw "Linux AMD64 aggregate ABI is not yet implemented"
  if f.variadic && f.parameters.any (·.environment) then throw "AMD64 System V does not support variadic environment functions"
  let params := f.parameters.map fun p => { width := p.width, value := Operand.temporary p.name, floating := p.floating, subword := p.subword, environment := p.environment, aggregate := p.aggregate : CallArgument }
  let incoming ← plan params
  let names := f.locals
  let maxPhi := f.blocks.foldl (fun n b => max n b.phis.size) 0
  let fixed := (names.size + maxPhi)*8
  let saveArea := align fixed + 176
  let frame := align (if f.variadic then saveArea else fixed)
  if frame > 1024*1024 then throw "AMD64 frame exceeds 1 MiB"
  let c : Context := { slots := names.toList.zipIdx.map (fun ((n,_),i) => (n,(i+1)*8)), locals, stage := (names.size+1)*8, saveArea, stackArgs := incoming.stackBytes, gpUsed := incoming.ngp, fpUsed := incoming.nfp }
  let mut lines := [f.customSection.map (Assembly.sectionDirective false) |>.getD ".text", s!".type {f.name}, @function", ".p2align 4"]
  if f.exported then lines := lines ++ [s!".globl {f.name}"]
  lines := lines ++ [s!"{f.name}:", "\tpushq %rbp", "\tmovq %rsp, %rbp"]
  if frame != 0 then lines := lines ++ [s!"\tsubq ${frame}, %rsp"]
  if f.variadic then
    for i in [:6] do lines := lines ++ [s!"\tmovq %{gp[i]!}, -{saveArea-i*8}(%rbp)"]
    for i in [:8] do lines := lines ++ [s!"\tmovdqu %xmm{i}, -{saveArea-48-i*16}(%rbp)"]
  for i in [:f.parameters.size] do
    let p := f.parameters[i]!
    match incoming.places[i]! with
    | .integer index => lines := lines ++ [s!"\tmovq %{gp[index]!}, %rax"]
    | .floating index => lines := lines ++ [s!"\tmov{if p.width == .word then "d" else "q"} %xmm{index}, {reg p.width "rax"}"]
    | .stack offset => lines := lines ++ [s!"\tmovq {16+offset}(%rbp), %rax"]
    | .environment => pure ()
    if let some kind := p.subword then lines := lines ++ extend .word kind.extension
    if p.width == .word then lines := lines ++ ["\tmovl %eax, %eax"]
    lines := lines ++ [s!"\tmovq %rax, {← slot c p.name}"]
  for block in f.blocks do
    lines := lines ++ [label f block.label ++ ":"]
    let mut debugIndex := 0
    for i in [:block.instructions.size+1] do
      for _ in [:block.debugLocations.size] do
        if let some loc := block.debugLocations[debugIndex]? then
          if loc.instruction != i then break
          lines := lines ++ [s!"\t.loc {fileId} {loc.line} {loc.column}"]
          debugIndex := debugIndex + 1
        else break
      if let some inst := block.instructions[i]? then lines := lines ++ (← emitStatement c inst)
    match block.terminator with
    | .ret value =>
      if let some value := value then
        let some width := f.resultWidth | throw "missing return type"
        lines := lines ++ (← load c width "rax" value)
        if let some kind := f.resultSubword then lines := lines ++ extend .word kind.extension
        if f.resultFloating then lines := lines ++ [s!"\tmov{if width == .word then "d" else "q"} {reg width "rax"}, %xmm0"]
      lines := lines ++ ["\tleave", "\tret"]
    | .halt => lines := lines ++ ["\tud2"]
    | .jump target => lines := lines ++ (← edge c f block.label target) ++ [s!"\tjmp {label f target}"]
    | .branch value yes no =>
      let other := s!".L_lcb_edge_{f.name.length}_{f.name}_{block.label}"
      lines := lines ++ (← load c .word "rax" value) ++ ["\ttestl %eax, %eax", s!"\tjz {other}"] ++
        (← edge c f block.label yes) ++ [s!"\tjmp {label f yes}", other ++ ":"] ++ (← edge c f block.label no) ++ [s!"\tjmp {label f no}"]
  lines := lines ++ [s!".size {f.name}, .-{f.name}"]
  if let some name := f.debugFile then lines := [s!".file {fileId} {Assembly.debugFilename name}"] ++ lines
  pure (String.intercalate "\n" lines ++ "\n")

def emitModule (m : Module) : Except String String := do
  validateModule m
  if m.data.any (·.threadLocal) then throw "Linux AMD64 TLS is not yet implemented"
  for data in m.data do Assembly.checkTargetSection false data.customSection
  let locals := (m.functions.filter (!·.exported)).toList.map (·.name) ++
    (m.data.filter (fun d => !d.exported && !d.common)).toList.map (·.name)
  let mut output := "# Generated by Lean Compiler Backend; Linux AMD64 System V\n"
  let mut fileId := 1
  for f in m.functions do
    output := output ++ (← emitFunction f locals fileId)
    if f.debugFile.isSome then fileId := fileId + 1
  for data in m.data do output := output ++ Assembly.emitData false data
  pure (output ++ ".section .note.GNU-stack,\"\",@progbits\n")

end LeanCompilerBackend.AMD64
