/- System V eightbyte classification and register-bank rollback for aggregates. -/
import LeanCompilerBackend.Aggregate

namespace LeanCompilerBackend.AMD64ABI

inductive Class where
  | empty | integer | floating
  deriving BEq, Inhabited, Repr

structure Info where
  layout : Aggregate.Layout
  classes : Array Class
  memory : Bool
  deriving Inhabited, Repr

private def walk : Nat → Array Aggregate.Layout → Aggregate.Layout → Nat → Array Class → Except String (Array Class × Bool)
  | 0, _, _, _, _ => throw "AMD64 aggregate nesting limit exceeded"
  | fuel+1, layouts, layout, base, initial => do
    let mut classes := initial
    let mut unknownLayout := layout.isOpaque
    for variant in layout.variants do
      for field in variant do
        if field.stride == 0 then continue
        for i in [:field.field.count] do
          let offset := base + field.offset + i*field.stride
          match field.field.member with
          | .scalar width floating =>
            for byte in [offset:offset+width.bytes] do
              let index := byte / 8
              if index >= classes.size then throw "AMD64 aggregate classification exceeds object extent"
              let kind := if floating && classes[index]! != .integer then Class.floating else .integer
              classes := classes.set! index kind
          | .named name =>
            let some nested := layouts.find? (·.name == name) | throw "undefined nested AMD64 aggregate"
            let (updated, unknown) ← walk fuel layouts nested offset classes
            classes := updated
            unknownLayout := unknownLayout || unknown
    pure (classes, unknownLayout)

def classify (types : Array AggregateType) : Except String (Array Info) := do
  let layouts ← Aggregate.layouts types
  layouts.mapM fun layout => do
    if layout.isOpaque || layout.size == 0 || layout.size > 16 then
      return { layout, classes := #[], memory := true }
    let (classes, unknownLayout) ← walk 1025 layouts layout 0 (Array.replicate ((layout.size+7)/8) Class.empty)
    pure { layout, classes, memory := unknownLayout }

def find (types : Array Info) (name : String) : Except String Info := do
  let some info := types.find? (·.layout.name == name) | throw s!"undefined aggregate type :{name}"
  if info.layout.alignment > 16 then throw "AMD64 aggregate alignments above 16 are not yet implemented"
  if info.layout.size > 1048576 then throw "AMD64 aggregate exceeds 1048576-byte resource limit"
  pure info

inductive Location where
  | integer (index : Nat) | floating (index : Nat) | stack (offset : Nat) | environment
  | aggregate (chunks : Array (Bool × Nat × Nat))
  deriving Inhabited, Repr

structure Plan where
  places : Array Location := #[]
  ngp : Nat := 0
  nfp : Nat := 0
  stackBytes : Nat := 0
  deriving Repr

private def align (n a : Nat) : Nat := (n+a-1)/a*a

def plan (types : Array Info) (args : Array CallArgument) (memoryResult : Bool := false) (variadicCall : Bool := false) : Except String Plan := do
  let mut p : Plan := { ngp := if memoryResult then 1 else 0 }
  if args.any (·.environment) && (variadicCall || args.any (·.variadic)) then
    throw "AMD64 System V does not support variadic environment calls"
  for arg in args do
    if let some name := arg.aggregate then
      let info ← find types name
      let ngp := info.classes.toList.count .integer
      let nfp := info.classes.toList.count .floating
      if !info.memory && p.ngp+ngp <= 6 && p.nfp+nfp <= 8 then
        let mut chunks := #[]
        for i in [:info.classes.size] do
          match info.classes[i]! with
          | .integer => chunks := chunks.push (false,p.ngp,i*8); p := { p with ngp := p.ngp+1 }
          | .floating => chunks := chunks.push (true,p.nfp,i*8); p := { p with nfp := p.nfp+1 }
          | .empty => pure ()
        p := { p with places := p.places.push (.aggregate chunks) }
      else
        -- A failed aggregate allocation consumes neither bank (SysV rollback).
        let offset := align p.stackBytes (max 8 info.layout.alignment)
        p := { p with places := p.places.push (.stack offset), stackBytes := offset + align info.layout.size 8 }
    else if arg.environment then p := { p with places := p.places.push .environment }
    else if arg.floating && p.nfp < 8 then
      p := { p with places := p.places.push (.floating p.nfp), nfp := p.nfp+1 }
    else if !arg.floating && p.ngp < 6 then
      p := { p with places := p.places.push (.integer p.ngp), ngp := p.ngp+1 }
    else p := { p with places := p.places.push (.stack p.stackBytes), stackBytes := p.stackBytes+8 }
  pure p

end LeanCompilerBackend.AMD64ABI
