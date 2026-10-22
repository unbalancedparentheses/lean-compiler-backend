# AMD64 word-normalization differential fuzzing

Compiler `11be972e96d4fc9de4c6df28cd1fe7f5ddf5c728ff01348bd6d1398eef1748b4`
passes 64 fresh seeds (20272000–20272063), 1,280 generated functions and 37,120
input cases per execution path on Linux x86 under QEMU. Independent Python
bit-vector expectations agree with the interpreter and all three LCB modes.
Return-value corruption is detected.

In the raw profile, original QBE fails all 64 seeds' reference qualification;
the campaign consequently exits nonzero and retains status `reference_failed`.
Inserting explicit modulo-width shift masks yields a separate profile with all
64 seeds common-qualified against unchanged QBE. Both profiles retain identical
IR within each backend comparison and use the original generator's independent
expected values. The masked profile does not erase the raw failures or represent
64 additional unique random seeds.

These immutable-snapshot runs qualify the word-normalization checkpoint, before
the subsequent AMD immediate-selection change. That later compiler has its own
target matrices and [11-program pointer replay](../amd-immediates/pointer-replay.json).
No proof or native x86 hardware coverage is inferred from this local campaign.
