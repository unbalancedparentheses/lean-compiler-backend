import LeanCompilerBackend.Driver

namespace LeanCompilerBackend.Driver.Tests

def run : IO Unit := do
  for (triple,target) in #[
      ("arm64-apple-darwin24.6.0", "aarch64-macos"),
      ("aarch64-apple-darwin", "aarch64-macos"),
      ("x86_64-apple-macosx15.0", "x86_64-macos"),
      ("aarch64-unknown-linux-gnu", "aarch64-linux"),
      ("arm64-unknown-linux-musl", "aarch64-linux"),
      ("x86_64-unknown-linux-gnu", "x86_64-linux"),
      ("amd64-unknown-linux-musl", "x86_64-linux"),
      ("riscv64-unknown-linux-gnu", "riscv64-linux")] do
    unless (hostTarget triple).toOption == some target do
      throw (IO.userError s!"wrong host-default selection for {triple}")
  for triple in #["", "x86_64-pc-windows-msvc", "wasm32-unknown-emscripten",
      "riscv64-apple-darwin", "armv7-unknown-linux-gnu", "x86_64-linux-darwin"] do
    unless (hostTarget triple).toOption.isNone do
      throw (IO.userError s!"unsupported host silently selected a target: {triple}")
  IO.println "driver: host triples select five supported targets; unsupported hosts require an explicit target"

end LeanCompilerBackend.Driver.Tests
