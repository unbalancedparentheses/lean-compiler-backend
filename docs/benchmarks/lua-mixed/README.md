# Lua 5.4.7 mixed-build qualification

Native Linux ARM64 qualification passes for compiler identity `e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4` with **30 of 33 production units** compiled through the backend: 968 functions and 76,174 IR lines. Lua is pinned at `1ab3208a1fceb12fca8f24ba57d6e13c5bff15e3`, with unchanged default configuration, no Linux/readline/internal-test defines, and retained frontend macro definitions.

The three original volatile-containing units (`ldebug.c`, `ldo.c`, `lstate.c`) still fail the pinned frontend before IR generation. Their unchanged GCC O2 object files are shared byte-for-byte across all five mixed builds. Volatile semantics and upstream source were not patched. This qualifies a mixed program, not full Lua compilation by LCB or QBE. The original [failed preflight](../lua-preflight/README.md) remains separate evidence.

Two pure GCC references (O0/O2), three mixed LCB modes, unchanged original QBE and explicitly corrected QBE all pass:

- Seven deterministic language/bit/FP/coroutine/GC probe executions.
- Fourteen unmodified upstream `all.lua` invocations: each binary runs official `_U=true`, then `_soft=true;_port=true` with visible skip messages.
- Matching skip profiles against GCC, explicit completion checks and an output oracle that detects a corrupted optimized Lua main returning success without running the script.

The 41 archive files were verified against the pinned test archive; that count does **not** mean all 41 files were fully executed. Internal ltests/opcode/API coverage, locale-dependent decimal cases and soft/portable exclusions remain. Per-label stdout/stderr and exact scripts are retained. Full stdout is not expected to be byte-identical because the suite includes variable process/timing output; the deterministic probe, completion assertions and matched skip profiles provide the comparison.

All runs use the same 64 MiB stack bound and 300-second per-invocation cap. The final host/guest digest barrier binds 944 source/configuration/frontend/compiler/object/oracle/test files. Both QBE variants were freshly built and executed, with their patch/source identities kept separate. There is no runtime-performance or full-QBE-parity claim.
