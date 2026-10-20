/- Exact conversion of QBE floating constants to IEEE bit patterns.
   Decimal/hexadecimal significands are rounded once, ties to even, using integers.
   This does not introduce floating-point operations or ABI support. -/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Numeric

private def signedExponent (text : String) : Except String Int := do
  let text := if text.startsWith "+" then String.ofList text.toList.tail else text
  let some exponent := text.toInt? | throw "invalid floating exponent"
  if exponent.natAbs > 10000 then throw "floating exponent exceeds the 10000 resource limit"
  pure exponent

private def digit (base : Nat) (c : Char) : Option Nat :=
  let value := if '0' <= c && c <= '9' then c.toNat - '0'.toNat
    else if 'a' <= c && c <= 'f' then c.toNat - 'a'.toNat + 10 else base
  if value < base then some value else none

private def significand (base : Nat) (text : String) : Except String (Nat × Nat) := do
  let pieces := text.splitOn "."
  if pieces.length > 2 then throw "invalid floating significand"
  let digits := String.intercalate "" pieces
  if digits.isEmpty then throw "floating significand requires digits"
  if digits.length > 4096 then throw "floating significand exceeds the 4096-digit resource limit"
  let mut coefficient := 0
  for c in digits.toList do
    let some value := digit base c | throw "invalid floating significand digit"
    coefficient := coefficient * base + value
  pure (coefficient, if pieces.length == 2 then pieces[1]!.length else 0)

private def scaledRatio (coefficient base : Nat) (exponent : Int) : Nat × Nat :=
  if exponent >= 0 then (coefficient * base ^ exponent.toNat, 1)
  else (coefficient, base ^ exponent.natAbs)

private def roundRatio (numerator denominator : Nat) (shift : Int) : Nat :=
  let (n, d) := if shift >= 0 then (numerator * 2 ^ shift.toNat, denominator)
    else (numerator, denominator * 2 ^ shift.natAbs)
  let q := n / d
  let twiceRemainder := 2 * (n % d)
  if twiceRemainder > d || (twiceRemainder == d && q % 2 == 1) then q + 1 else q

private def encode (fractionBits exponentBits numerator denominator : Nat) : Nat := Id.run do
  if numerator == 0 then return 0
  let bias := 2 ^ (exponentBits - 1) - 1
  let infinity := (2 ^ exponentBits - 1) * 2 ^ fractionBits
  let mut exponent := (numerator.log2 : Int) - (denominator.log2 : Int)
  let below := if exponent >= 0 then numerator < denominator * 2 ^ exponent.toNat
    else numerator * 2 ^ exponent.natAbs < denominator
  if below then exponent := exponent - 1
  if exponent > (bias : Int) then return infinity
  let minimum := 1 - (bias : Int)
  if exponent < minimum then
    return roundRatio numerator denominator ((fractionBits : Int) - minimum)
  let mut rounded := roundRatio numerator denominator ((fractionBits : Int) - exponent)
  if rounded >= 2 ^ (fractionBits + 1) then
    rounded := rounded / 2
    exponent := exponent + 1
  if exponent > (bias : Int) then return infinity
  return (exponent + bias).toNat * 2 ^ fractionBits + rounded - 2 ^ fractionBits

/-- Parse s_/d_ constants as untyped bit patterns, independent of host FP rounding. -/
def floatBits (token : String) : Except String Int := do
  let single := token.startsWith "s_"
  if !single && !token.startsWith "d_" then throw "expected s_ or d_ floating constant"
  let body := (String.ofList (token.toList.drop 2)).toLower
  let negative := body.startsWith "-"
  let magnitude := if negative || body.startsWith "+" then String.ofList body.toList.tail else body
  let fractionBits := if single then 23 else 52
  let exponentBits := if single then 8 else 11
  let sign := if negative then 2 ^ (fractionBits + exponentBits) else 0
  let infinity := (2 ^ exponentBits - 1) * 2 ^ fractionBits
  if magnitude == "inf" || magnitude == "infinity" then return sign + infinity
  if magnitude == "nan" then return sign + infinity + 2 ^ (fractionBits - 1)
  let hexadecimal := magnitude.startsWith "0x"
  let magnitude := if hexadecimal then String.ofList (magnitude.toList.drop 2) else magnitude
  let pieces := magnitude.splitOn (if hexadecimal then "p" else "e")
  if pieces.length > 2 then throw "invalid floating exponent"
  let exponent ← if pieces.length == 2 then signedExponent pieces[1]! else pure 0
  let (coefficient, decimals) ← significand (if hexadecimal then 16 else 10) pieces[0]!
  let exponent := exponent - (if hexadecimal then 4 * decimals else decimals : Nat)
  let (numerator, denominator) := scaledRatio coefficient (if hexadecimal then 2 else 10) exponent
  return sign + encode fractionBits exponentBits numerator denominator

/-- Exact integer-to-IEEE conversion under round-to-nearest, ties-to-even. -/
def integerBits (width : Width) (value : Int) : UInt64 :=
  let (fractionBits, exponentBits) := if width == .word then (23, 8) else (52, 11)
  let sign := if value < 0 then 2 ^ (fractionBits + exponentBits) else 0
  (sign + encode fractionBits exponentBits value.natAbs 1).toUInt64

end LeanCompilerBackend.Numeric
