# AMD64 folded-load normalization

The allocated constant-offset load path now omits a redundant `movl %eax, %eax`. Every word-result load selected by that path already writes EAX and clears the upper half of RAX. Signed and unsigned load opcodes, exact access width, floating-point bit patterns and long-result behavior are preserved. Direct loads and baseline lowering are unchanged.

The integrated source identity is `7e441df0ab15b5f01676b409a3908f811bb785659f782e45da83b672aab1d90c`, exactly matching the independently qualified [private candidate](private/README.md). Fresh main build, units and all 147 existing proof-audit statements pass. This adds no new semantic proof. A combined-main replay and complete regression gates follow in the next checkpoint.

Both AMD64 targets pass independent byte-oracle tests covering signed/unsigned loads, raw FP bits, pressure, shared/debug fallback boundaries, displacement extremes, unaligned addresses and guarded page ends. The full LCB fixture contains 128 functions and 2,048 checks per execution. Original QBE passes the separately labeled legal-displacement subset; its inability to assemble the out-of-range displacement fixture is retained as a reference failure. Deliberate load-signedness corruption is detected.

The 17-unit zlib comparison removes 889 redundant instructions and 1,745 optimized text bytes per AMD64 target. Allocated output loses 1,276 instructions and 2,578 bytes; baseline output is identical. Actual object sizes include branch relaxation and alignment. Linux QEMU execution passes six examples and 72 exact GCC/Python compressed-stream comparisons. Apple workload objects are assembled; focused C tests execute through Rosetta. These static reductions are not runtime speed claims.

All corpus changes are audited: 1,275 identical assemblies, fifteen identical refusals and thirty AMD allocated/optimized assemblies containing exactly 34 removed self-copies. Missing-tool emission, CLI, source/helper/compiler bindings and guest/host barriers pass. Earlier failed or superseded helper runs remain explicitly separate in the private evidence.
