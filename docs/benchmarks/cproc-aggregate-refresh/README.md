# Cproc self-compilation refresh

Compiler identity `a23afe3b4889b9da79c50d5ddf5b7e3e4affe2ba26d1e2c5072ed14c73cbdaaa` passes a fresh cproc bootstrap on all three Linux targets. Both baseline and optimized modes compile all 18 frontend units, reproduce 19 stage-two IR files exactly, and pass all 196 original tests per target: 114 IR reproductions and 1,176 test executions across six LCB profiles.

The inputs are unchanged pinned cproc `d1c53ddf56571573a7025324c8dd5c6d547a4d1f` and cJSON `c859b25da02955fef659d658b8f324b5cde87be3`. GCC builds the stage-one frontend and links stage-two objects with libc. ARM runs natively in the Linux VM; x86 and RV run under QEMU. The original tests exercise frontend IR, preprocessing and diagnostics; this is not a claim that 196 compiled target programs execute.

Unchanged original QBE passes on x86. Its ARM frontend crashes on `attr` with exit 139, and its RV output fails to link because of the known external GOT-addend defect. Those failures remain in the reports. Separately labeled test-only corrected QBE references pass on ARM and RV. Original source files match the pinned manifest; correction patches and binaries have separate bindings. The existing independent external-offset C probe reproduces these distinctions. RV QBE linking explicitly uses `-no-pie`.

The integrated `scripts/cproc_bootstrap.py --work PATH` option requires a fresh empty directory under `.build/linux-arm64` and keeps all source, configuration and build output there. Outside/nonempty path guards pass. The executed private runner is byte-identical to the integrated script; existing default paths remain for compatibility. This campaign never rebuilt the older bound source directories.

All nine successful backend/reference profiles also reproduce a small sentinel. Changing its valid IR operand from `extsw 37` to `extsw 38` is detected by the exact reproduction comparator. This checks comparator sensitivity, not independent semantic preservation or execution of a mutant frontend. The initial harness preflight incorrectly expected a direct `ret 37`; its script/log are retained, and all final campaigns used fresh directories after correcting the mutation pattern.

Source, configuration, compiler, frontend, oracle, IR, executable and helper bindings pass pre/post checks. Independent publication verification rechecks 3,064 bound files, the report digests and all pinned original-QBE sources. Guest/host barriers cover 931 ARM, 892 x86 and 930 RV artifacts. Compile durations are diagnostic under concurrent load and support no performance comparison.
