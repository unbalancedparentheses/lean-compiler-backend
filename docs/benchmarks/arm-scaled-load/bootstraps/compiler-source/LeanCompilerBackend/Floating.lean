/- Executable IEEE arithmetic model for compatibility testing, not a certification theorem.
   Uses Lean's native binary32/binary64 primitives; see docs/SEMANTICS.md. -/
import LeanCompilerBackend.Numeric
import Init.Data.Float

namespace LeanCompilerBackend.Floating

def binary (width : Width) (op : FloatBinary) (a b : UInt64) : UInt64 :=
  if width == .word then
    let x := Float32.ofBits a.toUInt32
    let y := Float32.ofBits b.toUInt32
    let result := match op with
      | .add => x + y | .sub => x - y | .mul => x * y | .div => x / y
    result.toBits.toUInt64
  else
    let x := Float.ofBits a
    let y := Float.ofBits b
    let result := match op with
      | .add => x + y | .sub => x - y | .mul => x * y | .div => x / y
    result.toBits

def compare (width : Width) (op : FloatComparison) (a b : UInt64) : UInt64 :=
  let result := if width == .word then
    let x := Float32.ofBits a.toUInt32
    let y := Float32.ofBits b.toUInt32
    match op with
    | .eq => x == y | .ne => x != y
    | .le => decide (x ≤ y) | .lt => decide (x < y)
    | .ge => decide (x ≥ y) | .gt => decide (x > y)
    | .ordered => !(x.isNaN || y.isNaN) | .unordered => x.isNaN || y.isNaN
  else
    let x := Float.ofBits a
    let y := Float.ofBits b
    match op with
    | .eq => x == y | .ne => x != y
    | .le => decide (x ≤ y) | .lt => decide (x < y)
    | .ge => decide (x ≥ y) | .gt => decide (x > y)
    | .ordered => !(x.isNaN || y.isNaN) | .unordered => x.isNaN || y.isNaN
  if result then 1 else 0

/-- Truncate exactly, then reject values outside the target integer domain.
    Native invalid conversions are target-dependent and are not modeled here. -/
private def toInteger (input output : Width) (signed : Bool) (value : UInt64)
    : Except String UInt64 := do
  let (fractionBits, exponentBits) : Nat × Nat := if input == .word then (23, 8) else (52, 11)
  let raw := value.toNat
  let exponent := (raw / 2 ^ fractionBits) % 2 ^ exponentBits
  if exponent == 2 ^ exponentBits - 1 then throw "non-finite floating-to-integer conversion; result not evaluated"
  let fraction := raw % 2 ^ fractionBits
  let significand := fraction + (if exponent == 0 then 0 else 2 ^ fractionBits)
  let bias : Nat := 2 ^ (exponentBits - 1) - 1
  let shift : Int := ((if exponent == 0 then 1 else exponent : Nat) : Int) - (bias : Int) - (fractionBits : Int)
  let magnitude : Nat := if shift >= 0 then significand * 2 ^ shift.toNat else significand / 2 ^ shift.natAbs
  let negative := raw / 2 ^ (input.bits - 1) % 2 == 1
  let integer : Int := if negative then -(magnitude : Int) else magnitude
  let minimum : Int := if signed then -(2 ^ (output.bits - 1) : Int) else 0
  let maximum : Int := 2 ^ (output.bits - (if signed then 1 else 0)) - 1
  if integer < minimum || integer > maximum then throw "out-of-range floating-to-integer conversion; result not evaluated"
  pure (BitVec.ofInt output.bits integer).toNat.toUInt64

def convert (output : Width) (op : FloatConversion) (value : UInt64) : Except String UInt64 :=
  match op with
  | .extendSingle => pure (Float32.ofBits value.toUInt32).toFloat.toBits
  | .truncateDouble => pure (Float.ofBits value).toFloat32.toBits.toUInt64
  | .toInteger input signed => toInteger input output signed value
  | .fromInteger input signed =>
    let raw := value.toNat % 2 ^ input.bits
    let integer : Int := if signed && raw >= 2 ^ (input.bits - 1) then (raw : Int) - 2 ^ input.bits else raw
    pure (Numeric.integerBits output integer)

end LeanCompilerBackend.Floating
