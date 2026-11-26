#!/usr/bin/env bash
# Assemble a frontend with the exact pinned Lean compiler and one instrumented
# object. Static linking makes both LCNF lookup sites use the recorder.
set -euo pipefail
out=$1
pinned=$(lean --print-prefix)
mkdir -p "$out/bin" "$out/source/Lean/Compiler" "$out/driverlib"
out=$(realpath "$out")
ln -sfn "$pinned/lib" "$out/lib"
ln -sfn "$pinned/include" "$out/include"
ln -sfn "$pinned/src" "$out/src"
for tool in "$pinned"/bin/*; do
  case "${tool##*/}" in
    lean|leanir) ;;
    *) ln -sfn "$tool" "$out/bin/" ;;
  esac
done
python3 - "$pinned" "$out" <<'PY'
from pathlib import Path
import sys

pinned, out = map(Path, sys.argv[1:])
source = Path("Lean/Compiler/CSimpAttr.lean")
text = (pinned / "src/lean" / source).read_text()
for old, new in [
    ("import Lean.ExtraModUses\n",
     "import Lean.ExtraModUses\nimport Lean.Data.Json\nimport Std.Sync.Mutex\n"),
    ("/-- If `e` (as a whole) matches", Path("scripts/csimp-recorder.inc").read_text()
     + "/-- If `e` (as a whole) matches"),
    ("if let some ent := s.map.find? declName then\n",
     "if let some ent := s.map.find? declName then\n    recordRewrite ent\n"),
]:
    if text.count(old) != 1:
        sys.exit(f"pinned Lean CSimp lookup has changed: {old!r}")
    text = text.replace(old, new)
(out / "source" / source).write_text(text)
PY
LEAN_PATH= "$pinned/bin/lean" --root="$out/source" \
  -c "$out/csimp.c" "$out/source/Lean/Compiler/CSimpAttr.lean"
LEAN_PATH= "$pinned/bin/lean" --root=scripts -o "$out/driverlib/ArithmeticMatches.olean" \
  -c "$out/arithmetic.c" scripts/ArithmeticMatches.lean
LEAN_PATH="$out/driverlib" "$pinned/bin/lean" --root=scripts -c "$out/driver.c" scripts/ProvenanceCompiler.lean
cp "$pinned/lib/lean/libLean.a" "$out/libLean.a"
chmod u+w "$out/libLean.a"
member=CSimpAttr.c.o.export
mapfile -t matches < <(ar t "$out/libLean.a" | grep -Fx "$member")
if [[ ${#matches[@]} != 1 ]]; then
  echo "expected exactly one $member in pinned libLean.a" >&2
  exit 1
fi
ar d "$out/libLean.a" "$member"
archives=("$out/libLean.a" "$pinned/lib/lean/libStd.a" "$pinned/lib/lean/libInit.a")
if [[ $(uname -s) == Darwin ]]; then
  link=(-Wl,-export_dynamic)
  for archive in "${archives[@]}"; do link+=("-Wl,-force_load,$archive"); done
else
  link=(-rdynamic -Wl,--whole-archive "${archives[@]}" -Wl,--no-whole-archive)
fi
LEAN_CC="${LEAN_CC:-${CC:-cc}}" "$pinned/bin/leanc" -L"$pinned/lib" \
  -DLEAN_EXPORTING -o "$out/bin/lean" "$out/driver.c" "$out/csimp.c" "$out/arithmetic.c" "${link[@]}"
