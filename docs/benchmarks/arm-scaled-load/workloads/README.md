# Combined-main scaled-load workload correctness

Actual main identity 210a515a is qualified against retained-TLS predecessor 4b41bddb, with exact full identities/hashes in reports. No compiler source edits or builds and no timing measurements in this replay.

Zlib: 17 unchanged target-configured IR units, both ARM targets/all 3 modes. All 204 assemblies exactly match corresponding historical private before/96c8 candidate outputs. Exhaustive delta audit identifies 74 scaled folds per ARM target, optimized text -312 bytes; baseline/allocated unchanged. Linux ARM native VM execution passes 6 example runs and 72 exact GCC/Python compressed-stream checks. Apple objects assembled only; no Apple zlib executable claim.

Mixed Lua: optimizedLinux ARM only, 30 LCB/cproc IR units plus 3 unchanged GCC volatile-unit objects (`ldebug`, `ldo`, `lstate`). 73 scaled folds across 16 units account for all changes, text -292 bytes. Fresh before/after and reused, hash-verified GCC O0/GCC O2/original QBE/corrected QBE executables each run independent probe and two reduced upstream suite profiles (6 probes + 12 suite invocations). Official _U and soft/port exclusions retained; not full Lua, not all LCB, and no fresh reference builds. Empty-main mutation must be detected despite exit 0.

Source/compiler/helper/oracle/IR/fixtures/executables have pre/post binding checks. Guest execution reports are digest-gated; final guest/host hashes checked without overwriting guest-generated outputs. Original and corrected QBE remain separately labeled. Static code reductions are not runtime performance claims.
