/- QBE aggregate storage layout. ABI classification is a separate step.
   Reference: pinned third_party/qbe/parse.c parsefields/parsetyp. -/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Aggregate

structure FieldLayout where
  field : AggregateField
  offset : Nat
  stride : Nat
  alignment : Nat
  deriving Repr, Inhabited, BEq

structure Layout where
  name : String
  size : Nat
  alignment : Nat
  isOpaque : Bool
  variants : Array (Array FieldLayout)
  deriving Repr, Inhabited, BEq

private def roundUp (n alignment : Nat) : Nat :=
  (n + alignment - 1) / alignment * alignment

/-- Checked layouts in declaration order: no forward or recursive references.
    Natural member alignment is a lower bound, as in pinned QBE.
    Bounds are implementation limits, not QBE language restrictions. -/
def layouts (types : Array AggregateType) : Except String (Array Layout) := do
  if types.size > 1024 then throw "aggregate type limit exceeded (1024)"
  let mut result : Array Layout := #[]
  for type in types do
    if !validIdentifier type.name then throw "invalid aggregate type name"
    if result.any (·.name == type.name) then throw s!"duplicate aggregate type :{type.name}"
    let alignment := type.alignment.getD 1
    if alignment == 0 || alignment > 65536 || alignment &&& (alignment - 1) != 0 then
      throw s!"type :{type.name}: alignment must be a power of two in 1..65536"
    if let some size := type.opaqueSize then
      if type.alignment.isNone || !type.variants.isEmpty || type.isUnion then
        throw s!"type :{type.name}: opaque type requires alignment and no fields"
      if size > 1024 * 1024 then throw "aggregate size limit exceeded (1 MiB)"
      result := result.push ⟨type.name, size, alignment, true, #[]⟩
    else
      if type.variants.isEmpty || type.variants.size > 1024 then
        throw "aggregate requires 1..1024 variants"
      if !type.isUnion && type.variants.size != 1 then
        throw "record requires exactly one variant"
      let mut maxAlignment := alignment
      let mut size := 0
      let mut variants : Array (Array FieldLayout) := #[]
      for variant in type.variants do
        if variant.size > 4096 then throw "aggregate field limit exceeded (4096)"
        let mut offset := 0
        let mut fields : Array FieldLayout := #[]
        for field in variant do
          let (stride, fieldAlignment) ← match field.member with
            | .scalar width floating =>
              if floating && width != .word && width != .long then
                throw "floating aggregate member must be s or d"
              pure (width.bytes, width.bytes)
            | .named name => do
              let some nested := result.find? (·.name == name)
                | throw s!"type :{type.name}: undefined or forward aggregate reference :{name}"
              pure (nested.size, nested.alignment)
          if field.count > 1024 * 1024 then throw "aggregate repetition limit exceeded (1048576)"
          offset := roundUp offset fieldAlignment
          fields := fields.push ⟨field, offset, stride, fieldAlignment⟩
          offset := offset + stride * field.count
          if offset > 1024 * 1024 then throw "aggregate size limit exceeded (1 MiB)"
          maxAlignment := max maxAlignment fieldAlignment
        size := max size offset
        variants := variants.push fields
      size := roundUp size maxAlignment
      if size > 1024 * 1024 then throw "aggregate size limit exceeded (1 MiB)"
      result := result.push ⟨type.name, size, maxAlignment, false, variants⟩
  return result

end LeanCompilerBackend.Aggregate
