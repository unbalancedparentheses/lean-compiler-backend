import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Assembly

/-- Accumulate instruction chunks without repeatedly copying the whole function.
    Flatten once, preserving the exact line and debug-directive order. -/
structure LineBuffer where
  chunks : Array (List String)

def LineBuffer.ofList (lines : List String) : LineBuffer := ⟨#[lines]⟩

instance : HAppend LineBuffer (List String) LineBuffer where
  hAppend buffer lines := ⟨buffer.chunks.push lines⟩

instance : HAppend (List String) LineBuffer LineBuffer where
  hAppend lines buffer := ⟨#[lines] ++ buffer.chunks⟩

def LineBuffer.toList (buffer : LineBuffer) : List String := buffer.chunks.toList.flatten

def symbolName (darwin : Bool) (name : String) : String :=
  if darwin then
    if name.startsWith "\"" then name else "_" ++ name
  else name

/-- Add target-private suffixes inside global-symbol quotes. -/
def symbolSuffix (name suffix : String) : String :=
  if name.startsWith "\"" then String.ofList (name.toList.take (name.length-1)) ++ suffix ++ "\""
  else name ++ suffix

/-- Quoted function names must not become assembler syntax in internal labels.
    The function-name length in each label keeps this encoding distinct from
    ordinary identifiers with a coincidentally matching spelling. -/
def localName (name : String) : String :=
  if name.startsWith "\"" then "quoted_" ++ String.intercalate "_" (name.toUTF8.data.toList.map (fun b => toString b.toNat))
  else name


def sectionDirective (darwin : Bool) (customSection : String) : String :=
  if darwin then ".section " ++ customSection
  else match customSection.splitOn "," with
    | name :: flags :: _ => s!".section {name},\"{flags}\""
    | _ => ".section " ++ customSection

def checkTargetSection (darwin : Bool) (customSection : Option String) : Except String Unit := do
  if let some name := customSection then
    if darwin == name.startsWith "." then
      throw "custom section syntax does not match the selected object format"

/-- Quote UTF-8 bytes using assembler octal escapes, including quotes and backslashes. -/
def debugFilename (name : String) : String :=
  "\"" ++ String.join (name.toUTF8.data.toList.map fun byte =>
    let n := byte.toNat
    "\\" ++ toString (n / 64) ++ toString (n / 8 % 8) ++ toString (n % 8)) ++ "\""


def emitData (darwin : Bool) (data : DataDefinition) : String := Id.run do
  if data.common then
    return s!".comm {symbolName darwin data.name},{data.byteSize},{if darwin then Nat.log2 data.alignment else data.alignment}\n"
  let zeroOnly := data.byteSize > 0 && !data.threadLocal && data.customSection.isNone &&
    data.items.all (fun item => match item with | .zeroes _ => true | _ => false)
  if darwin && zeroOnly then
    let global := if data.exported then s!".globl {symbolName true data.name}\n" else ""
    return global ++ s!".zerofill __DATA,__bss,{symbolName true data.name},{data.byteSize},{Nat.log2 data.alignment}\n"
  let mut lines := if data.threadLocal then
    if darwin then [".section __DATA,__thread_vars,thread_local_variables", ".p2align 3"]
    else [".section .tdata,\"awT\",%progbits", s!".type {data.name}, %tls_object"]
    else [data.customSection.map (sectionDirective darwin) |>.getD (if zeroOnly then ".bss" else ".data")]
  if data.exported then lines := lines ++ [s!".globl {symbolName darwin data.name}"]
  let initialSymbol := if darwin && data.threadLocal then symbolSuffix (symbolName true data.name) "$tlv$init" else symbolName darwin data.name
  if darwin && data.threadLocal then
    lines := lines ++ [s!"{symbolName true data.name}:", "\t.quad __tlv_bootstrap", "\t.quad 0", s!"\t.quad {initialSymbol}",
      ".section __DATA,__thread_data,thread_local_regular"]
  if !darwin then
    if !data.threadLocal then lines := lines ++ [s!".type {data.name}, %object"]
    lines := lines ++ [s!".size {data.name}, {data.byteSize}"]
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


end LeanCompilerBackend.Assembly
