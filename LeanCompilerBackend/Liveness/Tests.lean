import LeanCompilerBackend.Liveness
import LeanCompilerBackend.Parser

namespace LeanCompilerBackend.Liveness.Tests

private def analyze (f : Function) : IO Result :=
  match Liveness.analyze f with
  | .ok result => pure result
  | .error reason => throw (IO.userError reason)

/-- Exercise compatibility bounds without rendering a huge JSON diagnostic. -/
def run : IO Unit := do
  let blocks := (List.range 4096).toArray.map fun i =>
    {label := s!"b{i}", phis := #[], instructions := #[], terminator :=
      if i == 4095 then .ret (some (.temporary "x")) else .jump s!"b{i+1}" : Block}
  let chain : Function := {
    name := "chain", exported := false, resultWidth := some .long
    parameters := #[{name := "x", width := .long}], blocks}
  let result ← analyze chain
  unless result.liveIn.all (· == 1) && result.liveOut[4095]! == 0 &&
      result.before[4095]! == #[1] do
    throw (IO.userError "liveness failed at the 4096-block worklist boundary")
  let instructions := (List.range 16384).toArray.map fun i =>
    Statement.assign {destination := s!"v{i}", width := .long, operation := .copy (.constant (Int.ofNat i))}
  let large : Function := {
    name := "large", exported := false, resultWidth := some .long
    parameters := #[], blocks := #[{
      label := "s", phis := #[], instructions
      terminator := .ret (some (.temporary "v16383"))}]}
  let result ← analyze large
  unless result.names.size == 16384 && result.liveIn == #[0] &&
      result.before[0]!.size == 16385 && result.before[0]![16383]! == 0 &&
      result.contains result.before[0]![16384]! "v16383" &&
      result.members result.before[0]![16384]! == #["v16383"] do
    throw (IO.userError "liveness lost high-index values at the 16384-definition boundary")
  let disconnected ← match Parser.parseModule "function l $f(l %x) { @s ret %x @dead %a =l phi @dead %b %b =l add %a,1 jmp @dead }" with
    | .ok m => pure m.functions[0]! | .error e => throw (IO.userError e)
  let result ← analyze disconnected
  unless result.liveIn.size == 2 && result.contains result.before[1]![0]! "a" &&
      result.contains result.liveOut[1]! "b" do
    throw (IO.userError "liveness lost disconnected cyclic phi values")
  IO.println "liveness resource boundaries: 4096 blocks and 16384 definitions passed"

end LeanCompilerBackend.Liveness.Tests
