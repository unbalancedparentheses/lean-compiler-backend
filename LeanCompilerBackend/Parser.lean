/-
  QBE-compatible lexical and grammar subset, adapted from QBE 1.3 parse.c
  and doc/il.txt. See docs/UPSTREAM.md and third_party/qbe/LICENSE.
  Unsupported constructs are errors; no partial successful compilation.
-/
import LeanCompilerBackend.Numeric

namespace LeanCompilerBackend.Parser

structure Token where
  text : String
  line : Nat
  deriving Repr

private def separator (c : Char) : Bool :=
  c == '(' || c == ')' || c == '{' || c == '}' || c == '=' || c == ',' || c == '+'

/-- Preserve quoted strings before recognizing comments and punctuation. -/
def tokenize (source : String) : Array Token := Id.run do
  let mut tokens := #[]
  for (lineIndex, line) in source.splitOn "\n" |>.zipIdx |>.map (fun (s, i) => (i, s)) do
    let mut current := ""
    let mut quoted := false
    let mut escaped := false
    let mut comment := false
    for c in line.toList do
      if comment then continue
      if quoted then
        current := current.push c
        if escaped then escaped := false
        else if c == '\\' then escaped := true
        else if c == '"' then
          quoted := false
          tokens := tokens.push ⟨current, lineIndex + 1⟩
          current := ""
      else if c == '"' then
        quoted := true
        current := current.push c
      else if c == '#' then
        comment := true
      else if c == '+' && ((current.startsWith "s_") || (current.startsWith "d_")) &&
          (current.endsWith "e" || current.endsWith "E" || current.endsWith "p" || current.endsWith "P" || current.endsWith "_") then
        current := current.push c
      else if c.isWhitespace || separator c then
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

private def parseValueType : P (Width × Bool) := do
  match ← peek with
  | some "s" => discard take; return (.word, true)
  | some "d" => discard take; return (.long, true)
  | _ => return (← parseWidth, false)

private def parseABIType : P (Width × Bool × Option Subword) := do
  let subword := match (← peek).getD "" with
    | "sb" => some Subword.signedByte | "ub" => some .unsignedByte
    | "sh" => some .signedHalf | "uh" => some .unsignedHalf | _ => none
  if subword.isSome then
    discard take
    return (.word, false, subword)
  let (width, floating) ← parseValueType
  pure (width, floating, none)

private def parseName (sigil : Char) : P String := do
  let name ← take
  let chars := name.toList
  match chars with
  | first :: rest =>
    if first != sigil || rest.isEmpty then failAt s!"expected a {sigil}-prefixed name"
    if !validIdentifier (String.ofList rest) then
      failAt "unsupported name: expected an unquoted ASCII QBE identifier"
    return String.ofList rest
  | [] => failAt "empty name"

private def parseOperand : P Operand := do
  let token ← peek
  match token with
  | some "thread" => discard take; return .threadSymbol (← parseName '$')
  | some "extern" => do
    discard take
    if (← peek) == some "thread" then
      discard take
      return .threadSymbol (← parseName '$')
    return .symbol (← parseName '$')
  | some s =>
    if s.startsWith "%" then return .temporary (← parseName '%')
    if s.startsWith "$" then return .symbol (← parseName '$')
    if s.startsWith "s_" || s.startsWith "d_" then
      discard take
      match Numeric.floatBits s with
      | .ok bits => return .constant bits
      | .error reason => failAt reason
    match s.toInt? with
    | some n =>
      if n < -(2 ^ 63 : Int) || n > (2 ^ 64 : Int) - 1 then
        failAt "constant is outside the supported 64-bit QBE bit-pattern domain"
      discard take
      return .constant n
    | none => failAt "unsupported operand: expected temporary, symbol or decimal integer"
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

private def parseArguments : Nat → Bool → P (Array CallArgument)
  | 0, _ => failAt "call argument parsing limit exceeded"
  | fuel + 1, variadic => do
    if (← peek) == some ")" then return #[]
    if (← peek) == some "..." then
      if variadic then failAt "duplicate variadic call marker"
      discard take
      if (← peek) == some ")" then return #[]
      expect ","
      if (← peek) == some ")" then failAt "trailing comma in call arguments"
      return ← parseArguments fuel true
    let environment := (← peek) == some "env"
    let (width, floating, subword) ← if environment then do discard take; pure (Width.long, false, none) else parseABIType
    let value ← parseOperand
    if (← peek) == some "," then
      discard take
      if (← peek) == some ")" then failAt "trailing comma in call arguments"
      return #[{ width, value, variadic, environment, floating, subword }] ++ (← parseArguments fuel variadic)
    return #[{ width, value, variadic, environment, floating, subword }]

private def parseCall : P (CallTarget × Array CallArgument) := do
  let target ← if ((← peek).getD "").startsWith "$" then
      CallTarget.direct <$> parseName '$'
    else CallTarget.indirect <$> parseOperand
  expect "("
  let arguments ← parseArguments (maxIntegerArguments + 3) false
  expect ")"
  pure (target, arguments)

private def floatComparisonName (name : String) : Option (FloatComparison × Width) := Id.run do
  let names : List (String × FloatComparison) := [("ceq", .eq), ("cne", .ne),
    ("cle", .le), ("clt", .lt), ("cge", .ge), ("cgt", .gt), ("co", .ordered), ("cuo", .unordered)]
  for (stem, op) in names do
    if name == stem ++ "s" then return some (op, .word)
    if name == stem ++ "d" then return some (op, .long)
  return none

private def conversionName : String → Option FloatConversion
  | "exts" => some .extendSingle | "truncd" => some .truncateDouble
  | "stosi" => some (.toInteger .word true) | "stoui" => some (.toInteger .word false)
  | "dtosi" => some (.toInteger .long true) | "dtoui" => some (.toInteger .long false)
  | "swtof" => some (.fromInteger .word true) | "uwtof" => some (.fromInteger .word false)
  | "sltof" => some (.fromInteger .long true) | "ultof" => some (.fromInteger .long false)
  | _ => none

private def parseOperation (floating : Bool) (name : String) : P Operation := do
  if let some op := conversionName name then pure (.convert op (← parseOperand))
  else if name == "cast" then pure (.cast (← parseOperand))
  else if floating && name == "neg" then pure (.floatNegate (← parseOperand))
  else if floating && ["add", "sub", "mul", "div"].contains name then do
    let op := if name == "add" then FloatBinary.add else if name == "sub" then .sub
      else if name == "mul" then .mul else .div
    let lhs ← parseOperand
    expect ","
    pure (.floatBinary op lhs (← parseOperand))
  else if let some (op, width) := floatComparisonName name then do
    let lhs ← parseOperand
    expect ","
    pure (.floatCompare op width lhs (← parseOperand))
  else if name == "copy" then
    pure (.copy (← parseOperand))
  else if name == "vaarg" then
    pure (.vaArg (← parseOperand))
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
      | "load" | "loadl" | "loads" | "loadd" => some .plain | _ => none then
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
  let (width, floating, callSubword) ← parseABIType
  let name ← take
  if callSubword.isSome && name != "call" then failAt "subword result type is only valid for calls"
  if name == "phi" then
    pure (.inl { destination, width, floating, incoming := ← parseIncoming 65 })
  else
    pure (.inr (.assign { destination, width, floating, callSubword, operation := ← parseOperation floating name }))

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

private def parseParameters : Nat → P (Array Parameter × Bool)
  | 0 => failAt "parameter parsing limit exceeded"
  | fuel + 1 => do
    if (← peek) == some ")" then return (#[], false)
    if (← peek) == some "..." then
      discard take
      return (#[], true)
    let environment := (← peek) == some "env"
    let (width, floating, subword) ← if environment then do discard take; pure (Width.long, false, none) else parseABIType
    let name ← parseName '%'
    if (← peek) == some "," then
      discard take
      if (← peek) == some ")" then failAt "trailing comma in parameters"
      let (rest, variadic) ← parseParameters fuel
      return (#[{ name, width, environment, floating, subword }] ++ rest, variadic)
    return (#[{ name, width, environment, floating, subword }], false)

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
        else if token == "stores" || token == "stored" then do
          discard take
          let value ← parseOperand
          expect ","
          pure (.inr (.storeFloat (if token == "stores" then .word else .long) value (← parseOperand)))
        else if token == "vastart" then do
          discard take
          pure (.inr (.vaStart (← parseOperand)))
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

private def parseFunction (exported : Bool) : P Function := do
  expect "function"
  let result ← if ((← peek).getD "").startsWith "$" then pure none else some <$> parseABIType
  let resultWidth := result.map (·.1)
  let resultFloating := result.any (·.2.1)
  let resultSubword := result.bind (·.2.2)
  let name ← parseName '$'
  expect "("
  let (parameters, variadic) ← parseParameters (maxIntegerArguments + 3)
  expect ")"
  expect "{"
  let blocks ← parseBlocks resultWidth 65
  expect "}"
  return { name, exported, resultWidth, resultFloating, resultSubword, parameters, variadic, blocks }

private def parseDataInteger : P Int := do
  let token ← take
  let some value := token.toInt? | failAt "expected decimal integer data initializer"
  if value < -(2 ^ 63 : Int) || value > (2 ^ 64 : Int) - 1 then
    failAt "data constant is outside the supported 64-bit domain"
  pure value

private def parseDataBits : P Int := do
  let token := (← peek).getD ""
  if token.startsWith "s_" || token.startsWith "d_" then
    discard take
    match Numeric.floatBits token with
    | .ok bits => pure bits
    | .error reason => failAt reason
  else parseDataInteger

private def parseDataString : P (Array UInt8) := do
  let token ← take
  let chars := token.toList.toArray
  if chars.size < 2 || chars[0]! != '"' || chars[chars.size - 1]! != '"' then
    failAt "unterminated data string (multiline strings are not yet supported)"
  let mut result := #[]
  let mut index := 1
  for _ in [:chars.size] do
    if index >= chars.size - 1 then return result
    let c := chars[index]!
    index := index + 1
    if c != '\\' then
      result := result ++ (String.singleton c).toUTF8.data
    else
      if index >= chars.size - 1 then failAt "unterminated string escape"
      let escape := chars[index]!
      index := index + 1
      if '0' <= escape && escape <= '7' then
        let mut value := escape.toNat - '0'.toNat
        for _ in [:2] do
          if index < chars.size - 1 && '0' <= chars[index]! && chars[index]! <= '7' then
            value := value * 8 + chars[index]!.toNat - '0'.toNat
            index := index + 1
          else break
        if value > 255 then failAt "octal string escape exceeds one byte"
        result := result.push value.toUInt8
      else
        let value ← match escape with
          | 'n' => pure 10 | 'r' => pure 13 | 't' => pure 9
          | 'b' => pure 8 | 'f' => pure 12 | 'v' => pure 11 | 'a' => pure 7
          | '\\' => pure 92 | '"' => pure 34
          | _ => failAt "unsupported string escape; use an octal byte escape"
        result := result.push value
  failAt "string decoding limit exceeded"

private def parseData (exported threadLocal : Bool) : P DataDefinition := do
  expect "data"
  let name ← parseName '$'
  expect "="
  let alignment ← if (← peek) == some "align" then do
      discard take
      let n ← parseDataInteger
      if n <= 0 || n > 64 then failAt "data alignment must be a power of two in 1..64"
      pure n.toNat
    else pure 8
  expect "{"
  let mut items := #[]
  for _ in [:50000] do
    if (← peek) == some "}" then
      discard take
      return { name, exported, alignment, threadLocal, items }
    let kind ← take
    if kind == "z" then
      let bytes ← parseDataInteger
      if bytes < 0 || bytes > 1024 * 1024 then failAt "zero fill size must be in 0..1048576"
      items := items.push (.zeroes bytes.toNat)
    else
      let width ← match kind with
        | "b" => pure MemoryWidth.byte | "h" => pure .half
        | "w" | "s" => pure .word | "l" | "d" => pure .long
        | _ => failAt "unsupported data type: expected b, h, w, l, s, d or z"
      let mut count := 0
      for _ in [:50000] do
        if (← peek) == some "," || (← peek) == some "}" then break
        let item ← if ((← peek).getD "").startsWith "\"" then do
            if width != .byte then failAt "string initializer requires b"
            pure (DataItem.byteString (← parseDataString))
          else if ((← peek).getD "").startsWith "$" then do
            if width != .long then failAt "symbol data initializer currently requires l"
            let symbol ← parseName '$'
            let offset ← if (← peek) == some "+" then do
                discard take
                parseDataInteger
              else pure 0
            pure (DataItem.address symbol offset)
          else pure (.integer width (← parseDataBits))
        items := items.push item
        count := count + 1
      if count == 0 then failAt "data field requires at least one initializer"
    if (← peek) == some "," then discard take
    else if (← peek) != some "}" then failAt "expected ',' or '}' after data field"
  failAt "data initializer parsing limit exceeded"

private def parseDefinitions : Nat → P Module
  | 0 => failAt "module definition parsing limit exceeded"
  | fuel + 1 => do
    if (← peek).isNone then return {}
    let mut exported := false
    let mut threadLocal := false
    for _ in [:3] do
      if (← peek) == some "export" then
        if exported then failAt "duplicate export linkage"
        discard take
        exported := true
      else if (← peek) == some "thread" then
        if threadLocal then failAt "duplicate thread linkage"
        discard take
        threadLocal := true
      else break
    if (← peek) == some "data" then
      let data ← parseData exported threadLocal
      let rest ← parseDefinitions fuel
      return { rest with data := #[data] ++ rest.data }
    else
      if threadLocal then failAt "thread linkage requires data"
      let f ← parseFunction exported
      let rest ← parseDefinitions fuel
      return { rest with functions := #[f] ++ rest.functions }

def parseModule (source : String) : Except String Module := do
  if source.utf8ByteSize > 1024 * 1024 then throw "input exceeds 1 MiB initial resource limit"
  let tokens := tokenize source
  if tokens.isEmpty then throw "input contains no functions or data"
  if tokens.size > 50000 then throw "input exceeds initial token limit"
  let (program, _) ← (parseDefinitions (min (tokens.size + 1) 1025)).run { tokens }
  return program

/-- Legacy function-only API rejects data rather than silently discarding it. -/
def parse (source : String) : Except String Program := do
  let module ← parseModule source
  if !module.data.isEmpty then throw "module contains data; use Parser.parseModule"
  return module.functions

end LeanCompilerBackend.Parser
