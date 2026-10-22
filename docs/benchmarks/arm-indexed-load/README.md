# ARM adjacent indexed loads

Compiler identity `e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4` folds an adjacent sole-use long temporary sum and load into a non-writeback register-offset load. Whole-function use counts exclude sums reused by phi/calls/stores. Inputs use existing allocated homes or reserved x9/x10 scratch; large spill addresses use x15. This adds no scaled addressing, stores or global lifetime extension.

Both native ARM independent matrices pass 37,124 C case groups per mode and unchanged original QBE. They cover all integer load widths/signs, FP bits, page boundaries, spilled operands/results, register overlaps, modular address cancellation, shared uses, barriers and debug locations. Wrong-index and overwide-byte-load controls are detected. A separate 4,200-live-value probe exercises actual base/index/result spill slots beyond 32 KiB; its execution evidence is retained separately from the ordinary 64 KiB allocation test.

The corpus has 1,285 identical assemblies, 15 matching refusals and 20 changed ARM allocated/optimized assemblies. The executable audit script accounts for every changed byte as 88 adjacent add/load contractions. Baseline and non-ARM assemblies are unchanged. The full host gate, units and the 147-report unchanged proof audit pass; main gate records distinguish native execution from emission-only checks.

Fresh combined-main zlib qualification uses 17 units across both ARM targets and all 3 modes: 204 new assemblies/objects, 34 baseline identities and 408 host/guest digest comparisons. Optimized text Linux 116,376→115,792 and Apple 116,680→116,096; allocated text falls 724 bytes per target. Six original Linux upstream example runs and 72 exact GCC/Python compression profiles pass. Apple workload objects are assembled; independent Apple C matrices execute natively. Earlier private 15ce→3506 evidence is preserved without being relabelled as this compiler.

Two initial quiet timing windows (100 ms calibration, nine paired rounds each)
show repeated CRC32 about 4.3–5.5% faster than phi, but mixed compression medians
about 4.3–4.6% slower. Only the second mixed-compression interval excludes no
change; the first window has substantial variability. These results include a
possible regression and do not establish a general speedup. Longer 500 ms
windows are being collected to investigate. Raw samples, provenance and all
comparisons are retained in window1/window2 and the two-window summary.

Object size is not a runtime-speed claim. No new preservation proof or full QBE compatibility claim is made.
