# ELF custom TLS and retained sections

Combined compiler identity `5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e` supports two bounded custom-section features on the three Linux targets.

* Thread-local data can use a custom ELF section with explicit writable, allocated TLS flags (`awT`, in any order). Its requested section, alignment and TLS symbol kind survive emission. Common TLS remains rejected; read-only `aT` and additional flags are outside this slice.
* Ordinary ELF sections can use `R` alongside the existing `a`, `w`, and `x` flags. Independent tests check that unreferenced data/functions survive `--gc-sections`, while paired non-retained controls disappear. Runtime checks obtain retained addresses from post-link symbol offsets, so the test does not create linker references that would accidentally retain them.

The [actual-main qualification](main/README.md) runs separate matrices for both features. Each Linux matrix executes baseline, allocated, optimized and unchanged original QBE output. TLS tests verify four symbols' exact section/type/flags/alignment and 512 child-thread read/write round groups per backend, including fresh thread initialization and main-thread isolation. Wrong-section metadata and wrong-value execution controls are detected. Retention tests verify ELF metadata, actual linker garbage collection and retained content/function results; flag-removal and wrong-value controls are detected. Linux ARM executes natively in the VM; x86 and RV use QEMU.

Apple behavior is unchanged: custom TLS remains refused, ordinary TLS fixture assembly remains identical, and the existing literal second-field section-name convention remains intact. Apple coverage here is emission/refusal equivalence, not new runtime or GNU retention qualification. The tested zero-initialized `.lcb_tls.zero` section is PROGBITS; special assembler section names can select other types.

The combined campaign also passes ten missing-tool emission controls, two default CLI checks, nine checks that `R` does not leak into TLS flags, and source/snapshot/guest-output provenance barriers. Fresh build, units and all 147 unchanged proof-audit statements pass. No new production-emitter preservation theorem is claimed.

The corpus retains 1,305 byte-identical assemblies and 15 identical refusals. All 240 workload assemblies match previously executed output: 102 zlib, 30 mixed-Lua and 108 cproc units across the three Linux targets. This bridge reuses prior links/executions and does not claim new workload runtime measurements. All three [complete Linux regression gates](full-linux/qualification.json) pass. The complete host/Rosetta gate is running separately.

Private TLS candidate `f156a05c…` and retention candidate `b24b3ba3…` used different earlier bases and remain historical evidence. Their exact sources, original QBE qualification, failed harness preflights and superseded helper bindings are preserved in the private directories. Actual-main results use the combined identity above.
