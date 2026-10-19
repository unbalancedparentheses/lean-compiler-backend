/-
  QBE-compatible lexical and grammar subset, adapted from QBE 1.3 parse.c
  and doc/il.txt. See docs/UPSTREAM.md and third_party/qbe/LICENSE.
  Unsupported constructs are errors; no partial successful compilation.
-/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Parser

structure Token where
  text : String
  line : Nat
  deriving Repr

private def separator (c : Char) : Bool :=
  c == '(' || c == ')' || c == '{' || c == '}' || c == '=' || c == ','

def tokenize (source : String) : Array Token := Id.run do
  let mut tokens := #[]
  for (lineIndex, line) in source.splitOn "\n" |>.zipIdx |>.map (fun (s, i) => (i, s)) do
    let line := (line.splitOn "#").head!
    let mut current := ""
    for c in line.toList do
      if c.isWhitespace || separator c then
        if !current.isEmpty then
          tokens := tokens.push ⟨current, lineIndex + 1⟩
          current := ""
        if separator c then tokens := tokens.push ⟨String.singleton c, lineIndex + 1⟩
      else current := current.push c
    if !current.isEmpty then tokens := tokens.push ⟨current, lineIndex + 1⟩
  return tokens

private structure Cursor where
  tokens : Array Token
  position : Nat := 0

private abbrev P := StateT Cursor (Except String)

private def failAt (message : String) : P α := do
  let s ← get
  let location := match s.tokens[s.position]? with
    | some t => s!"line {t.line} near '{t.text}'"
    | none => "end of input"
  throw s!"{location}: {message}"

private def peek : P (Option String) := do
  return ((← get).tokens[(← get).position]?).map (·.text)

private def take : P String := do
  let s ← get
  match s.tokens[s.position]? with
  | none => failAt "unexpected end of input"
  | some t =>
    set { s with position := s.position + 1 }
    return t.text

private def expect (wanted : String) : P Unit := do
  if (← peek) != some wanted then failAt s!"expected '{wanted}'"
  discard take

private def parseWidth : P Width := do
  match ← peek with
  | some "w" => discard take; return .word
  | some "l" => discard take; return .long
  | _ => failAt "unsupported type: expected w (32-bit) or l (64-bit)"

private def parseName (sigil : Char) : P String := do
  let name ← take
  let chars := name.toList
  match chars with
  | first :: rest =>
    if first != sigil || rest.isEmpty then failAt s!"expected a {sigil}-prefixed name"
    if !rest.all (fun c => c.toNat < 128 && (c.isAlphanum || c == '_')) then
      failAt "unsupported name: use ASCII letters, digits and underscores"
    if !(rest.head!.isAlpha || rest.head! == '_') then
      failAt "name must start with a letter or underscore"
    return String.ofList rest
  | [] => failAt "empty name"

private def parseOperand : P Operand := do
  let token ← peek
  match token with
  | some s =>
    if s.startsWith "%" then return .temporary (← parseName '%')
    match s.toInt? with
    | some n =>
      if n < -(2 ^ 63 : Int) || n > (2 ^ 64 : Int) - 1 then
        failAt "constant is outside the supported 64-bit QBE bit-pattern domain"
      discard take
      return .constant n
    | none => failAt "unsupported operand: expected temporary or decimal integer"
  | none => failAt "expected operand"

private def unaryName : String → Option Unary
  | "neg" => some .negate
  | "extsb" => some .signedByte
  | "extub" => some .unsignedByte
  | "extsh" => some .signedHalf
  | "extuh" => some .unsignedHalf
  | "extsw" => some .signedWord
  | "extuw" => some .unsignedWord
  | _ => none

private def divisionName : String → Option Division
  | "div" => some .signedDiv
  | "udiv" => some .unsignedDiv
  | "rem" => some .signedRem
  | "urem" => some .unsignedRem
  | _ => none

private def comparisonName (name : String) : Option (Comparison × Width) := Id.run do
  let names : List (String × Comparison) := [
    ("ceq", .eq), ("cne", .ne), ("csle", .signedLE), ("cslt", .signedLT),
    ("csge", .signedGE), ("csgt", .signedGT), ("cule", .unsignedLE),
    ("cult", .unsignedLT), ("cuge", .unsignedGE), ("cugt", .unsignedGT)]
  for (stem, op) in names do
    if name == stem ++ "w" then return some (op, .word)
    if name == stem ++ "l" then return some (op, .long)
  return none

private def parseArguments : Nat → P (Array CallArgument)
  | 0 => failAt "call argument parsing limit exceeded"
  | fuel + 1 => do
    if (← peek) == some ")" then return #[]
    let width ← parseWidth
    let value ← parseOperand
    if (← peek) == some "," then
      discard take
      if (← peek) == some ")" then failAt "trailing comma in call arguments"
      return #[{ width, value }] ++ (← parseArguments fuel)
    return #[{ width, value }]

private def parseCall : P (String × Array CallArgument) := do
  let target ← parseName '$'
  expect "("
  let arguments ← parseArguments (maxIntegerArguments + 2)
  expect ")"
  pure (target, arguments)

private def parseOperation (name : String) : P Operation := do
  if name == "copy" then
    pure (.copy (← parseOperand))
  else if name == "call" then do
    let (target, arguments) ← parseCall
    pure (.call target arguments)
  else if ["alloc1", "alloc2", "alloc4", "alloc8", "alloc16"].contains name then
    -- QBE parse.c maps alloc1/alloc2 aliases to alloc4 (stronger alignment).
    let alignment := if ["alloc1", "alloc2", "alloc4"].contains name then StackAlignment.four
      else if name == "alloc8" then .eight else .sixteen
    pure (.allocate alignment (← parseOperand))
  else if let some kind := match name with
      | "loadsb" => some LoadKind.signedByte | "loadub" => some .unsignedByte
      | "loadsh" => some .signedHalf | "loaduh" => some .unsignedHalf
      | "loadsw" | "loadw" => some .signedWord | "loaduw" => some .unsignedWord
      | "load" | "loadl" => some .plain | _ => none then
    pure (.load kind (← parseOperand))
  else if let some op := unaryName name then
    pure (.unary op (← parseOperand))
  else if let some op := divisionName name then do
    let lhs ← parseOperand
    expect ","
    pure (.divide op lhs (← parseOperand))
  else if let some (op, operandWidth) := comparisonName name then do
    let lhs ← parseOperand
    expect ","
    pure (.compare op operandWidth lhs (← parseOperand))
  else do
    let op ← match name with
      | "add" => pure Binary.add
      | "sub" => pure Binary.sub
      | "mul" => pure Binary.mul
      | "and" => pure Binary.andBits
      | "or" => pure Binary.orBits
      | "xor" => pure Binary.xorBits
      | "shl" => pure Binary.shiftLeft
      | "shr" => pure Binary.logicalRight
      | "sar" => pure Binary.arithmeticRight
      | _ => failAt s!"unsupported operation '{name}'"
    let lhs ← parseOperand
    expect ","
    let rhs ← parseOperand
    pure (.binary op lhs rhs)

private def parseIncoming : Nat → P (Array (String × Operand))
  | 0 => failAt "phi incoming-edge limit exceeded"
  | fuel + 1 => do
    let label ← parseName '@'
    let value ← parseOperand
    if (← peek) == some "," then
      discard take
      pure (#[ (label, value) ] ++ (← parseIncoming fuel))
    else pure #[ (label, value) ]

private def parseDefinition : P (Sum Phi Statement) := do
  let destination ← parseName '%'
  expect "="
  let width ← parseWidth
  let name ← take
  if name == "phi" then
    pure (.inl { destination, width, incoming := ← parseIncoming 65 })
  else
    pure (.inr (.assign { destination, width, operation := ← parseOperation name }))

private def storeWidth : String → Option MemoryWidth
  | "storeb" => some .byte | "storeh" => some .half
  | "storew" => some .word | "storel" => some .long | _ => none

private def parseStore (width : MemoryWidth) : P Statement := do
  discard take
  let value ← parseOperand
  expect ","
  pure (.store width value (← parseOperand))

private def parseBlit : P Statement := do
  expect "blit"
  let source ← parseOperand
  expect ","
  let destination ← parseOperand
  expect ","
  let .constant bytes ← parseOperand
    | failAt "blit byte count must be a nonnegative numeric constant"
  if bytes < 0 then failAt "blit byte count must be nonnegative"
  pure (.blit source destination bytes.toNat)

private def parseParameters : Nat → P (Array Parameter)
  | 0 => failAt "parameter parsing limit exceeded"
  | fuel + 1 => do
    if (← peek) == some ")" then return #[]
    let width ← parseWidth
    let name ← parseName '%'
    if (← peek) == some "," then
      discard take
      if (← peek) == some ")" then failAt "trailing comma in parameters"
      return #[{ name, width }] ++ (← parseParameters fuel)
    return #[{ name, width }]

private def parseBody (resultWidth : Option Width) : Nat → P (Array Phi × Array Statement × Terminator)
  | 0 => failAt "instruction parsing limit exceeded"
  | fuel + 1 => do
    if (← peek) == some "ret" then
      discard take
      let value ← if resultWidth.isSome then some <$> parseOperand else pure none
      pure (#[], #[], .ret value)
    else if (← peek) == some "jmp" then
      discard take
      pure (#[], #[], .jump (← parseName '@'))
    else if (← peek) == some "jnz" then
      discard take
      let condition ← parseOperand
      expect ","
      let yes ← parseName '@'
      expect ","
      pure (#[], #[], .branch condition yes (← parseName '@'))
    else if (← peek) == some "hlt" then
      discard take
      pure (#[], #[], .halt)
    else if let some token := ← peek then
      if token.startsWith "@" then
        -- QBE permits fallthrough when the next label begins a new block.
        pure (#[], #[], .jump (String.ofList token.toList.tail))
      else
        let definition ← if let some width := storeWidth token then
          Sum.inr <$> parseStore width
        else if token == "blit" then Sum.inr <$> parseBlit
        else if token == "call" then do
          discard take
          let (target, arguments) ← parseCall
          pure (.inr (.callVoid target arguments))
        else parseDefinition
        let (phis, instructions, terminator) ← parseBody resultWidth fuel
        match definition with
        | .inl phi => pure (#[phi] ++ phis, instructions, terminator)
        | .inr inst =>
          if !phis.isEmpty then failAt "phi definitions must precede ordinary instructions"
          pure (#[], #[inst] ++ instructions, terminator)
    else failAt "expected block terminator"

private def parseBlocks (resultWidth : Option Width) : Nat → P (Array Block)
  | 0 => failAt "block parsing limit exceeded"
  | fuel + 1 => do
    let label ← parseName '@'
    let (phis, instructions, terminator) ← parseBody resultWidth 481
    let block := { label, phis, instructions, terminator : Block }
    match ← peek with
    | some token =>
      if token.startsWith "@" then pure (#[block] ++ (← parseBlocks resultWidth fuel))
      else pure #[block]
    | none => pure #[block]

private def parseFunction : P Function := do
  let exported := (← peek) == some "export"
  if exported then discard take
  expect "function"
  let resultWidth ← if ((← peek).getD "").startsWith "$" then pure none else some <$> parseWidth
  let name ← parseName '$'
  expect "("
  let parameters ← parseParameters (maxIntegerArguments + 2)
  expect ")"
  expect "{"
  let blocks ← parseBlocks resultWidth 65
  expect "}"
  return { name, exported, resultWidth, parameters, blocks }

private def parseProgram : Nat → P Program
  | 0 => failAt "function parsing limit exceeded"
  | fuel + 1 => do
    if (← peek).isNone then return #[]
    let f ← parseFunction
    return #[f] ++ (← parseProgram fuel)

def parse (source : String) : Except String Program := do
  if source.utf8ByteSize > 1024 * 1024 then throw "input exceeds 1 MiB initial resource limit"
  let tokens := tokenize source
  if tokens.isEmpty then throw "input contains no functions"
  if tokens.size > 50000 then throw "input exceeds initial token limit"
  let (program, _) ← (parseProgram (min (tokens.size + 1) 65)).run { tokens }
  return program

end LeanCompilerBackend.Parser
