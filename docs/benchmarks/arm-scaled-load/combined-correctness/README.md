# Fresh ARM five-label build and correctness only

Fresh actual-main e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e (`combined-scaled`) versus retained-TLS4b41bddb (`predecessor`), plus freshly rebuilt GCC, unchanged originalQBE and explicitly correctedQBE reference labels. Exact identities/source/configuration/IR/caller/object/executable hashes are retained in manifest.json. CorrectedQBE is separate from unchanged upstream; its patch is not silently used as the original oracle.

All five labels pass15 correctness profiles each, including exact sink/output checks and negative controls. Before/after correctness provenance checks each bind485host/guest files, and78main source/helper/snapshot input hashes remain unchanged. This is native ARM Linux in the VM. No timing phase ran; there is no benchmark result or performance claim. Earlier scaled-load windows remain withdrawn noisy diagnostics, separate from this package.

The unchanged benchmark script, exact build command/logs, caller/probe,15IRfiles compressed losslessly, source-hash map and oracle diff are retained; binaries/objects are excluded. Raw build directory remains .build/linux-arm64/zlib-inprocess-scaled-combined for any later separately qualified monitored timing.
