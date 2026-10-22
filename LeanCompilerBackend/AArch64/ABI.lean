/-
  Apple ARM64 scalar argument-layout helper; full emitter classification uses AggregateABI.plan.
  Adapted from QBE 1.3 arm64; see docs/UPSTREAM.md and third_party licenses.
-/
import LeanCompilerBackend.Memory

namespace LeanCompilerBackend.AArch64

/-- Apple ARM64 packs non-variadic stack scalars at their natural size/alignment.
    In particular consecutive words occupy four bytes each, not eight. This
    follows QBE 1.3 arm64/abi.c argsclass/selcall/selpar. -/
inductive ArgumentLocation where
  | register (index : Nat)
  | floatRegister (index : Nat)
  | stack (offset : Nat)
  deriving Repr, Inhabited

structure ArgumentLayout where
  locations : Array ArgumentLocation
  stackBytes : Nat
  stackUsedBytes : Nat

def argumentLayout (widths : Array Width) (variadicFrom : Nat := widths.size)
    (environment : Bool := false) (floating : Array Bool := #[]) (subwords : Array (Option Subword) := #[]) : ArgumentLayout := Id.run do
  let mut locations := #[]
  let mut offset := 0
  let mut gp := 0
  let mut fp := 0
  for i in [:widths.size] do
    if environment && i == 0 then locations := locations.push (.register 9)
    else if (floating[i]?).getD false && fp < 8 && i < variadicFrom then
      locations := locations.push (.floatRegister fp)
      fp := fp + 1
    else if !((floating[i]?).getD false) && gp < 8 && i < variadicFrom then
      locations := locations.push (.register gp)
      gp := gp + 1
    else
      let bytes := if i >= variadicFrom then 8 else (((subwords[i]?).getD none).map (·.bytes)).getD widths[i]!.bytes
      offset := alignUp offset bytes
      locations := locations.push (.stack offset)
      offset := offset + bytes
  return { locations, stackBytes := alignUp offset 16, stackUsedBytes := offset }

end LeanCompilerBackend.AArch64
