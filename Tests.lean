import LeanCompilerBackend

open LeanCompilerBackend

private def sample := "export function w $add(w %a, w %b) { @start %r =w add %a, %b ret %r }"

private def require (condition : Bool) (message : String) : IO Unit := do
  unless condition do throw (IO.userError message)

private def isFailure : Except ε α → Bool
  | .error _ => true
  | .ok _ => false

private def valueEquals [BEq α] (result : Except ε α) (expected : α) : Bool :=
  match result with
  | .ok actual => actual == expected
  | .error _ => false

def main : IO Unit := do
  let program ← match Parser.parse sample with
    | .ok p => pure p
    | .error e => throw (IO.userError e)
  require (valueEquals (validate program) ()) "sample should validate"
  require (valueEquals (Semantics.evaluate program[0]! #[4294967295, 2]) 1) "word addition must wrap"
  require (valueEquals (Semantics.evaluate program[0]! #[10, 20]) 30) "word addition result"
  require (isFailure (Semantics.evaluate program[0]! #[])) "arity mismatch must reject"
  require (isFailure (Parser.parse "export function d $bad() { @s ret 0 }")) "float must reject"
  require (isFailure (Parser.parse "function w $bad() { @s ret 0 } trailing")) "surplus input must reject"
  IO.println "unit checks passed"
