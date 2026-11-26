/- Character operations shared by parsing and assembly rendering. -/
import Init.Data.List.SplitOn.Lemmas

namespace LeanCompilerBackend.Text

/-- Split at matching characters, retaining empty components at both ends. -/
def splitWhen (separator : Char → Bool) (text : String) : List String :=
  (List.splitOnPTR separator text.toList).mapTR String.ofList

theorem splitWhen_spec (separator : Char → Bool) (text : String) :
    splitWhen separator text = (text.toList.splitOnP separator).map String.ofList := by
  rw [List.map_eq_mapTR, List.splitOnP_eq_splitOnPTR]
  rfl

private def validDecimal : List Char → Bool → Bool
  | [], lastDigit => lastDigit
  | c :: rest, lastDigit =>
    if c.isDigit then validDecimal rest true
    else if c == '_' && lastDigit then validDecimal rest false
    else false

private def decimalDigits (chars : List Char) : Option Nat :=
  if validDecimal chars false then
    some (chars.foldl (fun n c => if c == '_' then n else 10 * n + (c.toNat - '0'.toNat)) 0)
  else none

/-- Parse an optional minus sign and decimal digits with interior underscores. -/
def decimalInt? (text : String) : Option Int :=
  match text.toList with
  | '-' :: rest => (decimalDigits rest).map Int.negOfNat
  | chars => (decimalDigits chars).map Int.ofNat

end LeanCompilerBackend.Text
