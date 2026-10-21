/- Apple ARM64 aggregate classification; based on pinned QBE arm64/abi.c.
   This module plans locations, not instructions or memory semantics. -/
import LeanCompilerBackend.Aggregate

namespace LeanCompilerBackend.AggregateABI

inductive Passing where
  | general (count : Nat)
  | homogeneous (width : Width) (count : Nat)
  | indirect
  deriving Repr, Inhabited, BEq

structure TypeInfo where
  layout : Aggregate.Layout
  passing : Passing
  deriving Repr, Inhabited

private def homogeneous (layout : Aggregate.Layout) (known : Array (String × Option Width))
    : Option Width := Id.run do
  if layout.isOpaque then return none
  let mut kind : Option Width := none
  let mut extent := 0
  for variant in layout.variants do
    let mut endOffset := 0
    for field in variant do
      if field.offset != endOffset then return none
      let element := match field.field.member with
        | .scalar .word true => some Width.word
        | .scalar .long true => some Width.long
        | .named name => (known.find? (·.1 == name)).bind (·.2)
        | _ => none
      let some element := element | return none
      -- A zero repetition contributes no members, but may introduce padding.
      if field.field.count != 0 then
        if kind.isSome && kind != some element then return none
        kind := some element
      endOffset := field.offset + field.stride * field.field.count
    extent := max extent endOffset
  -- Tail padding is not another floating member. This also prevents a padded
  -- nested type from being mistaken for an HFA (pinned QBE does so).
  if extent != layout.size then return none
  return kind

/-- Layout can admit over-aligned types, but this ABI preserves QBE's <=8 limit. -/
def classify (types : Array AggregateType) : Except String (Array TypeInfo) := do
  let layouts ← Aggregate.layouts types
  let mut known := #[]
  let mut result := #[]
  for layout in layouts do
    let kind := homogeneous layout known
    known := known.push (layout.name, kind)
    let passing := match kind with
      | some width =>
        let count := layout.size / width.bytes
        if count > 0 && count <= 4 && layout.size % width.bytes == 0 then
          Passing.homogeneous width count
        else if layout.size > 16 || layout.size == 0 then .indirect
        else .general ((layout.size + 7) / 8)
      | none => if layout.isOpaque || layout.size > 16 || layout.size == 0 then .indirect
        else .general ((layout.size + 7) / 8)
    result := result.push { layout, passing }
  return result

def find (types : Array TypeInfo) (name : String) : Except String TypeInfo := do
  let some info := types.find? (·.layout.name == name) | throw s!"undefined aggregate type :{name}"
  if info.layout.alignment > 8 then throw "aggregate ABI alignments larger than 8 are not supported"
  if info.layout.size > 4096 then throw "aggregate ABI size exceeds the 4096-byte resource limit"
  pure info

inductive Location where
  | general (first count : Nat)
  | floating (first count : Nat) (width : Width)
  | stack (offset : Nat)
  deriving Repr, Inhabited

structure Argument where
  location : Location
  aggregate : Option TypeInfo := none
  /-- Private caller-owned copy for an indirectly passed aggregate. -/
  copyOffset : Option Nat := none
  deriving Repr, Inhabited

structure Plan where
  arguments : Array Argument
  stackUsed : Nat
  gpUsed : Nat := 0
  fpUsed : Nat := 0
  stackBytes : Nat
  totalBytes : Nat
  deriving Repr, Inhabited

private def align (n a : Nat) : Nat := (n + a - 1) / a * a

def plan (types : Array TypeInfo) (arguments : Array CallArgument) (darwin : Bool := true) : Except String Plan := do
  let mut result := #[]
  let mut gp := 0
  let mut fp := 0
  let mut stack := 0
  for argument in arguments do
    if argument.environment then
      result := result.push { location := .general 9 1 }
      continue
    let aggregate ← argument.aggregate.mapM (find types)
    let passing := aggregate.map (·.passing)
    let (ngp, nfp, width) := match passing with
      | some (.general n) => (n, 0, Width.long)
      | some (.homogeneous w n) => (0, n, w)
      | some .indirect => (1, 0, Width.long)
      | none => if argument.floating then (0, 1, argument.width) else (1, 0, argument.width)
    if !(darwin && argument.variadic) && gp + ngp <= 8 && fp + nfp <= 8 then
      let location := if nfp != 0 then Location.floating fp nfp width else .general gp ngp
      result := result.push { location, aggregate }
      gp := gp + ngp
      fp := fp + nfp
    else
      -- An aggregate is never split across registers and the stack. Exhaust its
      -- bank when it does not fit; the other bank remains available.
      if !(darwin && argument.variadic) then
        if gp + ngp > 8 then gp := 8
        if fp + nfp > 8 then fp := 8
      let bytes := match aggregate with
        | some info => if info.passing == .indirect then 8 else align info.layout.size 8
        | none => if !darwin || argument.variadic then 8 else (argument.subword.map (·.bytes)).getD argument.width.bytes
      let alignment := if !darwin || aggregate.isSome || argument.variadic then 8 else bytes
      stack := align stack alignment
      result := result.push { location := .stack stack, aggregate }
      stack := stack + bytes
  let stackBytes := align stack 16
  let mut endOffset := stackBytes
  for i in [:result.size] do
    if let some info := result[i]!.aggregate then
      if info.passing == .indirect then
        endOffset := align endOffset 8
        result := result.set! i { result[i]! with copyOffset := some endOffset }
        endOffset := endOffset + info.layout.size
  return { arguments := result, stackUsed := stack, gpUsed := gp, fpUsed := fp, stackBytes, totalBytes := align endOffset 16 }

end LeanCompilerBackend.AggregateABI
