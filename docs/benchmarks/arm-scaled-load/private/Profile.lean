import LeanCompilerBackend.Parser
import LeanCompilerBackend.SSA
import LeanCompilerBackend.Optimize
import LeanCompilerBackend.Selection
open LeanCompilerBackend

def main (args : List String) : IO Unit := do
  for path in args do
    let source ← IO.FS.readFile path
    let m ← match Parser.parseModule source >>= SSA.constructModule >>= Optimize.module with
      | .ok m => pure m | .error e => throw (IO.userError e)
    for f in m.functions do
      let uses := Selection.useCounts f
      for b in f.blocks do
        for i in [:b.instructions.size] do
          if b.debugLocations.any (fun d => d.instruction == i+1 || d.instruction == i+2) then continue
          let some (.assign sh) := b.instructions[i]? | continue
          if sh.width != .long || sh.floating || uses[sh.destination]? != some 1 then continue
          let .binary .shiftLeft (.temporary index) (.constant amount) := sh.operation | continue
          let some (.assign address) := b.instructions[i+1]? | continue
          if address.width != .long || address.floating || uses[address.destination]? != some 1 then continue
          let .binary .add (.temporary left) (.temporary right) := address.operation | continue
          if left != sh.destination && right != sh.destination then continue
          let some (.assign inst) := b.instructions[i+2]? | continue
          let .load kind (.temporary name) := inst.operation | continue
          if name != address.destination then continue
          let shift := (Semantics.constant .word amount).toNat % 64
          if shift != 0 && shift != (kind.bytes inst.width).log2 then continue
          IO.println s!"{path}\t{f.name}\t{b.label}\t{i}\t{kind.bytes inst.width}\t{shift}\t{index}"
