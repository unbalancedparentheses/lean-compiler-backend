# Executable coverage for retained _chacha20.ssa

The imported original fixture has no upstream C driver. Its counter starts at
10 and decreases by 10, so the unchanged program executes one double-round,
not the complete 20-round cipher. The independent C caller checks that exact
round transformation on 512 states, including four edge-state patterns, with
separate, in-place and partially overlapping output (1,536 cases per backend).
Whole-buffer comparisons also check surrounding canaries. Both native ARM
profiles pass baseline/allocated/optimized LCB and unchanged original QBE.
Changing one addition to subtraction in a separate mutated IR copy is detected
with exit 1 on both targets. The imported source is never changed.

The initial development caller expected ten double-rounds and failed even on
baseline. Inspection identified the retained fixture's counter behavior; that
preflight is excluded and its source/log remain in .build/chacha-full-round-
preflight-* and .build/chacha-leaf-run.log. A Python command-list syntax error
was fixed before the successful runner execution. This qualification does not
assert that the retained fixture implements full ChaCha20, nor alter the count
of original upstream drivers (58).
