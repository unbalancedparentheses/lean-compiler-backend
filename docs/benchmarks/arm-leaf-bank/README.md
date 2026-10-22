# Bounded ARM64 leaf register bank

Allocated/optimized functions without explicit calls or TLS operands can use
x16, x17 and x8 after the existing x19–x28 bank. The target checks the exact bank
independently of graph coloring and symbolic home flow. Only x19–x28 are saved
and restored. Incoming hidden-result x8 is captured before home writes; argument
registers x0–x7 and all emitter scratch/platform registers remain excluded.

IP0/IP1 may be clobbered by linker veneers. Expanded functions therefore require
bounded output with local branch targets and no calls or indirect branches;
unexpected or large output is emitted again using the original bank. The 900 KiB
physical-line bound covers ordinary conditional branches; the only shorter-range
TBZ sequence is a fixed local varargs expansion. See [the source audit](AUDIT.md)
for constraints and ABI reference. This is not a machine correctness proof.

Before identity: `5ce9e7a3011f06f269e630fb6685db716de6a9d5850c99f4dedc6df83dcfc8fa`.
After identity: `15ce10a4b7cefa821efb53656d214910f35b8eb97d9b33770f3dd2ce20b3657c`.
Main and the independently qualified release have identical executable hashes.

Both native ARM profiles pass 7,168 independent C checks per mode, covering
pressure, GP/FP arguments, raw floating bits, hidden aggregate returns,
environments, leaf varargs, large/dynamic frames, blits and phi loops. Eligible
fixtures assert actual use of all three extra homes. A deliberately call-live
caller-saved home is detected with exit 5. Baseline and nonleaf/TLS fixture bytes
stay identical. Independent bank/branch/size controls pass; leaf-only objects
have no relocations. A 300,065-line function falls back to the original output.

The ordinary emission comparison has 1,297 identical assemblies, 15 matching
refusals and eight intended changes: ARM allocated/optimized `_chacha20` and
`spill1` output. All baseline and non-ARM output stays identical. The raw exact
comparator reports these differences; `assembly-scope-audit.json` checks their
scope. Correctness evidence comes from executable tests, not this scope check.
The [additional C caller](chacha/README.md) gives executable coverage to the
otherwise assembly-only retained `_chacha20` fixture without changing its source.

Seventeen Linux ARM zlib objects keep baseline text at 416,468 bytes. Allocated
text falls 168,500→167,404; optimized falls 123,032→121,836 (1,196 bytes). Six
before/after upstream examples and 72 exact GCC/Python payload profiles pass.
Those original object runs used an intermediate identity with identical code;
`release-equivalence.json` records all 51 identical final-release assemblies.
Fresh final-release builds and separately qualified performance measurements
are in [the in-process zlib report](../zlib-inprocess/README.md).

Main passes the complete host gate (native Apple ARM and Rosetta Apple x86),
the complete native Linux ARM gate, units, emission-only guards and the unchanged
147-report proof audit. Linux wrappers inside the host gate are emission-only;
Linux ARM execution is qualified by its separate native gate.
