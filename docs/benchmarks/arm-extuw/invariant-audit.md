## Invariant audit

All declared-word GP homes have zero upper 32 bits under current emitter:
- parameters: register/FP saves use W destination, stack scalar/subword loads use W;
- phi edges: direct moves and cycle staging use phi width, including narrowing self-copies scheduled after old-long-bit consumers;
- arithmetic, divide/remainder, integer negation/extensions, integer/float comparisons: W instructions (comparison cset always W);
- extsw/extuw themselves require a long result by validation, so signed X extension cannot define a word;
- memory loads, including adjacent addressing selector: W for word result, even signed byte/half/word loads;
- copies/casts: width-specific load or W move; symbol/TLS word loads explicitly normalize;
- float arithmetic, float negate and integer/float conversion: word result transferred/written through W (single float bits included);
- external/direct/indirect ABI returns: explicit W0-to-W-home or S0-to-W-home move normalizes caller-clobbered upper bits;
- vaarg: both Darwin stack and Linux register-save paths load W for word, then word storeHome;
- allocation/aggregate pointers are long by validation; generic word stores use W;
- stable homes use the admitted target bank: caller-saved x8/x16/x17 are allowed only in bounded call/TLS-free leaf functions, while call-containing functions retain callee-saved homes; scratch/argument registers remain disjoint and allocation checks interference plus HomeFlow.

This is a source audit and targeted executable qualification, not a formal proof. Future producer paths must preserve this invariant.

