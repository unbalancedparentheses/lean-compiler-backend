/- RV64 LP64D aggregate classification and argument locations. -/
import LeanCompilerBackend.Aggregate

namespace LeanCompilerBackend.RV64ABI

structure Field where
  width : Width
  floating : Bool
  offset : Nat
  bytes : Nat
  deriving Inhabited, Repr
structure Info where
  layout : Aggregate.Layout
  fields : Array Field
  indirect : Bool
  deriving Inhabited, Repr
private def flatten : Nat → Array AggregateType → Array Aggregate.Layout → Aggregate.Layout → Nat → Except String (Option (Array Field))
  | 0, _, _, _, _ => throw "RV64 aggregate nesting limit exceeded"
  | fuel+1, types, layouts, layout, base => do
    if layout.isOpaque || (types.find? (·.name == layout.name)).any (·.isUnion) then return none
    let mut result := #[]
    for field in layout.variants[0]?.getD #[] do
      if field.stride == 0 then continue
      if field.field.count > 2 then return none
      for i in [:field.field.count] do
        let offset := base+field.offset+i*field.stride
        match field.field.member with
        | .scalar w floating => result := result.push {width := w.valueWidth, floating, offset, bytes := w.bytes}
        | .named name =>
          let some nested := layouts.find? (·.name == name) | throw "undefined RV64 aggregate"
          let some fields ← flatten fuel types layouts nested offset | return none
          result := result ++ fields
        if result.size > 2 then return none
    return some result

def classify (types : Array AggregateType) : Except String (Array Info) := do
  let layouts ← Aggregate.layouts types
  layouts.mapM fun layout => do
    let indirect := layout.isOpaque || layout.size == 0 || layout.size > 16
    if indirect then return {layout, fields := #[], indirect}
    let fields ← flatten 1025 types layouts layout 0
    pure {layout, fields := fields.getD #[], indirect}

def find (types : Array Info) (name : String) : Except String Info := do
  let some info := types.find? (·.layout.name == name) | throw s!"undefined aggregate :{name}"
  if info.layout.alignment > 16 then throw "RV64 aggregate alignment above 16 not yet implemented"
  if info.layout.size > 4096 then throw "RV64 aggregate exceeds 4096-byte resource limit"
  pure info

def integerFields (info : Info) : Array Field := Id.run do
  let mut fields := #[]
  for i in [:(info.layout.size+7)/8] do
    fields := fields.push {width := .long, floating := false, offset := i*8, bytes := min 8 (info.layout.size-i*8)}
  return fields

def fields (info : Info) (ngp nfp : Nat) (variadic : Bool := false) : Array Field :=
  let nf := (info.fields.filter (·.floating)).size
  let ni := info.fields.size-nf
  if !variadic && nf > 0 && ngp+ni <= 8 && nfp+nf <= 8 then info.fields else integerFields info

inductive Place where
  | gp (index : Nat) | fp (index : Nat) | stack (offset : Nat) | environment
  deriving Inhabited, Repr
structure Chunk where
  field : Field
  place : Place
  deriving Inhabited, Repr
structure Argument where
  chunks : Array Chunk
  indirect : Bool := false
  deriving Inhabited, Repr
structure Plan where
  arguments : Array Argument := #[]
  ngp : Nat := 0
  nfp : Nat := 0
  stackBytes : Nat := 0
  deriving Repr
private def put (p : Plan) (field : Field) : Plan × Place :=
  if field.floating && p.nfp < 8 then ({p with nfp := p.nfp+1}, .fp p.nfp)
  else if p.ngp < 8 then ({p with ngp := p.ngp+1}, .gp p.ngp)
  else ({p with stackBytes := p.stackBytes+8}, .stack p.stackBytes)

def plan (types : Array Info) (args : Array CallArgument) (memoryResult : Bool := false) : Except String Plan := do
  let mut p : Plan := {ngp := if memoryResult then 1 else 0}
  for a in args do
    if let some name := a.aggregate then
      let info ← find types name
      let fs := if info.indirect then #[{width := .long, floating := false, offset := 0, bytes := 8 : Field}]
        else fields info p.ngp p.nfp a.variadic
      -- Variadic 2*XLEN-aligned aggregates begin at an even register pair.
      if a.variadic && !info.indirect && info.layout.alignment == 16 then
        p := {p with ngp := (p.ngp+1)/2*2}
      -- Stack aggregates are naturally aligned, while split GP/stack tails use XLEN.
      if p.ngp == 8 && !(fs.any (·.floating)) then
        let alignment := if info.indirect then 8 else max 8 info.layout.alignment
        p := {p with stackBytes := (p.stackBytes+alignment-1)/alignment*alignment}
      let mut chunks := #[]
      for field in fs do
        let (next, place) := put p field
        p := next
        chunks := chunks.push {field, place}
      p := {p with arguments := p.arguments.push {chunks, indirect := info.indirect}}
    else
      let field : Field := {width := a.width, floating := a.floating && !a.variadic, offset := 0, bytes := a.width.bytes}
      let (next, place) := if a.environment then (p,Place.environment) else put p field
      p := {next with arguments := next.arguments.push {chunks := #[{field, place}]}}
  pure p

end LeanCompilerBackend.RV64ABI
