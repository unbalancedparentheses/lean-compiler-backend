# Function-level indexed-load diagnostics, protocol v2

These are exact assembly-body mixtures, not new compiler identities. Library
controls retain phi `1fb34f883f3d1b0a8cec71544974df3fc5a9b4a23c7c300a144677eae3e4bcfc`
and indexed `e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4`.
Only `longest_match` is indexed in longest-only; deflate-except-longest has the
opposite composition. Every other library unit is phi for these mixtures. Exact
body/object provenance and all 15 correctness profiles are in ../function-hybrids.

Two fresh protocol-v2 windows each complete 72 samples: eight labels, nine
randomized paired rounds, mixed payload at level 6, 500 ms GCC calibration and
two warmups. Compression loops are fixed across labels/rounds; the other two
APIs run once and are excluded from this summary. Sinks agree and all 1,089 bound
files plus protocol/report hashes pass host/guest checks before and after each
window. Own builds/tests were held; unrelated user processes were not controlled.

| Variant / phi | Window 1 median [descriptive 95% interval] | Window 2 |
| --- | --- | --- |
| indexed | 1.0172 [1.0090, 1.0328] | 1.0214 [1.0138, 1.0654] |
| deflate-only | 1.0253 [0.9976, 1.0400] | 1.0253 [1.0137, 1.0452] |
| longest-only | 1.0000 [0.9786, 1.0218] | 1.0139 [0.9965, 1.0384] |
| deflate-except-longest | 1.0151 [1.0116, 1.0381] | 1.0408 [1.0275, 1.0539] |

Changing longest_match alone does not reproduce a clear slowdown; the rest of
deflate retains a slowdown in both windows. Magnitudes vary from the earlier
object windows and between these windows. Layout and warmup/cache effects remain
confounders; these finite observations neither isolate individual instructions
nor establish a universal speedup/regression. Intervals are within-window
bootstrap descriptions without multiple-comparison correction. Full raw timing,
protocols, comparison summaries and provenance are retained in each archive.

## Failed first attempt

The original untimed function preparation copied an object-probe reference list
containing crc32-only, which was absent from the eight-label function manifest.
The first attempt collected 72 raw samples, then failed its summary with KeyError;
it never completed post-timing provenance. It is explicitly **unqualified** and
retained in failed-summary-v1, including the exact script, protocol, raw samples,
error log and hashes. Its samples are not included in the qualified summary.

Protocol v2 selects paired references from the actual manifest labels and removes
the irrelevant CRC-only note. Both qualified windows were freshly rerun after
this harness correction. Compiler bodies, caller, payload and correctness bindings
did not change. The initial validation-only preparation checked bindings, not
summary execution; it was not proof that the timing script would complete.

Reproduce with the exact per-window mixed_probe.py/mixed_time.py and bound retained
workdirs. Archives use the previously published archive-window.py and refuse
replacement. No function-name special case was introduced into the compiler.
