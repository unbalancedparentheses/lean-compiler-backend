/-
  QBE-compatible lexical and grammar subset, adapted from QBE 1.3 parse.c
  and doc/il.txt. See docs/UPSTREAM.md and third_party/qbe/LICENSE.
  Unsupported constructs are errors; no partial successful compilation.
-/
import LeanCompilerBackend.Numeric
import LeanCompilerBackend.Aggregate

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
  let mut current := ""
  let mut quoted := false
  let mut escaped := false
  let mut comment := false
  let mut line := 1
  let mut tokenLine := 1
  for c in source do
    if comment then
      if c == '\n' then
        comment := false
        line := line + 1
      continue
    if current.isEmpty then tokenLine := line
    if quoted then
      current := current.push c
      if escaped then escaped := false
      else if c == '\\' then escaped := true
      else if c == '"' then
        quoted := false
        tokens := tokens.push ⟨current, tokenLine⟩
        current := ""
    else if c == '"' then
      quoted := true
      current := current.push c
    else if c == '#' then
      if !current.isEmpty then
        tokens := tokens.push ⟨current, tokenLine⟩
        current := ""
      comment := true
    else if c == '+' && ((current.startsWith "s_") || (current.startsWith "d_")) &&
        (current.endsWith "e" || current.endsWith "E" || current.endsWith "p" || current.endsWith "P" || current.endsWith "_") then
      current := current.push c
    else if c.isWhitespace || separator c then
      if !current.isEmpty then
        tokens := tokens.push ⟨current, tokenLine⟩
        current := ""
      if separator c then tokens := tokens.push ⟨String.singleton c, line⟩
    else current := current.push c
    if c == '\n' then line := line + 1
  if !current.isEmpty then tokens := tokens.push ⟨current, tokenLine⟩
  return tokens

private structure Cursor where
  tokens : Array Token
  position : Nat := 0
  typeNames : List String := []
  debugFile : Option String := none

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

private def parseName (sigil : Char) : P String := do
  let name ← take
  let chars := name.toList
  match chars with
  | first :: rest =>
    if first != sigil || rest.isEmpty then failAt s!"expected a {sigil}-prefixed name"
    let result := String.ofList rest
    if sigil == '$' && result.startsWith "\"" then
      if !validGlobalName result then failAt "invalid quoted global name"
      return result
    if !validIdentifier result then
      failAt "unsupported name: expected an unquoted ASCII QBE identifier"
    return result
  | [] => failAt "empty name"

private def parseABIType : P (Width × Bool × Option Subword × Option String) := do
  if ((← peek).getD "").startsWith ":" then
    let name ← parseName ':'
    if !(← get).typeNames.contains name then failAt s!"unsupported type: undefined aggregate :{name}"
    return (.long, false, none, some name)
  let subword := match (← peek).getD "" with
    | "sb" => some Subword.signedByte | "ub" => some .unsignedByte
    | "sh" => some .signedHalf | "uh" => some .unsignedHalf | _ => none
  if subword.isSome then
    discard take
    return (.word, false, subword, none)
  let (width, floating) ← parseValueType
  pure (width, floating, none, none)

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

private def parseArguments : Nat → Bool → P (Array CallArgument × Bool)
  | 0, _ => failAt "call argument parsing limit exceeded"
  | fuel + 1, variadic => do
    if (← peek) == some ")" then return (#[], variadic)
    if (← peek) == some "..." then
      if variadic then failAt "duplicate variadic call marker"
      discard take
      if (← peek) == some ")" then return (#[], true)
      expect ","
      if (← peek) == some ")" then failAt "trailing comma in call arguments"
      return ← parseArguments fuel true
    let environment := (← peek) == some "env"
    let (width, floating, subword, aggregate) ← if environment then do discard take; pure (Width.long, false, none, none) else parseABIType
    let value ← parseOperand
    if (← peek) == some "," then
      discard take
      if (← peek) == some ")" then failAt "trailing comma in call arguments"
      let (rest, marker) ← parseArguments fuel variadic
      return (#[{ width, value, variadic, environment, floating, subword, aggregate }] ++ rest, marker)
    return (#[{ width, value, variadic, environment, floating, subword, aggregate }], variadic)

private def parseCall : P (CallTarget × Array CallArgument × Bool) := do
  let target ← if ((← peek).getD "").startsWith "$" then
      CallTarget.direct <$> parseName '$'
    else CallTarget.indirect <$> parseOperand
  expect "("
  let (arguments, variadic) ← parseArguments (maxIntegerArguments + 3) false
  expect ")"
  pure (target, arguments, variadic)

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
    let (target, arguments, variadic) ← parseCall
    pure (.call target arguments variadic)
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

private def parseIncoming (limit : Nat) : P (Array (String × Operand)) := do
  let mut incoming := #[]
  for _ in [:limit] do
    let label ← parseName '@'
    let value ← parseOperand
    incoming := incoming.push (label, value)
    if (← peek) == some "," then discard take
    else return incoming
  failAt "phi incoming-edge limit exceeded"

private def parseDefinition : P (Sum Phi Statement) := do
  let destination ← parseName '%'
  expect "="
  let (width, floating, callSubword, callAggregate) ← parseABIType
  let name ← take
  if callSubword.isSome && name != "call" then failAt "subword result type is only valid for calls"
  if callAggregate.isSome && name != "call" then failAt "aggregate result type is only valid for calls"
  if name == "phi" then
    pure (.inl { destination, width, floating, incoming := ← parseIncoming (maxCompatibilityBlocks + 1) })
  else
    pure (.inr (.assign { destination, width, floating, callSubword, callAggregate, operation := ← parseOperation floating name }))

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
    let (width, floating, subword, aggregate) ← if environment then do discard take; pure (Width.long, false, none, none) else parseABIType
    let name ← parseName '%'
    if (← peek) == some "," then
      discard take
      if (← peek) == some ")" then failAt "trailing comma in parameters"
      let (rest, variadic) ← parseParameters fuel
      return (#[{ name, width, environment, floating, subword, aggregate }] ++ rest, variadic)
    return (#[{ name, width, environment, floating, subword, aggregate }], false)

private def parseBody (resultWidth : Option Width) (limit : Nat) : P (Array Phi × Array Statement × Terminator × Array DebugLocation) := do
  let mut phis := #[]
  let mut instructions := #[]
  let mut debugLocations := #[]
  -- Debug directives consume tokens, but are not IR instructions.
  let cursor ← get
  for _ in [:cursor.tokens.size - cursor.position + 1] do
    if (← peek) == some "dbgloc" then
      discard take
      let some line := (← take).toNat? | failAt "expected nonnegative debug line"
      let column ← if (← peek) == some "," then do
        discard take
        let some value := (← take).toNat? | failAt "expected nonnegative debug column"
        pure value
      else pure 0
      if line >= 2^29 || column >= 2^29 then failAt "debug location exceeds 29-bit QBE limit"
      if (← get).debugFile.isNone then failAt "dbgloc requires a preceding dbgfile"
      debugLocations := debugLocations.push { instruction := instructions.size, line, column }
    else if (← peek) == some "ret" then
      discard take
      -- A bare ret is valid even in a typed function (e.g. an unreachable
      -- fallthrough block emitted by C frontends). Preserve the absent value.
      let next ← peek
      let bare := next.isNone || next == some "}" || next.any (·.startsWith "@")
      let value ← if resultWidth.isSome && !bare then some <$> parseOperand else pure none
      return (phis, instructions, .ret value, debugLocations)
    else if (← peek) == some "jmp" then
      discard take
      return (phis, instructions, .jump (← parseName '@'), debugLocations)
    else if (← peek) == some "jnz" then
      discard take
      let condition ← parseOperand
      expect ","
      let yes ← parseName '@'
      expect ","
      return (phis, instructions, .branch condition yes (← parseName '@'), debugLocations)
    else if (← peek) == some "hlt" then
      discard take
      return (phis, instructions, .halt, debugLocations)
    else if let some token := ← peek then
      if token.startsWith "@" then
        -- QBE permits fallthrough when the next label begins a new block.
        return (phis, instructions, .jump (String.ofList token.toList.tail), debugLocations)
      else
        if phis.size + instructions.size >= limit - 1 then
          failAt "instruction parsing limit exceeded"
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
          let (target, arguments, variadic) ← parseCall
          pure (.inr (.callVoid target arguments variadic))
        else parseDefinition
        match definition with
        | .inl phi =>
          if !instructions.isEmpty || !debugLocations.isEmpty then failAt "phi definitions must precede ordinary instructions"
          phis := phis.push phi
        | .inr inst => instructions := instructions.push inst
    else failAt "expected block terminator"

  failAt "instruction parsing limit exceeded"

private def parseBlocks (resultWidth : Option Width) (limit : Nat) : P (Array Block) := do
  let mut blocks := #[]
  for _ in [:limit] do
    let label ← parseName '@'
    let (phis, instructions, terminator, debugLocations) ← parseBody resultWidth (maxCompatibilityInstructions + 1)
    blocks := blocks.push { label, phis, instructions, terminator, debugLocations }
    if !((← peek).getD "").startsWith "@" then return blocks
  failAt "block parsing limit exceeded"

private def parseFunction (exported : Bool) : P Function := do
  expect "function"
  let result ← if ((← peek).getD "").startsWith "$" then pure none else some <$> parseABIType
  let resultWidth := result.map (·.1)
  let resultFloating := result.any (·.2.1)
  let resultSubword := result.bind (·.2.2.1)
  let resultAggregate := result.bind (·.2.2.2)
  let name ← parseName '$'
  expect "("
  let (parameters, variadic) ← parseParameters (maxIntegerArguments + 3)
  expect ")"
  expect "{"
  let blocks ← parseBlocks resultWidth (maxCompatibilityBlocks + 1)
  expect "}"
  return { name, exported, resultWidth, resultFloating, resultSubword, resultAggregate, parameters, variadic, blocks, debugFile := (← get).debugFile }

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
    failAt "unterminated data string"
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
      if bytes < 0 || bytes > 256 * 1024 * 1024 then failAt "zero fill size must be in 0..268435456"
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
            let symbol ← parseName '$'
            let offset ← if (← peek) == some "+" then do
                discard take
                parseDataInteger
              else pure 0
            pure (DataItem.address width symbol offset)
          else pure (.integer width (← parseDataBits))
        items := items.push item
        count := count + 1
      if count == 0 then failAt "data field requires at least one initializer"
    if (← peek) == some "," then discard take
    else if (← peek) != some "}" then failAt "expected ',' or '}' after data field"
  failAt "data initializer parsing limit exceeded"

private def parseAggregateFields : P (Array AggregateField) := do
  expect "{"
  let mut fields := #[]
  for _ in [:4097] do
    if (← peek) == some "}" then
      discard take
      return fields
    let member ← if ((← peek).getD "").startsWith ":" then
        pure (AggregateMember.named (← parseName ':'))
      else do
        let kind ← take
        match kind with
        | "b" => pure (.scalar .byte false) | "h" => pure (.scalar .half false)
        | "w" => pure (.scalar .word false) | "l" => pure (.scalar .long false)
        | "s" => pure (.scalar .word true) | "d" => pure (.scalar .long true)
        | _ => failAt "expected aggregate member b/h/w/l/s/d or named type"
    let count ← match ((← peek).getD "").toNat? with
      | some n => discard take; pure n
      | none => pure 1
    fields := fields.push { member, count }
    if (← peek) == some "," then discard take
    else if (← peek) != some "}" then failAt "expected ',' or '}' after aggregate member"
  failAt "aggregate field limit exceeded (4096)"

private def parseAggregate : P AggregateType := do
  expect "type"
  let name ← parseName ':'
  expect "="
  let alignment ← if (← peek) == some "align" then do
      discard take
      let some n := (← take).toNat? | failAt "expected aggregate alignment"
      pure (some n)
    else pure none
  -- Inspect the first body token without consuming the record's opening brace.
  let saved ← get
  expect "{"
  if let some size := ((← peek).getD "").toNat? then
    discard take
    expect "}"
    return { name, alignment, opaqueSize := some size }
  if (← peek) == some "{" then
    let mut variants := #[]
    for _ in [:1025] do
      if (← peek) == some "}" then
        discard take
        return { name, alignment, variants, isUnion := true }
      variants := variants.push (← parseAggregateFields)
    failAt "aggregate variant limit exceeded (1024)"
  else
    set saved
    let fields ← parseAggregateFields
    return { name, alignment, variants := #[fields] }

private def parseDefinitions (fuel : Nat) : P Module := do
  let mut result : Module := {}
  for _ in [:fuel] do
    if (← peek).isNone then return result
    if (← peek) == some "dbgfile" then
      discard take
      let bytes ← parseDataString
      let some file := String.fromUTF8? ⟨bytes⟩ | failAt "debug filename must be UTF-8"
      if file.contains '\x00' then failAt "debug filename must not contain NUL"
      modify fun state => { state with debugFile := some file }
      continue
    if (← peek) == some "type" then
      let type ← parseAggregate
      modify fun state => { state with typeNames := type.name :: state.typeNames }
      result := { result with types := result.types.push type }
      continue
    let mut exported := false
    let mut threadLocal := false
    let mut common := false
    let mut customSection := none
    for _ in [:5] do
      if (← peek) == some "export" then
        if exported then failAt "duplicate export linkage"
        discard take
        exported := true
      else if (← peek) == some "thread" then
        if threadLocal then failAt "duplicate thread linkage"
        discard take
        threadLocal := true
      else if (← peek) == some "common" then
        if common then failAt "duplicate common linkage"
        discard take
        common := true
      else if (← peek) == some "section" then
        if customSection.isSome then failAt "duplicate section linkage"
        discard take
        let bytes ← parseDataString
        let some name := String.fromUTF8? ⟨bytes⟩ | failAt "section name must be UTF-8"
        let flags ← if ((← peek).getD "").startsWith "\"" then do
          let bytes ← parseDataString
          let some flags := String.fromUTF8? ⟨bytes⟩ | failAt "section flags must be UTF-8"
          pure ("," ++ flags)
        else pure ""
        customSection := some (name ++ flags)
      else break
    if (← peek) == some "data" then
      let data ← parseData exported threadLocal
      result := { result with data := result.data.push { data with common, customSection } }
    else
      if threadLocal then failAt "thread linkage requires data"
      if common then failAt "common linkage requires data"
      let f ← parseFunction exported
      result := { result with functions := result.functions.push { f with customSection } }
  failAt "module definition parsing limit exceeded (16384)"

def parseModule (source : String) : Except String Module := do
  if source.utf8ByteSize > 8 * 1024 * 1024 then throw "input exceeds 8 MiB compatibility resource limit"
  let tokens := tokenize source
  if tokens.isEmpty then throw "input contains no functions or data"
  if tokens.size > 600000 then throw "input exceeds 600000-token compatibility limit"
  let (program, _) ← (parseDefinitions (min (tokens.size + 1) 16385)).run { tokens }
  discard (Aggregate.layouts program.types)
  return program

/-- Legacy function-only API rejects data rather than silently discarding it. -/
def parse (source : String) : Except String Program := do
  let module ← parseModule source
  if !module.data.isEmpty || !module.types.isEmpty then
    throw "module contains data or types; use Parser.parseModule"
  return module.functions

end LeanCompilerBackend.Parser
