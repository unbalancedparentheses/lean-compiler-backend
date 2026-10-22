from pathlib import Path
import hashlib,json
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');w=Path('.build/aggregate-copy');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();helper=Path('scripts/large_aggregate_abi.py');assert helper.read_bytes()==(w/'immutable-helper-history/final-v3.py').read_bytes()
paths=[helper,w/'cap-candidate',w/'numeric-copy-only',w/'before',Path('compiler-build.json'),w/'FINAL-QUALIFICATION.md',w/'AUDIT.md',w/'bind-final.py'];reports=[]
for name in ['AArch64','AMD64','RV64','AggregateABI','AMD64ABI','RV64ABI']:paths.append(Path('LeanCompilerBackend')/(name+'.lean'))
for name in ['check.sh','linux_arm64.py','linux_targets.py','macos_x86.py']:paths.append(Path('scripts')/name)
paths += [w/n for n in ['numeric-copy-core.patch','cap-only.patch','final-tests.patch','final-hooks.patch','run-final.py','emission-final.py','final-v3-matrix.log','final-v3-emission.log','final-v3-native-cli.log']]
for target in ['aarch64-macos','x86_64-macos','aarch64-linux','x86_64-linux','riscv64-linux']:
 case=(root/'.build/linux-arm64'/('aggregate-copy-final-v3-'+target) if target.endswith('linux') else w/('final-v3-'+target))/'large-aggregate-abi';r=json.loads((case/'report.json').read_text());assert r['harness_sha256']==sha(helper) and r['executed_matrix_modes']==4 and r['executed_maximum_modes']==6 and len(r['sizes'])==22 and r['control']=='zeroed ABI copy detected';assert len([x for x in r['boundaries'] if 'refusal' in x])==9
 reports.append(dict(target=target,report=str((case/'report.json').resolve()),sha256=sha(case/'report.json'),qbe_sha256=r['qbe_sha256'],compiler_identity=r['compiler_identity']))
 paths+=list(case.rglob('*'))
 emit=w/'final-emission-v3'/target/'large-aggregate-abi';er=json.loads((emit/'report.json').read_text());assert er['executed_matrix_modes']==er['executed_maximum_modes']==0 and er['harness_sha256']==sha(helper);paths+=list(emit.rglob('*'))
paths+=list((w/'final-v3-native-cli').rglob('*'))
m=dict(status='passed',compiler_identity=reports[0]['compiler_identity'],reports=reports,files={str(p.resolve()):sha(p) for p in paths if p.is_file()},scope='Fresh final-v3 only; source identity unchanged69c2. Core+cap stages preserved separately. OriginalQBE through65537; maximum independent C only. No timing claim.')
(w/'final-v3-manifest.json').write_text(json.dumps(m,indent=2)+'\n');print(len(m['files']),'final bound files, all five reports validated')
