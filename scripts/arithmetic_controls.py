#!/usr/bin/env python3
"""Check concrete mutations of the production arithmetic mappings and proofs."""

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def rejects(root, relative, old, new, diagnostic):
    original = (ROOT / relative).read_text()
    if original.count(old) != 1:
        raise AssertionError(f"{relative}: mutation must identify one production site")
    candidate = root / relative
    candidate.parent.mkdir(parents=True, exist_ok=True)
    candidate.write_text(original.replace(old, new, 1))
    result = subprocess.run(
        ["lake", "env", "lean", f"--root={root}", str(candidate)],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    if result.returncode != 1 or diagnostic not in result.stdout:
        raise AssertionError(f"{relative}: expected {diagnostic!r}\n{result.stdout}")


def main():
    with tempfile.TemporaryDirectory(prefix="lcb-arithmetic-") as directory:
        root = Path(directory)
        rv64 = "LeanCompilerBackend/RV64.lean"
        unsigned_rem = ' | .unsignedRem => "remu"'
        catch_all = "error: arithmetic lowering requires an explicit opcode constructor"
        for pattern in ("_", "(_ : Division)", "_other"):
            rejects(root, rv64, unsigned_rem, f' | {pattern} => "remu"', catch_all)
        rejects(root, rv64, unsigned_rem, "", "Division.unsignedRem")
        signed_unary = '.negate | .signedByte | .signedHalf | .signedWord => norm w "t0"'
        rejects(root, rv64, signed_unary, '_ => norm w "t0"', catch_all)
        for module, arm in (
            ("AArch64", '      | .unsignedRem => ("udiv", true)\n'),
            ("AMD64", "      | .unsignedRem => (false, true)\n"),
            ("Verified/TypedA64", "    | .unsignedRem => remainder false\n"),
        ):
            rejects(root, f"LeanCompilerBackend/{module}.lean", arm, "", "Division.unsignedRem")
        for explicit in (
            ".extendSingle | .truncateDouble | .toInteger .. => true",
            ".extendSingle | .truncateDouble | .fromInteger .. => true",
        ):
            rejects(root, "LeanCompilerBackend/IR.lean", explicit, "_ => true", catch_all)
        rejects(
            root, "LeanCompilerBackend/Verified/TypedA64.lean",
            "  pure { label := block.label, instructions := (chunks.flatMap Array.toList).toArray ++ tail }",
            """  let code := (chunks.flatMap Array.toList).map fun inst =>
    match inst with
    | .alu .long .mulHighUnsigned dst lhs rhs _ | .alu .long .mulHighSigned dst lhs rhs _ =>
      Instruction.alu .long .mul dst lhs rhs (Or.inl rfl)
    | other => other
  pure { label := block.label, instructions := code.toArray ++ tail }""",
            "error: unsolved goals",
        )
    print("arithmetic controls: target division coverage, RV64 and conversion wildcard rejection, and AArch64 placement proof passed")


if __name__ == "__main__":
    main()
