from pathlib import Path
import hashlib,json,subprocess,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';out=base/'unused-call-results-main-review';prep=Path('/tmp/lcb-unused-call-results-main');dest=root/'docs/benchmarks/unused-call-results/main';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
bindings=json.loads((prep/'input-bindings.json').read_text());m=json.loads((root/'compiler-build.json').read_text());expected='77ea0aaf88b3ede106fce810658fddb41546fe2b85b78cfb9125dae6129eb1a4';assert m['identity']==expected
for name,h in bindings.items():assert sha(root/name)==h,('bound source changed',name)
for name,h in m['files'].items():assert sha(root/name)==h,('compiler manifest source changed',name)
for name in ['run.py','emission.py','finalize.py','input-bindings.json']:shutil.copy2(prep/name,out/name)
for name in ['matrix','emission']:shutil.copy2(Path('/tmp')/('lcb-unused-call-results-main-'+name+'.log'),out/(name+'.log'))
for name in bindings:
 if name.startswith('.build/'):continue
 p=out/'source-bindings'/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/name,p)
r=json.loads((out/'reports.json').read_text());emission=json.loads((out/'emission-only.json').read_text())
for target,v in r.items():
 assert v['compiler_identity']==expected and v['compiler_sha256']==sha(out/'compiler')==bindings['.build/lcb-unused-call-results-main'];case=out/target/'unused-call-results';assert sha(case/'calls.ssa')==v['source_sha256'] and sha(case/'caller.c')==v['caller_sha256']
 for label,row in v['backends'].items():
  assert sha(case/(label+'.s'))==row['assembly_sha256']
  if target=='riscv64-linux' and label=='qbe':assert row['execution']=='failed_known_signed_subword_return_extension' and row['exit']==4
  else:assert row['execution']=='passed'
 assert v['negative_controls']['dropped_call']=='detected exit1'
 assert emission[target]['compiler_identity']==expected and emission[target]['checks_per_backend']==0 and emission[target]['original_qbe']=='not-run'
rv=r['riscv64-linux'];assert rv['qbe_reduced_profile']['excluded_signed_return_comparisons']==64 and rv['qbe_reduced_profile']['status']=='passed'
manifest={str(p.relative_to(base)):sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='qualification.json'}
p=subprocess.run(['docker','exec','-i','lcb-parity-linux','python3','-c','import sys,json,hashlib;m=json.load(sys.stdin);print(json.dumps({p:hashlib.sha256(open("/work/"+p,"rb").read()).hexdigest() for p in m}))'],input=json.dumps(manifest),capture_output=True,text=True);assert p.returncode==0,p.stderr;assert json.loads(p.stdout)==manifest
q={'status':'lcb_passed_with_known_original_qbe_rv_failure','compiler_identity':expected,'compiler_sha256':sha(out/'compiler'),'input_bindings':bindings,'compiler_source_manifest_identity':m['identity'],'lcb_c_groups_per_mode_target':672,'total_lcb_c_groups':10080,'original_qbe':'Full672groups passfourtargets; unchanged fullRVfixture fails usedsigned-subword-return control exit4.','rv_original_profile':'Same originalIR/assembly; omit only64sb/sh returned-value comparisons.608fullgroups+64retainedsideeffect-only controls pass. No unused-call effect checks removed.','negative_controls':'Five optimized dropped-call mutations exit1; staticwrong-signature/aggregate guards and interpreterchecks retained.','artifact_count':len(manifest),'files':manifest,'postvalidation':'All compiler manifest source hashes and before/after helper/hook/core bindings unchanged. Immutable snapshot matches executed binaries. Completehostguestdigestbarrier passed.','scope':'Fresh actualmain five-target C/QBE matrix and emission-only controls. Separate private38c41af results are not relabeled. Root owns broadergates,proofs,workloads and units.','execution_profiles':{'aarch64-macos':'native Apple ARM','aarch64-linux':'native ARM Linux VM','x86_64-macos':'Rosetta','x86_64-linux':'QEMU','riscv64-linux':'QEMU'},'timing':'Not run.'}
(out/'qualification.json').write_text(json.dumps(q,indent=2)+'\n');dest.mkdir(parents=True,exist_ok=True)
for name in ['qualification.json','reports.json','emission-only.json','matrix.log','emission.log','run.py','emission.py','finalize.py','input-bindings.json']:shutil.copy2(out/name,dest/name)
shutil.copytree(out/'source-bindings',dest/'source-bindings',dirs_exist_ok=True)
for name in ['calls.ssa','caller.c']:shutil.copy2(out/'aarch64-macos/unused-call-results'/name,dest/name)
for source,name in [('qbe.s','rv-original-qbe.s'),('qbe-rv-discard-scope.c','rv-qbe-reduced-caller.c')]:shutil.copy2(out/'riscv64-linux/unused-call-results'/source,dest/name)
(dest/'README.md').write_text('''# Actual-main unused-call-result qualification

Fresh actual-main snapshot `77ea0aaf88b3ede106fce810658fddb41546fe2b85b78cfb9125dae6129eb1a4` passed all three LCB modes on five targets: 672 independent C check groups per mode/target, **10,080 LCB groups**. Apple ARM and Linux ARM VM execute natively; Apple x86 uses Rosetta and Linux x86/RV use QEMU. Every dropped-call mutation failed with exit 1. All five missing-tool emission-only controls passed.

Original QBE passed the full fixture on four targets. Its unchanged full RV64 fixture again failed the documented used signed-subword return-extension control with exit 4. The raw failed executable, full caller, IR and assembly remain retained. A separate RV64 C caller uses exactly that same QBE assembly and IR, omitting only 64 signed-byte/signed-halfword returned-value comparisons while retaining their calls and side-effect checks. It passes 608 full groups plus 64 side-effect-only replacements. Every assigned-unused-call effect check remains present. This is not a full original-QBE RV64 pass; no oracle source or IR was patched. RV64 QBE explicitly links with `-no-pie`.

The tests cover assigned unused scalar results, used scalar results, aggregate hidden return storage, computed indirect targets, environments, stack arguments and empty variadic markers. Unknown native external/indirect signatures remain ABI assumptions. Exact outcomes, compiler/oracle hashes and retained source/caller/assembly hashes are in `reports.json`. The qualification verifies every compiler source-manifest hash, before/after helper/hook/core bindings, immutable compiler snapshot, and the complete host/guest artifact digest barrier. `source-bindings/` retains the exact implementation/helper/hooks tested.

This is fresh main evidence, not relabeled private `38c41af` evidence. Broader gates, proof audit, units and workload comparisons are owned and reported separately by the root worker. No timing or compiler rebuilding occurred in this matrix campaign. Raw artifacts are in `.build/linux-arm64/unused-call-results-main-review/`.
''')
print('postvalidated',len(manifest),'files; published',dest)
