# ARM typed phi identities

Compiler identity `e7ef407580b7f70044b148f5b0dd6fcd9b74b780ef0cc14b92b7b54472fb18d8` skips allocated phi transfers only when declared widths and physical homes match. Scheduling indices stay populated, and other transfers retain the existing cycle/staging logic. Baseline emission is unchanged.

Both native ARM targets pass 5,120 independent C checks per mode and unchanged original QBE. Tests cover integer/FP bits, cycles, updating loops, spills and dirty upper bits; a wrong GP narrowing mutation is detected. Implicit word-to-long phi is rejected by the existing validator; explicit unsigned extension paths are tested. Cross-width stack fallback has structural coverage, not a claim that every erroneous same-slot store deletion is observable.

The main full Linux ARM gate, Apple independent helper, emission guards, units and unchanged 147-report proof audit pass. Corpus comparison has 1,213 identical assemblies, 15 matching refusals and 92 ARM allocated/optimized changes. The retained audit accounts for 552 redundant copy instructions and 60 branch instructions: removing copies exposes empty trampolines to the existing branch compactor. Baseline and non-ARM output stay identical. See `main-gates.json`, `assembly-audit.json` and the executable audit script.

Seventeen zlib units shrink 5,460 text bytes on each ARM target (Linux 121,836→116,376; Apple 122,140→116,680). All 34 baseline assemblies match. Linux upstream example and 12 GCC/Python exact compressed-stream checks pass.

Two quiet native Linux ARM VM timing windows each contain 135 paired measurements with five compiler/oracle labels, nine rounds and 100 ms calibration. All five labels pass 15 correctness profiles; 485 bound host/guest files pass provenance barriers before/after each window. CRC32 elapsed falls about 25%, mixed decompression about 9%, and repeated compression about 4% versus the leaf checkpoint in both windows. Other effects are smaller or overlap noise. CRC32 still takes roughly 1.28–1.29x QBE and 2.9–3.0x GCC time. These are finite-workload measurements; descriptive bootstrap intervals have no multiple-comparison correction. Original and corrected QBE remain separate labels. Full raw archives and per-case ratios are retained here.

No new end-to-end or optimization preservation proof is claimed. `qualification.json` records fixture preflights and excluded attempts; its initial no-timing statement describes that earlier qualification stage, superseded by the separately retained timing windows.
