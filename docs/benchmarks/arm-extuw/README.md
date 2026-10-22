# ARM64 typed unsigned-word extension

Allocated/optimized code omits `extuw` only when its temporary source is declared
word-width and shares the same physical home as the result. Every current word
producer writes a W register, so its high half is already zero. Long sources,
spills and different homes retain the existing conversion; baseline is unchanged.
The accompanying source audit documents the producer invariant. This is not a
formal preservation proof, and future emitter paths must preserve that invariant.

The before identity is `7958046aa99bf6a1d836e954f5f022dfc8e62384a8e58013fdf529eb5808e282`;
after is `5ce9e7a3011f06f269e630fb6685db716de6a9d5850c99f4dedc6df83dcfc8fa`.
Main and the independent candidate have identical executable hashes.

Both native ARM targets pass 5,632 independent C checks per mode and unchanged
original-QBE comparisons. Cases cover dirty long inputs, ABI word returns with
dirty high bits, FP bit patterns, phi transfers, calls, varargs, pressure and debug
locations. An intentionally omitted dirty-long truncation is detected with exit
11. Main passes the complete Linux ARM gate, native Apple matrix, units, missing-
tools emission guard and unchanged 147-report proof audit. The ordinary emission
corpus has 1,305 identical assemblies and 15 matching refusals.

Across each target's 44 workload units, all baseline assemblies remain identical.
Optimized zlib text loses 1,012 bytes (253 instructions), libyaml loses 8 bytes
(2 instructions), and LZ4 loses 500 bytes (125 instructions). Linux before/after
executables pass the zlib upstream example and 12 exact GCC stream profiles,
52 historical libyaml checks, and the bounded LZ4 upstream unit/randomized profile
plus 15 exact streams. Apple workload evidence is object-only; its independent
matrix executes natively. No runtime speedup is claimed.

An initial workload harness link included two zlib main objects; the corrected
fresh run selected the appropriate objects. That preflight is excluded from the
published successful evidence. Source, IR, assembly, object and executable hashes
are retained in `combined-evidence.json`.
