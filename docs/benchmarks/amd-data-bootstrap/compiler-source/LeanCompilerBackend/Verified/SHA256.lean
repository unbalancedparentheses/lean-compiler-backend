/- SHA-256 content indices for canonical packets. These are NOT equality proofs:
   replay still compares exact bytes and recomputes the baseline. The executable
   hash is tested against published vectors and Python hashlib, not proved. -/
import Std

namespace LeanCompilerBackend.Verified.SHA256

private def initial : Array UInt32 := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

private def constants : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

private def rotate (x : UInt32) (n : Nat) : UInt32 :=
  (x >>> n.toUInt32) ||| (x <<< (32-n).toUInt32)

def hash (input : ByteArray) : ByteArray := Id.run do
  let mut padded := input.push 128
  let zeros := (56 + 64 - padded.size % 64) % 64
  for _ in [:zeros] do padded := padded.push 0
  let bits := (input.size * 8).toUInt64
  for i in [:8] do padded := padded.push ((bits >>> ((7-i)*8).toUInt64).toUInt8)
  let mut state := initial
  for block in [:padded.size / 64] do
    let mut schedule : Array UInt32 := #[]
    for i in [:16] do
      let mut word : UInt32 := 0
      for j in [:4] do word := (word <<< 8) ||| padded[block*64+i*4+j]!.toUInt32
      schedule := schedule.push word
    for i in [16:64] do
      let a := schedule[i-15]!
      let b := schedule[i-2]!
      let s0 := rotate a 7 ^^^ rotate a 18 ^^^ (a >>> 3)
      let s1 := rotate b 17 ^^^ rotate b 19 ^^^ (b >>> 10)
      schedule := schedule.push (schedule[i-16]! + s0 + schedule[i-7]! + s1)
    let mut a := state[0]!
    let mut b := state[1]!
    let mut c := state[2]!
    let mut d := state[3]!
    let mut e := state[4]!
    let mut f := state[5]!
    let mut g := state[6]!
    let mut h := state[7]!
    for i in [:64] do
      let s1 := rotate e 6 ^^^ rotate e 11 ^^^ rotate e 25
      let choice := (e &&& f) ^^^ (~~~e &&& g)
      let t1 := h + s1 + choice + constants[i]! + schedule[i]!
      let s0 := rotate a 2 ^^^ rotate a 13 ^^^ rotate a 22
      let majority := (a &&& b) ^^^ (a &&& c) ^^^ (b &&& c)
      let t2 := s0 + majority
      h := g; g := f; f := e; e := d + t1
      d := c; c := b; b := a; a := t1 + t2
    let working := #[a,b,c,d,e,f,g,h]
    state := state.mapIdx (fun i word => word + working[i]!)
  let mut output := ByteArray.empty
  for word in state do
    for i in [:4] do output := output.push ((word >>> ((3-i)*8).toUInt32).toUInt8)
  return output

def hex (input : ByteArray) : String := Id.run do
  let digits := "0123456789abcdef".toList.toArray
  let mut output := ""
  for byte in (hash input).data do
    output := output.push digits[byte.toNat / 16]!
    output := output.push digits[byte.toNat % 16]!
  return output

end LeanCompilerBackend.Verified.SHA256
