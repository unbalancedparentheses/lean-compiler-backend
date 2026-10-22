# Fresh combined compiler: QBE and cproc replay

Compiler identity: `e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e`. This actual-main snapshot includes the combined AMD lowering and 4,096-data-definition profile. Both programs were rebuilt in fresh, separate work directories for Linux ARM64, x86-64 and RISC-V64. No compiler rebuild or source change occurred in this campaign.

QBE: all 32 unchanged pinned QBE 1.3 translation units were compiled through the pinned cproc frontend. LCB baseline and optimized compiler executables each reproduce 455 upstream-fixture assemblies and 32 self-IR assemblies, and pass 58 original ARM64 runtime tests per platform. Across the two LCB modes and three platforms: 2,922 exact assembly reproductions and 348 runtime-test executions. The assembly comparison spans QBE's targets, including its own Windows output; this does not imply Windows support in LCB.

cproc: all 18 unchanged pinned frontend units were rebuilt. LCB baseline and optimized each reproduce 19 stage-two IR files (18 frontend units plus cJSON) and pass 196 original cproc tests per platform: 114 IR reproductions and 1,176 test executions across both modes and all three platforms.

Linux ARM compiler executables run natively. Linux x86 and RISC-V compiler executables run through QEMU user emulation. The generated ARM outputs in the QBE upstream runtime checks execute natively. These are finite workload qualifications, not general equivalence proofs.

Original and corrected QBE are separate oracle labels throughout. The summary and raw reports retain all original-QBE failures and their diagnostics; corrected-source passes must not be reported as original-source passes. The GCC-built original QBE remains the assembly reference. Every correction is included with its original source binding. Comparator controls are required to detect changed output: QBE appends a changed assembly comment; cproc changes valid sentinel IR from extsw 37 to extsw 38. These establish comparator sensitivity, not independent semantic proof.

The unchanged proven helpers retain one mandatory QBE diagnostic sweep plus incidental build-duration fields. Runs shared the machine with other gates. No performance comparison or speed claim is made.

Full compiler source and build identity, exact executed helpers/dependencies, commands, stdout logs, six final reports, oracle correction descriptors and compressed input/control artifacts are included. Complete raw assemblies, objects and executables remain in their report-bound `.build/linux-arm64/combined-amd-data-v1-*` directories. Helper pre/post source/compiler/oracle bindings and guest/host artifact checks passed, followed by an outer final-report digest barrier and complete source/helper/compiler pre/post validation. `manifest.json` binds this compact publication package.
