/-
  Lean Compiler Backend — initial QBE integer-IR subset.
  Adapted from QBE 1.3's class/operand/instruction discipline (all.h, ops.h).
  See docs/UPSTREAM.md and third_party/qbe/LICENSE for provenance and copyright.
  Zig's AIR/target separation is an architectural reference, not an API dependency.
-/
import Std

namespace LeanCompilerBackend

/-- Compatibility resource bounds are independent of the certified-profile plan. -/
def maxCompatibilityFunctions : Nat := 4096
def maxCompatibilityBlocks : Nat := 4096
def maxCompatibilityInstructions : Nat := 16384

/-- Unquoted QBE identifier grammar; quoted global names are a separate feature. -/
def validIdentifier (name : String) : Bool :=
  !name.isEmpty && name.toList.all (fun c =>
    c.toNat < 128 && (c.isAlphanum || c == '_' || c == '.' || c == '$')) &&
    (name.toList.head!.isAlpha || name.toList.head! == '_' || name.toList.head! == '.')

/-- Global symbols may use assembler-quoted QBE spelling. Keep escape spelling
    intact: assembler symbol quoting differs from data-string escape decoding. -/
def validGlobalName (name : String) : Bool := Id.run do
  if validIdentifier name then return true
  let chars := name.toList.toArray
  if chars.size < 3 || chars.size > 4096 || chars[0]! != '"' || chars[chars.size-1]! != '"' then return false
  let mut escaped := false
  for i in [1:chars.size-1] do
    let c := chars[i]!
    if c.toNat < 32 || c.toNat == 127 then return false
    if escaped then escaped := false
    else if c == '\\' then escaped := true
    else if c == '"' then return false
  return !escaped

inductive Width where
  | word | long
  deriving BEq, DecidableEq, Repr, Inhabited

def Width.bits : Width → Nat
  | .word => 32
  | .long => 64

def Width.bytes (width : Width) : Nat := width.bits / 8

/-- A compiler resource limit, not a limit imposed by the target ABI. -/
def maxIntegerArguments : Nat := 64

def Width.spelling : Width → String
  | .word => "w"
  | .long => "l"

inductive Operand where
  | temporary (name : String)
  | constant (value : Int)
  | symbol (name : String)
  | threadSymbol (name : String)
  deriving Repr, Inhabited

inductive Binary where
  | add | sub | mul | andBits | orBits | xorBits
  | shiftLeft | logicalRight | arithmeticRight
  deriving BEq, DecidableEq, Repr, Inhabited

def Binary.rhsWidth (width : Width) : Binary → Width
  | .shiftLeft | .logicalRight | .arithmeticRight => .word
  | _ => width

inductive Unary where
  | negate | signedByte | unsignedByte | signedHalf | unsignedHalf | signedWord | unsignedWord
  deriving BEq, DecidableEq, Repr, Inhabited

def Unary.inputWidth (width : Width) : Unary → Width
  | .negate => width
  | _ => .word

inductive Division where
  | signedDiv | unsignedDiv | signedRem | unsignedRem
  deriving BEq, DecidableEq, Repr, Inhabited

inductive Comparison where
  | eq | ne | signedLE | signedLT | signedGE | signedGT
  | unsignedLE | unsignedLT | unsignedGE | unsignedGT
  deriving BEq, DecidableEq, Repr, Inhabited

inductive MemoryWidth where
  | byte | half | word | long
  deriving BEq, DecidableEq, Repr, Inhabited

def MemoryWidth.bytes : MemoryWidth → Nat
  | .byte => 1 | .half => 2 | .word => 4 | .long => 8

def MemoryWidth.valueWidth : MemoryWidth → Width
  | .long => .long
  | _ => .word

inductive LoadKind where
  | signedByte | unsignedByte | signedHalf | unsignedHalf
  | signedWord | unsignedWord | plain
  deriving BEq, DecidableEq, Repr, Inhabited

def LoadKind.bytes (width : Width) : LoadKind → Nat
  | .signedByte | .unsignedByte => 1
  | .signedHalf | .unsignedHalf => 2
  | .signedWord | .unsignedWord => 4
  | .plain => width.bits / 8

def LoadKind.signedBits : LoadKind → Option Nat
  | .signedByte => some 8 | .signedHalf => some 16 | .signedWord => some 32
  | _ => none

inductive StackAlignment where
  | four | eight | sixteen
  deriving BEq, DecidableEq, Repr, Inhabited

def StackAlignment.bytes : StackAlignment → Nat
  | .four => 4 | .eight => 8 | .sixteen => 16

/-- ABI-only subword classes; their SSA values have base type w. -/
inductive Subword where
  | signedByte | unsignedByte | signedHalf | unsignedHalf
  deriving BEq, DecidableEq, Repr, Inhabited

def Subword.bytes : Subword → Nat
  | .signedByte | .unsignedByte => 1 | .signedHalf | .unsignedHalf => 2

def Subword.extension : Subword → Unary
  | .signedByte => .signedByte | .unsignedByte => .unsignedByte
  | .signedHalf => .signedHalf | .unsignedHalf => .unsignedHalf

inductive CallTarget where
  | direct (name : String)
  | indirect (address : Operand)
  deriving Repr, Inhabited

structure CallArgument where
  width : Width
  value : Operand
  variadic : Bool := false
  environment : Bool := false
  floating : Bool := false
  subword : Option Subword := none
  aggregate : Option String := none
  deriving Repr, Inhabited

/-- Floating values use Width for storage size; their SSA class is tracked separately. -/
inductive FloatBinary where
  | add | sub | mul | div
  deriving BEq, DecidableEq, Repr, Inhabited

inductive FloatComparison where
  | eq | ne | le | lt | ge | gt | ordered | unordered
  deriving BEq, DecidableEq, Repr, Inhabited

inductive FloatConversion where
  | extendSingle | truncateDouble
  | toInteger (input : Width) (signed : Bool)
  | fromInteger (input : Width) (signed : Bool)
  deriving BEq, DecidableEq, Repr, Inhabited

def FloatConversion.inputWidth : FloatConversion → Width
  | .extendSingle => .word | .truncateDouble => .long
  | .toInteger width _ | .fromInteger width _ => width

def FloatConversion.inputFloating : FloatConversion → Bool
  | .fromInteger .. => false | _ => true

def FloatConversion.resultFloating : FloatConversion → Bool
  | .toInteger .. => false | _ => true

inductive Operation where
  | convert (op : FloatConversion) (value : Operand)
  | floatBinary (op : FloatBinary) (lhs rhs : Operand)
  | floatNegate (value : Operand)
  | floatCompare (op : FloatComparison) (operandWidth : Width) (lhs rhs : Operand)
  | cast (value : Operand)
  | copy (value : Operand)
  | binary (op : Binary) (lhs rhs : Operand)
  | unary (op : Unary) (value : Operand)
  | divide (op : Division) (lhs rhs : Operand)
  | compare (op : Comparison) (operandWidth : Width) (lhs rhs : Operand)
  | allocate (alignment : StackAlignment) (size : Operand)
  | load (kind : LoadKind) (address : Operand)
  | vaArg (list : Operand)
  | call (target : CallTarget) (arguments : Array CallArgument)
  deriving Repr, Inhabited

def CallTarget.operands : CallTarget → List Operand
  | .direct _ => [] | .indirect value => [value]

def Operation.operands : Operation → List Operand
  | .copy x | .cast x | .convert _ x | .unary _ x | .floatNegate x
  | .allocate _ x | .load _ x | .vaArg x => [x]
  | .binary _ x y | .floatBinary _ x y | .divide _ x y
  | .compare _ _ x y | .floatCompare _ _ x y => [x, y]
  | .call target args => target.operands ++ args.toList.map (·.value)

structure Instruction where
  destination : String
  width : Width
  operation : Operation
  floating : Bool := false
  callSubword : Option Subword := none
  callAggregate : Option String := none
  deriving Repr, Inhabited

/-- Effect statements have no SSA result or artificial temporary definition. -/
inductive Statement where
  | assign (instruction : Instruction)
  | storeFloat (width : Width) (value address : Operand)
  | store (width : MemoryWidth) (value address : Operand)
  | callVoid (target : CallTarget) (arguments : Array CallArgument)
  | vaStart (list : Operand)
  | blit (source destination : Operand) (bytes : Nat)
  deriving Repr, Inhabited

def Statement.definition : Statement → Option (String × Width)
  | .assign inst => some (inst.destination, inst.width)
  | .storeFloat .. | .store .. | .callVoid .. | .blit .. | .vaStart .. => none

def Statement.callSite : Statement → Option (CallTarget × Array CallArgument × Option Width)
  | .assign { width, operation := .call target arguments, .. } => some (target, arguments, some width)
  | .callVoid target arguments => some (target, arguments, none)
  | _ => none

def Statement.resultFloating : Statement → Bool
  | .assign inst => inst.floating
  | _ => false

def Statement.resultSubword : Statement → Option Subword
  | .assign inst => inst.callSubword
  | _ => none

def Statement.resultAggregate : Statement → Option String
  | .assign inst => inst.callAggregate
  | _ => none

def Statement.operands : Statement → List Operand
  | .assign inst => inst.operation.operands
  | .store _ value address | .storeFloat _ value address => [value, address]
  | .callVoid target args => target.operands ++ args.toList.map (·.value)
  | .vaStart value => [value]
  | .blit source destination _ => [source, destination]

structure Parameter where
  name : String
  width : Width
  environment : Bool := false
  floating : Bool := false
  subword : Option Subword := none
  aggregate : Option String := none
  deriving Repr, Inhabited

structure Phi where
  destination : String
  width : Width
  floating : Bool := false
  incoming : Array (String × Operand)
  deriving Repr, Inhabited

inductive Terminator where
  | ret (value : Option Operand)
  | jump (label : String)
  | branch (condition : Operand) (ifTrue ifFalse : String)
  | halt
  deriving Repr, Inhabited

def Terminator.successors : Terminator → List String
  | .jump label => [label]
  | .branch _ yes no => [yes, no]
  | _ => []

/-- Source location before an instruction index (size denotes the terminator). -/
structure DebugLocation where
  instruction : Nat
  line : Nat
  column : Nat := 0
  deriving Repr, Inhabited

structure Block where
  label : String
  phis : Array Phi
  instructions : Array Statement
  terminator : Terminator
  debugLocations : Array DebugLocation := #[]
  deriving Repr, Inhabited

structure Function where
  name : String
  exported : Bool
  resultWidth : Option Width
  resultFloating : Bool := false
  resultSubword : Option Subword := none
  resultAggregate : Option String := none
  parameters : Array Parameter
  variadic : Bool := false
  blocks : Array Block
  debugFile : Option String := none
  customSection : Option String := none
  deriving Repr, Inhabited

def Function.locals (f : Function) : Array (String × Width) :=
  f.blocks.foldl (fun result block => result
    ++ block.phis.map (fun phi => (phi.destination, phi.width))
    ++ block.instructions.filterMap Statement.definition)
    (f.parameters.map (fun p => (p.name, p.width)))

abbrev Program := Array Function

/-- Packed initializers; addresses use the target's 64-bit pointer representation. -/
inductive DataItem where
  | integer (width : MemoryWidth) (value : Int)
  | zeroes (bytes : Nat)
  | byteString (values : Array UInt8)
  | address (name : String) (offset : Int)
  deriving Repr, Inhabited

def DataItem.byteSize : DataItem → Nat
  | .integer width _ => width.bytes
  | .zeroes bytes => bytes
  | .byteString values => values.size
  | .address .. => 8

structure DataDefinition where
  name : String
  exported : Bool := false
  alignment : Nat := 8
  threadLocal : Bool := false
  common : Bool := false
  customSection : Option String := none
  items : Array DataItem
  deriving Repr, Inhabited

def DataDefinition.byteSize (data : DataDefinition) : Nat :=
  data.items.foldl (fun size item => size + item.byteSize) 0

/-- Aggregate members retain repetition without expanding large arrays. -/
inductive AggregateMember where
  | scalar (width : MemoryWidth) (floating : Bool := false)
  | named (name : String)
  deriving Repr, Inhabited, BEq

structure AggregateField where
  member : AggregateMember
  count : Nat := 1
  deriving Repr, Inhabited, BEq

/-- Retain union identity even for a single variant (needed by RV64 ABI).
    Opaque sizes are exact, not rounded to alignment. -/
structure AggregateType where
  name : String
  alignment : Option Nat := none
  variants : Array (Array AggregateField) := #[]
  isUnion : Bool := false
  opaqueSize : Option Nat := none
  deriving Repr, Inhabited, BEq

/-- Module-level data is kept separate from the function-only compilation API. -/
structure Module where
  functions : Program := #[]
  types : Array AggregateType := #[]
  data : Array DataDefinition := #[]
  deriving Repr, Inhabited

end LeanCompilerBackend
