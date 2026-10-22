# Omitted unused environment parameters

QBE permits calls without an environment argument when the declared environment
parameter is unused. The [minimal input](minimal.ssa) was previously rejected on
all targets. The [before/after comparison](before.json) retains compiler identities,
binary hashes and unchanged original-QBE admission results.

Current identity: `49f1c29def2b2df50394c242f67719bc7202ec3208ab6853fd3c3962fb676207`.
Signature checking and interpretation remove only the unused parameter binding;
no arbitrary value is assigned. Native definitions and their normal ABI layout
remain unchanged. Uses in instruction operands, phi inputs and terminators of
all retained blocks prevent omission, including untaken constant branches.
Structurally unreachable blocks may already have been pruned by SSA normalization.
Known direct calls and interpreter-resolved indirect targets are checked; native
unresolved indirect/external calls retain the established ABI assumptions.

[Validation](validation.json) records fresh units, 147 unchanged proof-audit
reports, existing environment/aggregate/indirect regressions, and target gates.
The new suite runs 250 interpreter cases plus a variadic interpreter control,
14 refusal controls and 410 independent C calls per mode on all five targets.
It covers scalar/stack, direct/indirect, explicit/omitted/extra environments,
callbacks, aggregate returns, void results and recursion, with return corruption
detected. All three LCB modes and unchanged original QBE pass. Apple ARM/Linux
ARM execute natively, Apple x86 through Rosetta, Linux x86/RV through QEMU.
Only the original-QBE RV reference uses `-no-pie`.

[Ordinary assembly comparison](assembly-equivalence.json) retains 1,305 identical
assemblies and 15 matching refusals. This is a bounded admission/ABI correction,
not a new preservation proof. Native AMD64 variadic environment definitions remain
a separate limitation in this checkpoint.
