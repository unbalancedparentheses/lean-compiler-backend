ARM indexed-load diagnostic evidence
===================================

This directory publishes diagnostic object/function mixtures, not a new compiler
or an additional compiler qualification claim. Original benchmark workdirs and
compiler snapshots were not modified. No timing was performed while packaging.

Compiler controls
-----------------
phi: 1fb34f883f3d1b0a8cec71544974df3fc5a9b4a23c7c300a144677eae3e4bcfc
indexed: e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4
Exact binary hashes, input/configuration/IR hashes, caller hashes, objects and
executables are bound in the manifests and bindings.json files. Source identities
are distinct from executable hashes. Original QBE and the separately corrected
QBE remain separate labels; GCC builds original C.

Object diagnostics: measured
----------------------------
object-hybrids contains nine labels: GCC, phi, indexed, crc32-only, deflate-only,
trees-only, deflate-trees, original QBE and corrected QBE. Each selective label
uses indexed objects only for its named units and phi objects elsewhere. Hybrid
compiler_identity is null; each object records its actual origin. Only hybrid
executables were freshly linked, using the identical retained GCC caller object.
All nine labels passed 15 correctness profiles: exact GCC compressed bytes,
Python decompression/CRC checks and verification of GCC streams. The wrong-CRC
control was detected. Pre/post checks bound 1,037 files on host and guest.

Two targeted quiet windows used nine randomized paired rounds, mixed.bin at
compression level 6, 500 ms GCC calibration, and two caller warmups. Compression
loops were fixed across labels/rounds after calibration. Decompression and CRC
used one loop each; their timings were excluded from summaries. This is a NEW
PRIVATE protocol, not the unchanged generic benchmark probe. Exact private
probe/adapter hashes and protocol are retained. Each window has 81 samples,
matching sinks, pre/post provenance, and an archive hash manifest.

Both windows reproduced indexed/phi mixed-compression slowdown (~4.4–4.5%).
Deflate-only was ~6.1–6.3% slower and deflate+trees ~5.0–5.5% slower; their
per-window descriptive bootstrap intervals exclude parity. Trees-only remained
near parity. These observations prioritize deflate.o; they do not prove a
particular instruction is responsible. CRC-only trended ~2% faster despite
unchanged measured compression code. The caller executes CRC in warmups, so
this control includes possible linked-layout AND cache-preconditioning effects.
Window 1 was noisier than window 2. All results remain retained; intervals have
no multiple-comparison correction. No universal performance claim is made.

Function diagnostics: NOT timed
------------------------------
function-hybrids includes eight correctness-qualified labels. longest-only uses
phi deflate.s except for indexed longest_match. deflate-except-longest uses
indexed deflate.s except for phi longest_match. Every non-deflate library object
is phi in both new diagnostics; phi and deflate-only are consistent controls.
The exact function region from its comment through its matching .size was
swapped. All other 33 function regions match their selected base byte for byte.
Original assemblies were independently re-emitted with immutable compiler
snapshots and matched retained originals before composition. Function body
hashes/origins and complete composed/original assemblies are included.

All eight labels passed 15 correctness profiles and the wrong-CRC control;
1,089 files passed host/guest pre/post validation. Symbol type/name multisets
and relocation type/symbol multisets match originals. Relocation offsets and
section-relative addends can change with layout and were NOT asserted equal;
raw nm/readelf output is retained. Debug and local-label text remains within
its exact copied function region. This is finite execution qualification,
not a machine-code proof. No function-level timing result exists yet.

The deflate map has 32 indexed sites: 23 byte and 9 half loads, including six
byte and one half in longest_match. No word/long sites occur. A narrow-load-only
exclusion would disable all 32; it cannot isolate longest_match. No function-name
special case has been proposed for compiler implementation.

Reproduction and later function timing
--------------------------------------
Run from the repository root. Exact scripts are published without path rewriting:
prepare-indexed-hybrids.py and prepare-indexed-functions.py retain original
absolute workspace paths. The publication is an audit/replay package, not a
standalone relocatable build. Executables, compiler snapshots, source trees,
payloads and objects are not duplicated here; retained workdirs plus their
original bound dependency workdirs are required. bindings.json enumerates all
required paths/hashes. The Docker container is lcb-parity-linux, with
.build/linux-arm64 mounted at /work. Prepare scripts require fresh destinations;
do not rerun them over retained evidence. Adapt paths only in a separately
identified reproduction and regenerate provenance rather than relabeling it.

Validation only (runs no benchmark executable):
  python3 .build/linux-arm64/zlib-inprocess-indexed-functions/mixed_time.py

Only after an explicit new quiet-window release, run one function window:
  python3 .build/linux-arm64/zlib-inprocess-indexed-functions/mixed_time.py --time --samples 9 --batch-ms 500 --warmups 2

Archive the completed first function window without overwriting it:
  python3 docs/benchmarks/arm-indexed-load/diagnostics/archive-window.py --work .build/linux-arm64/zlib-inprocess-indexed-functions --name mixed-window1

Before a second window, archive mixed-timing.json, mixed-timing.log,
provenance.json, manifest.json, correctness.json, bindings.json,
mixed-protocol.json, mixed_probe.py, mixed_time.py, caller.c and probe.py into
a NEW directory inside that workdir. Require timing status=completed, 72 samples
(8 labels x 9 rounds), sink agreement and latest provenance stage
=after_mixed_timing/status=passed. Hash each archived file. Never overwrite the
first archive. Repeat the timing command only within an authorized quiet period.
The adapter validates original bindings and protocol before/after; it defaults
to validation-only unless --time is explicitly supplied. Generic committed
zlib_inprocess.py --phase time cannot directly validate mixed labels because
it assumes one compiler snapshot per LCB label.

Package integrity
-----------------
package-files.json records exact source paths, SHA-256 and byte lengths of all
73 copied evidence files. It excludes this explanatory README, the new archive-window.py utility and itself.
Per-window archive-hashes.json records the original archived file hashes.
The earlier four full API/payload windows remain in the parent directory and
are not replaced or silently pooled with this targeted protocol.
