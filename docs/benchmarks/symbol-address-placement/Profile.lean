import LeanCompilerBackend.Parser
import LeanCompilerBackend.SSA
import LeanCompilerBackend.Optimize
import LeanCompilerBackend.Allocation
open LeanCompilerBackend
private def bits (n : Nat) : Nat := Id.run do
  let mut x := n
  let mut count := 0
  while x != 0 do
    x := x &&& (x-1)
    count := count+1
  return count
private def take (v : Except String α) : IO α := match v with
  | .ok x => pure x | .error e => throw (IO.userError e)
def main (args : List String) : IO Unit := do
  for path in args do
    let source ← IO.FS.readFile path
    let m ← take (Parser.parseModule source >>= SSA.constructModule)
    for (label,input) in [("normal",m),("no-symbol-hoist",{m with data := #[]})] do
      let out ← take (Optimize.module input)
      for f in out.functions do
        let live ← take (Liveness.analyze f)
        let peak := live.before.foldl (fun n row => row.foldl (fun n set => max n (bits set)) n) 0
        let plan ← take (Allocation.allocate f 13)
        IO.println s!"{path}\t{label}\t{peak}\t{plan.spills}\t{f.locals.size}"
