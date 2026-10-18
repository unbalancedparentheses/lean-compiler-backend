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

private def parseInstruction : P Instruction := do
  let destination ← parseName '%'
  expect "="
  let width ← parseWidth
  let name ← take
  let operation ← if name == "copy" then
    pure (.copy (← parseOperand))
  else do
    let op ← match name with
      | "add" => pure Binary.add
      | "sub" => pure Binary.sub
      | "mul" => pure Binary.mul
      | "and" => pure Binary.andBits
      | "or" => pure Binary.orBits
      | "xor" => pure Binary.xorBits
      | _ => failAt s!"unsupported operation '{name}'"
    let lhs ← parseOperand
    expect ","
    let rhs ← parseOperand
    pure (.binary op lhs rhs)
  return { destination, width, operation }

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

private def parseBody : Nat → P (Array Instruction × Operand)
  | 0 => failAt "instruction parsing limit exceeded"
  | fuel + 1 => do
    if (← peek) == some "ret" then
      discard take
      return (#[], ← parseOperand)
    let inst ← parseInstruction
    let (rest, result) ← parseBody fuel
    return (#[inst] ++ rest, result)

private def parseFunction : P Function := do
  let exported := (← peek) == some "export"
  if exported then discard take
  expect "function"
  let resultWidth ← parseWidth
  let name ← parseName '$'
  expect "("
  let parameters ← parseParameters 10
  expect ")"
  expect "{"
  let entryLabel ← parseName '@'
  let (instructions, result) ← parseBody 481
  expect "}"
  return { name, exported, resultWidth, parameters, entryLabel, instructions, result }

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
