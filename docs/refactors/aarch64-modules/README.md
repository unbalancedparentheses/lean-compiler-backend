# AArch64 module extraction

The public `LeanCompilerBackend.AArch64` facade now imports two focused modules: `AArch64/ALU.lean` owns primitive ALU selection/evaluation and `select_preserves`; `AArch64/ABI.lean` owns the Apple scalar argument-layout helper. Full call/parameter lowering still uses `AggregateABI.plan`. Public names, namespaces, defaults and definition bodies are unchanged. The emitter retains all private implementation declarations.

`verify-extraction.py` mechanically checks exact moved bodies and reconstructs the complete original facade byte-for-byte. Both worker and independent reviewer checked the boundaries. The source/build identity changes from e095ed59 to c1178a9e because module organization is part of the identity; historical results are not relabeled.

Fresh build, units and all 147 exact proof-audit statements pass. Across five targets and three modes, the retained corpus produces 1,305 identical assemblies and 15 identical refusals. Fresh compilation of retained zlib IR (17 units, both ARM targets, three modes) and mixed-Lua IR (30 units, Linux ARM, three modes) produces 192 identical assembly pairs. Native Apple ARM aggregate ABI, scaled-load and floating variadic suites pass against independent C/original QBE controls. All exact reports, helper hashes and compiler identities are retained.

This is a behavior-preserving organization change supported by mechanical source equality and finite regression evidence, not a new preservation theorem. The immediately preceding full gates remain bound to their original identity; they were not rerun wholesale. Workload frontend/runtime phases were not rerun. Lua's three volatile frontend exclusions remain. No performance claim or proof expansion. Binaries and generated workload assembly are omitted; exact hashes are retained.

Run `python3 docs/refactors/aarch64-modules/verify-extraction.py` to reproduce the source check. `corpus.json` and `workloads.json` retain every assembly hash and input binding; `qualification.json` records the commands' scope and limitations.
