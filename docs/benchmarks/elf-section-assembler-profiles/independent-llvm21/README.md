# Corrected independent original-QBE/LLVM object audit

The initial report is superseded: it checked a 29-name subset and omitted an extra-header rejection. All three saved objects also contained `d\040space` and `d\x20space`; the earlier complete-profile interpretation was incorrect.

The corrected audit reparses unchanged bound objects and requires exactly 31 custom sections, exact names/flags/type, 8-byte sizes for each of the three spellings, and no unexpected custom sections. Ordinary metadata/relocation headers are separately allowed; RV attributes require exact type/flags. Unchanged QBE preserves these lexical spellings with LLVM, whereas LCB canonicalizes the equivalent IR strings into one name (29 custom sections). This is a compatibility boundary, not compiler byte-equivalence. No C execution or global-symbol validation was performed by this independent object probe; root's matrix supplies those checks.
