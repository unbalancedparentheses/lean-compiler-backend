from pathlib import Path
import hashlib,json,subprocess,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';out=base/'unused-call-results-review';private=Path('/tmp/lcb-dead-call-results');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for src,name in [(private/'scripts/unused_call_results.py','unused_call_results.py'),(private/'compiler-build.json','compiler-build.json'),(Path('/tmp/lcb-unused-call-results-run.py'),'run.py'),(Path('/tmp/lcb-unused-call-results-emission.py'),'emission.py'),(Path('/tmp/lcb-unused-call-results-finalize.py'),'finalize.py'),(Path('/tmp/lcb-unused-call-results-tests.patch'),'tests.patch')]:shutil.copy2(src,out/name)
for name in ['matrix','emission','preflight-mutation','rv-original-failure']:shutil.copy2(Path('/tmp')/('lcb-unused-call-results-'+name+'.log'),out/(name+'.log'))
r=json.loads((out/'reports.json').read_text())
for target,v in r.items():
 assert v['compiler_sha256']==sha(out/'compiler');case=out/target/'unused-call-results';assert sha(case/'calls.ssa')==v['source_sha256'] and sha(case/'caller.c')==v['caller_sha256']
 for label,row in v['backends'].items():
  assert sha(case/(label+'.s'))==row['assembly_sha256']
  if target=='riscv64-linux' and label=='qbe':assert row['execution']=='failed_known_signed_subword_return_extension' and row['exit']==4
  else:assert row['execution']=='passed'
 assert v['negative_controls']['dropped_call']=='detected exit1'
rv=r['riscv64-linux'];assert rv['qbe_reduced_profile']['excluded_signed_return_comparisons']==64 and rv['qbe_reduced_profile']['status']=='passed'
manifest={str(p.relative_to(base)):sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='qualification.json'}
p=subprocess.run(['docker','exec','-i','lcb-parity-linux','python3','-c','import sys,json,hashlib;m=json.load(sys.stdin);print(json.dumps({p:hashlib.sha256(open("/work/"+p,"rb").read()).hexdigest() for p in m}))'],input=json.dumps(manifest),capture_output=True,text=True);assert p.returncode==0,p.stderr;assert json.loads(p.stdout)==manifest
q={'status':'lcb_passed_with_known_original_qbe_rv_failure','compiler_identity':next(iter(r.values()))['compiler_identity'],'lcb_c_groups_per_mode_target':672,'total_lcb_c_groups':10080,'original_qbe':'Full672groups passfourtargets; unchanged fullRVfixture fails usedsigned-subword-return control.','rv_original_profile':'Same originalIR/assembly; omit only64sb/sh returned-value comparisons.608fullgroups+64retainedsideeffect-only controls pass. No discarded-call effect checks removed.','negative_controls':'Five optimized dropped-call mutations exit1; staticwrong-signature/aggregate guards and interpreterchecks retained.','artifact_count':len(manifest),'files':manifest,'postvalidation':'Compiler/input/caller/assembly hashes and completehostguestdigestbarrier pass.','preflights':'One harness mutation parser assumed ARMcomments; fixed to functionlabels. FulloriginalRV failure independentlyreproduced and documented, not relabeledpass.','scope':'Assignedunused scalarreturns w/l/s/d/sb/ub/sh/uh direct/indirect/external;usedscalarresults;largeaggregatehiddenreturnunused;computedindirecttarget;usedenvironment+12arguments;emptyvariadicmarker. No coreedits by helperowner.','execution_profiles':{'aarch64-macos':'nativeAppleARM','aarch64-linux':'nativeARMLinuxVM','x86_64-macos':'Rosetta','x86_64-linux':'QEMU','riscv64-linux':'QEMU'},'timing':'Notrun.'}
(out/'qualification.json').write_text(json.dumps(q,indent=2)+'\n');print('postvalidated',len(manifest),'files')
