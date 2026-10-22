/- Bounded canonical binary primitives. Integers/counts are unsigned LE64;
   tags/booleans are bytes; strings are length-prefixed strict UTF-8. -/
import LeanCompilerBackend.Verified.Job

namespace LeanCompilerBackend.Verified.Wire

abbrev Encoder := StateT ByteArray (Except String)
structure Cursor where
  bytes : ByteArray
  position : Nat := 0
abbrev Decoder := StateT Cursor (Except String)

def byte (value : Nat) : Encoder Unit := do
  if value >= 256 then throw "wire tag overflow"
  modify (·.push value.toUInt8)

def natural (value : Nat) : Encoder Unit := do
  if value >= 2^64 then throw "wire integer overflow"
  for i in [:8] do byte ((value / 2^(8*i)) % 256)

def boolean (value : Bool) : Encoder Unit := byte (if value then 1 else 0)

def bytes (value : ByteArray) : Encoder Unit := do
  natural value.size
  modify (· ++ value)

def string (value : String) : Encoder Unit := do
  if value.toUTF8.size > 4096 then throw "string exceeds 4096 bytes"
  bytes value.toUTF8

def array (write : α → Encoder Unit) (values : Array α) : Encoder Unit := do
  natural values.size
  for value in values do write value

def readByte : Decoder Nat := do
  let cursor ← get
  if cursor.position >= cursor.bytes.size then throw "truncated packet"
  let value := cursor.bytes[cursor.position]!
  set { cursor with position := cursor.position + 1 }
  pure value.toNat

def readNatural : Decoder Nat := do
  let mut value := 0
  for i in [:8] do value := value + (← readByte) * 2^(8*i)
  pure value

def readBoolean : Decoder Bool := do
  match ← readByte with
  | 0 => pure false | 1 => pure true | _ => throw "noncanonical boolean"

def readBytes (limit : Nat) : Decoder ByteArray := do
  let count ← readNatural
  let cursor ← get
  if count > limit || count > cursor.bytes.size - cursor.position then
    throw "byte string too large or truncated"
  set { cursor with position := cursor.position + count }
  pure (cursor.bytes.extract cursor.position (cursor.position + count))

def readString (limit := 4096) : Decoder String := do
  let bytes ← readBytes limit
  let some value := String.fromUTF8? bytes | throw "invalid UTF-8"
  pure value

def readArray (limit : Nat) (read : Decoder α) : Decoder (Array α) := do
  let count ← readNatural
  if count > limit then throw "collection resource limit"
  let mut values := #[]
  for _ in [:count] do values := values.push (← read)
  pure values

def encode (writer : Encoder Unit) : Except String ByteArray := do
  let (_, result) ← writer.run ByteArray.empty
  if result.size > 1048576 then throw "packet exceeds 1 MiB"
  pure result

def decode (reader : Decoder α) (input : ByteArray) : Except String α := do
  if input.size > 1048576 then throw "packet exceeds 1 MiB"
  let (value, cursor) ← reader.run { bytes := input }
  if cursor.position != input.size then throw "trailing packet bytes"
  pure value

end LeanCompilerBackend.Verified.Wire
