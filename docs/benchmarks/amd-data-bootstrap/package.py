from pathlib import Path
import json,hashlib,shutil,tarfile
p=Path('/tmp/lcb-combined-final-replay');out=p/'publication';out.mkdir(exist_ok=False);root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';name='combined-amd-data-v1';sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
identity='e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e';summary=dict(compiler_identity=identity,compiler_sha256=sha(p/(name+'-qbe')/'lcb-snapshot'),campaigns={})
for program in ['qbe','cproc']:
 campaign=p/(name+'-'+program);qualification=json.loads((campaign/'qualification.json').read_text());assert qualification['status']=='passed' and qualification['compiler_identity']==identity
 before=json.loads((campaign/'pre-bindings.json').read_text());assert before==json.loads((campaign/'post-bindings.json').read_text());assert all(sha(Path(k))==v for k,v in before.items())
 dest=out/program;dest.mkdir();summary['campaigns'][program]=[]
 for f in campaign.iterdir():
  if f.is_file() and f.name!='lcb-snapshot':shutil.copy2(f,dest/f.name)
 shutil.copytree(campaign/'scripts',dest/'scripts')
 for target in ['aarch64-linux','x86_64-linux','riscv64-linux']:
  r=json.loads((campaign/(target+'.json')).read_text());work=base/(name+'-'+program+'-'+target)
  assert sha(work/'report.json')==sha(campaign/(target+'.json'))
  with tarfile.open(dest/(target+'-inputs-controls.tar.gz'),'w:gz') as tar:
   for f in work.rglob('*'):
    rel=f.relative_to(work)
    if not f.is_file() or '.git' in rel.parts:continue
    selected=(program=='qbe' and (rel.parts[0]=='ir' or f.name in ['commands.jsonl','probe.py','probe.json'] or (len(rel.parts)==1 and f.suffix=='.log'))) or (program=='cproc' and len(rel.parts)==1 and f.suffix in ['.ssa','.c','.log'])
    if selected:tar.add(f,arcname=str(rel))
  if program=='qbe':row=dict(target=target,units=len(r['translation_units']),qualified_backends=[k for k,v in r['backends'].items() if v.get('original_runner_passes')==58],fixture_assemblies=455,self_ir_assemblies=32,original_runtime_tests=58,original_failure=r['backends']['qbe'].get('failure'),comparator_control=r['comparator_control'],pre_post_bindings=len(r['provenance']['pre_post_bindings']),guest_host_bindings=r['provenance']['guest_host_count'])
  else:row=dict(target=target,units=len(r['translation_units']),qualified_backends=[k for k,v in r['backends'].items() if v.get('upstream_tests_passed')==196],stage2_ir=19,upstream_tests=196,original_failure=r['backends']['qbe'].get('failure'),negative_controls=r['negative_controls'],pre_post_bindings=len(r['provenance']['files']),guest_host_bindings=r['provenance']['guest_host_files'])
  summary['campaigns'][program].append(row)
shutil.copytree(p/(name+'-qbe')/'compiler-source',out/'compiler-source');shutil.copy2(p/(name+'-qbe')/'compiler-build.json',out/'compiler-build.json')
for file in ['run.py','package.py',name+'.log']:shutil.copy2(p/file,out/file)
shutil.copy2(root/'upstream-lock.json',out/'upstream-lock.json');patches=out/'oracle-corrections';patches.mkdir()
for file in ['qbe-1.3-amd64-extern-flags.json','qbe-1.3-arm64-extern-offset.json','qbe-1.3-rv64-extern-offset.json']:shutil.copy2(root/'tests/upstream'/file,patches/file)
(out/'summary.json').write_text(json.dumps(summary,indent=2))
(out/'README.md').write_text('''# Fresh combined compiler: QBE and cproc replay

Compiler identity: `e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e`. This actual-main snapshot includes the combined AMD lowering and 4,096-data-definition profile. Both programs were rebuilt in fresh, separate work directories for Linux ARM64, x86-64 and RISC-V64. No compiler rebuild or source change occurred in this campaign.

QBE: all 32 unchanged pinned QBE 1.3 translation units were compiled through the pinned cproc frontend. LCB baseline and optimized compiler executables each reproduce 455 upstream-fixture assemblies and 32 self-IR assemblies, and pass 58 original ARM64 runtime tests per platform. Across the two LCB modes and three platforms: 2,922 exact assembly reproductions and 348 runtime-test executions. The assembly comparison spans QBE's targets, including its own Windows output; this does not imply Windows support in LCB.

cproc: all 18 unchanged pinned frontend units were rebuilt. LCB baseline and optimized each reproduce 19 stage-two IR files (18 frontend units plus cJSON) and pass 196 original cproc tests per platform: 114 IR reproductions and 1,176 test executions across both modes and all three platforms.

Linux ARM compiler executables run natively. Linux x86 and RISC-V compiler executables run through QEMU user emulation. The generated ARM outputs in the QBE upstream runtime checks execute natively. These are finite workload qualifications, not general equivalence proofs.

Original and corrected QBE are separate oracle labels throughout. The summary and raw reports retain all original-QBE failures and their diagnostics; corrected-source passes must not be reported as original-source passes. The GCC-built original QBE remains the assembly reference. Every correction is included with its original source binding. Comparator controls are required to detect changed output: QBE appends a changed assembly comment; cproc changes valid sentinel IR from extsw 37 to extsw 38. These establish comparator sensitivity, not independent semantic proof.

The unchanged proven helpers retain one mandatory QBE diagnostic sweep plus incidental build-duration fields. Runs shared the machine with other gates. No performance comparison or speed claim is made.

Full compiler source and build identity, exact executed helpers/dependencies, commands, stdout logs, six final reports, oracle correction descriptors and compressed input/control artifacts are included. Complete raw assemblies, objects and executables remain in their report-bound `.build/linux-arm64/combined-amd-data-v1-*` directories. Helper pre/post source/compiler/oracle bindings and guest/host artifact checks passed, followed by an outer final-report digest barrier and complete source/helper/compiler pre/post validation. `manifest.json` binds this compact publication package.
''')
manifest={str(f.relative_to(out)):sha(f) for f in out.rglob('*') if f.is_file()};(out/'manifest.json').write_text(json.dumps(manifest,indent=2));print(out,len(manifest),sha(out/'manifest.json'))
