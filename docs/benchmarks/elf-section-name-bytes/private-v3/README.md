# Private printable ELF section-name qualification

Candidate60e510e707c849ca375d8257d60a64972246624466c90712cf63ef3bec74fd4e based05188/a23afe; does not include later customTLS/R changes. Core admits decoded printableASCII0x20..0x7e names of1..128bytes. ELF emitter escapes backslashes first, then quotes; other bytes/spelling unchanged. Apple grammar/emission unchanged. No main edits or commits.

Freshbuild/fullunits/147proof-audit assertions pass. Full existingcorpus:1305identical assemblies+15identical refusals,0changes acrossfive targets/threemodes. This is finitecorpus equivalence, not universalproof.

Freshv2 matrix onthreeLinux targets executes baseline/allocated/optimized and unchangedQBE.14data/functionname pairs include1/128bytebounds, spaces/colon/slash/plus/@, literalquotes/backslashes, literalbackslash-n, all95printableASCIIbytes, and injection-looking names. Threeadditionaldata definitions use literalspace/octalescape/hexescape spellings that map to one exactsectionname. RawELF64 stringtable parsing verifies29exactcustomnames, flags andPROGBITS types; nm verifies exactly31definedglobal symbols. Cchecks all14functions/data pairs and3escaped-equivalentdata values. There are no unintendedsymbols/sections. NativeLinuxARMVM; x86/RV underQEMU. No performance claim.

EachLinux target detects a wrongname mutation via exactmetadata and a wrongvalue mutation viaC exit1. Invaliddecodedempty/129/control/NUL/DEL/nonASCII names are refused inallthree modes. Firstpath remains excluded. BothApple targets verifyexistingordinarycustomsectionfixture assemblybyteequality and15negativeemissionprofiles; no newApple runtimeclaim. Allfive ordinaryfixtures comparebyteidentically tobefore; whenbefore absent reusablehelper explicitlyskips comparison. Tenmissingtool emission-only profiles (fivewith/fivewithoutbefore), nativeApple CLI, Python/shell syntax checks pass. Hookpatch coverscheck.sh, alltargetrunners andemission_only.py.

Initialv1 matrix passedARM/x86 then correctlystopped becausehelper omitted legitimateassembler-generated RV .riscv.attributes fromallowlist. V2 admits onlythat exactname withtype0x70000003/flags0, preservesallstrictcustomchecks, and rerunsfreshallfive. Preservedv1 helper/log. Compiler unchangedduringmatrix.

OriginalQBE is unchanged; binarieshashedperreport. Sourceinput/helper/compiler/core/hooks/report bindings andLinuxguest-host barriers recorded. Reports areexactprivatecandidate qualification; regenerateidentity and rerunaftercombinedmainintegration. No broadgrammar beyondprintableASCII; flags retaintheir separatevalidatedgrammar.


## Final v3 review correction

Use this package for final helper integration. The compiler/coreidentity remains60e510e7; no rebuild/corechange. Existingsection_names.py contained staleLinux negatives for newlyadmitted printable names; these nowremain Apple-only, whiletruecontrol/NUL/DEL/nonASCII/length negativesremain. Newhelper nowchecks rawmatchedheadercount==29 before dictionaryconversion, preventing duplicate names fromcollapsing. Freshv3 newhelper campaign passes allfive; existinghelper regression independentlypassesallfive with252Cchecks each (1260total acrossLCB/originalQBE), retainingexistingApplequoted-section discrepancies/16byteboundaryfailure.15missingtoolprofiles (newhelperfivewithbefore+fivewithout, oldhelperfive) andnativeAppleCLI pass.

Earlier publication/README+manifest and exactqualifiedhelper bytes remain historical. Their livehelper/hook bindings are superseded by thisnewcampaign; no oldreport relabeled. Old v2 core/build/unit/proof/corpus evidence remainsapplicable because core/binaryunchanged. Finaltests.patch includesboth newhelper andnecessary existinghelper correction; hooks/corepatch unchanged. Exactsource/inputs/report bindings andsixLinuxhelper guest-host barriers below. No main edits/commits.
