/- Executable IEEE arithmetic model for compatibility testing, not a certification theorem.
   Uses Lean's native binary32/binary64 primitives; see docs/SEMANTICS.md. -/
import LeanCompilerBackend.IR
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

end LeanCompilerBackend.Floating
