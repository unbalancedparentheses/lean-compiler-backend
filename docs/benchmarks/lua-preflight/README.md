# Lua 5.4.7 frontend preflight (unqualified)

The pinned Lua source commit `1ab3208a1fceb12fca8f24ba57d6e13c5bff15e3`
was attempted with the existing pinned cproc frontend. Three original units
(`ldebug.c`, `ldo.c`, `lstate.c`) require volatile stores that cproc rejects.
This occurs before QBE IR generation or any LCB compilation. No Lua support,
backend failure, or executable result is claimed.

Thirty-three original C units were attempted; internal `ltests.c` was excluded.
The initial `lstrlib.c` failure was a missing `__DBL_MAX_10_EXP__` macro and passes
when supplied as 308. The three volatile-store failures remain. We did not strip
volatile qualifiers or patch upstream C/IR to make the program compile.

The preflight used the existing native Linux ARM cproc executable and flags
`-D__CHAR_BIT__=8 -D__SCHAR_MAX__=127 -D__SHRT_MAX__=32767
-D__LONG_MAX__=9223372036854775807L -D__DBL_MANT_DIG__=53
-D__DBL_MAX_EXP__=1024 -D__FLT_RADIX__=2`, with `-emit-qbe` per original unit.
The raw diagnostics, source and frontend hashes are in `report.json`.

The matching official Lua tests were downloaded and checksum-verified but never
executed. They are not counted as qualification. Frontend support for volatile
stores (or another compatible frontend) is required before this workload can
qualify the backend.

A later [mixed-build qualification](../lua-mixed/README.md) executes the 30 frontend-compatible units through LCB/QBE and shares the same three unchanged GCC units. It does not change this full-frontend preflight failure.
