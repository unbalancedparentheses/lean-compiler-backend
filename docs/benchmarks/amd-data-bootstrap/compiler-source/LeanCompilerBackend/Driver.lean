/- Host-default selection for the compatibility command-line driver. -/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Driver

/-- Use the Lean runtime's LLVM triple, so a translated executable selects its
    own architecture. Unknown hosts require an explicit supported target. -/
def hostTarget (triple : String) : Except String String := do
  let parts := triple.splitOn "-"
  let architecture := parts.head!
  let linux := parts.contains "linux"
  let darwin := parts.any fun p => p.startsWith "darwin" || p.startsWith "macos"
  if linux == darwin then
    throw s!"cannot select a supported host target from '{triple}'; pass --target explicitly"
  match architecture, linux with
  | "arm64", false | "aarch64", false => pure "aarch64-macos"
  | "arm64", true | "aarch64", true => pure "aarch64-linux"
  | "x86_64", false | "amd64", false => pure "x86_64-macos"
  | "x86_64", true | "amd64", true => pure "x86_64-linux"
  | "riscv64", true => pure "riscv64-linux"
  | _, _ => throw s!"unsupported host architecture in '{triple}'; pass --target explicitly"

end LeanCompilerBackend.Driver
