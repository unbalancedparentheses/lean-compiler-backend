/-
  Executable little-endian memory model for defined-behavior tests of QBE loads,
  stores and stack allocations. References: QBE 1.3 doc/il.txt and arm64/emit.c.
  Addresses here are abstract interpreter addresses, not host pointers. External
  pointers, uninitialized reads and out-of-bounds accesses have no interpreted
  result; this does not promise corresponding native runtime checks.
-/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend

structure MemoryObject where
  base : Nat
  bytes : Array (Option UInt8)
  deriving Inhabited

structure Memory where
  objects : Array MemoryObject := #[]
  nextAddress : Nat := 65536
  allocatedBytes : Nat := 0
  deriving Inhabited

def alignUp (value alignment : Nat) : Nat :=
  (value + alignment - 1) / alignment * alignment

def Memory.allocate (memory : Memory) (alignment : StackAlignment) (size : Nat)
    : Except String (UInt64 × Memory) := do
  if memory.allocatedBytes + size > 1024 * 1024 then
    throw "interpreter memory budget exceeded; result not evaluated"
  let base := alignUp memory.nextAddress alignment.bytes
  let object := { base, bytes := Array.replicate size none : MemoryObject }
  let updated := Memory.mk (memory.objects.push object) (base + size + 16)
    (memory.allocatedBytes + size)
  pure (base.toUInt64, updated)

private def Memory.locate (memory : Memory) (address : UInt64) (size : Nat)
    : Except String (Nat × Nat) := do
  let address := address.toNat
  for i in [:memory.objects.size] do
    let object := memory.objects[i]!
    if object.base <= address && address + size <= object.base + object.bytes.size then
      return (i, address - object.base)
  throw "undefined or external memory access outside an allocated object"

def Memory.read (memory : Memory) (address : UInt64) (size : Nat)
    : Except String UInt64 := do
  let (index, offset) ← memory.locate address size
  let object := memory.objects[index]!
  let mut value : UInt64 := 0
  for i in [:size] do
    let some byte := object.bytes[offset + i]! | throw "undefined uninitialized memory read"
    value := value ||| (byte.toUInt64 <<< (i * 8).toUInt64)
  pure value

def Memory.write (memory : Memory) (address : UInt64) (size : Nat) (value : UInt64)
    : Except String Memory := do
  let (index, offset) ← memory.locate address size
  let mut object := memory.objects[index]!
  for i in [:size] do
    let byte := ((value >>> (i * 8).toUInt64) &&& 255).toUInt8
    object := { object with bytes := object.bytes.set! (offset + i) (some byte) }
  pure { memory with objects := memory.objects.set! index object }

end LeanCompilerBackend
