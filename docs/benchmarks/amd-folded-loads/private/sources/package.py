from pathlib import Path
import hashlib,json,subprocess,shutil,time,gzip
p=Path(__file__).parent;root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';pub=p/'publication';assert not pub.exists();pub.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def copy(src,name):
 dest=pub/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
helper=p/'scripts/amd_folded_loads.py';matrix=base/'amd-folded-loads-private-v4';reports=json.loads((matrix/'reports.json').read_text());assert all(r['helper_sha256']==sha(helper) and r['compiler_sha256']==sha(p/'after') for r in reports.values());assert sha(p/'helper-final.py')==sha(helper)
cli=json.loads(Path('/tmp/lcb-amd-folded-cli-v4.json').read_text());assert cli['helper_sha256']==sha(helper) and all(r['execution']=='passed' for r in cli['rows'])
z=base/'amd-folded-load-zlib-v2';r=json.loads((z/'report.json').read_text());e=json.loads((z/'execution.json').read_text());last=json.loads(Path('/tmp/lcb-amd-folded-zlib-execute.log').read_text().splitlines()[-1]);assert sha(z/'execution.json')==last['report_sha256'];assert all(sha(k)==h for k,h in r['bound_inputs'].items());assert all(sha(k.replace('/work',str(base),1))==h for k,h in e['initial_files'].items())
barriers={}
for w in [matrix,z]:
 code='import pathlib,hashlib,json;r=pathlib.Path("/work/'+w.name+'");print(json.dumps({str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in r.rglob("*") if p.is_file()}))';gh=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c',code],text=True));assert gh
 for k,h in gh.items():
  for _ in range(100):
   if (w/k).exists() and sha(w/k)==h:break
   time.sleep(.05)
  else:raise AssertionError(w/k)
 barriers[w.name]=gh
 for f in w.rglob('*'):
  if f.is_file() and f.suffix in ['.json','.ssa','.c','.py']:
   dest=Path('matrix' if w==matrix else 'zlib')/f.relative_to(w)
   if f.suffix=='.ssa':
    target=pub/dest;target.parent.mkdir(parents=True,exist_ok=True);target.with_suffix('.ssa.gz').write_bytes(gzip.compress(f.read_bytes(),mtime=0))
   else:copy(f,dest)
for name in ['core','tests','hooks']:copy(Path('/tmp/lcb-amd-folded-normalization-'+name+'.patch'),name+'.patch')
for f in ['scripts/amd_folded_loads.py','run-matrix.py','controls.py','qualify-zlib.py','execute-zlib.py','audit.py','audit-zlib.py','package.py','compiler-build.json','LeanCompilerBackend/AMD64.lean','.build/amd-folded-corpus-raw.json','.build/corpus-audit.json','.build/audit.sh','.build/audit.log','.build/controls-v4.json']:copy(p/f,Path('sources')/f)
for f in ['helper-v1.py','helper-v2.py','helper-v3.py','run-matrix-v1.py','run-matrix-v2.py','run-matrix-v3.py','qualify-zlib-preflight-v1.py','matrix-v1.log','zlib-preflight-v1.log','corpus-preflight-v1.log','cli-relative-preflight.log']:copy(p/f,Path('superseded')/f)
for v in [1,2,3]:
 old=base/f'amd-folded-loads-private-v{v}'
 for f in old.rglob('*.json'):copy(f,Path('superseded')/f'matrix-v{v}'/f.relative_to(old))
# The exact original-QBE out-of-range assembly and source are retained, not patched.
for f in ['input.ssa','caller.c','qbe.s']:copy(base/'amd-folded-loads-private-v1/x86_64-macos/amd-folded-loads'/f,Path('superseded/qbe-out-of-range')/f)
for f in ['/tmp/lcb-amd-folded-normalization-build.log','/tmp/lcb-amd-folded-normalization-units.log','/tmp/lcb-amd-folded-normalization-matrix-v4.log','/tmp/lcb-amd-folded-cli-v4.json','/tmp/lcb-amd-folded-cli-v4.log','/tmp/lcb-amd-folded-zlib-execute.log']:copy(Path(f),Path('logs')/Path(f).name)
q={'status':'passed','before_identity':subprocess.check_output([p/'before','--build-identity'],text=True).strip(),'after_identity':subprocess.check_output([p/'after','--build-identity'],text=True).strip(),'before_sha256':sha(p/'before'),'after_sha256':sha(p/'after'),'helper_sha256':sha(helper),'core_source_sha256':sha(p/'LeanCompilerBackend/AMD64.lean'),'guest_host':barriers,'compiler_source_files':json.loads((p/'compiler-build.json').read_text())['files'],'qbe_provenance':{'scope':'Reused original-QBE host/guest binaries, not rebuilt in this campaign; pinned vendored C/H source hashes retained for context, not a new binary attestation','pinned_sources':{str(x.relative_to(root)):sha(x) for x in sorted((root/'third_party/qbe').rglob('*')) if x.is_file() and x.suffix in ['.c','.h']},'host_snapshot_sha256':sha(root/'.build/syntax-main-review/qbe-snapshot')},'execution_modes':{'x86_64-macos':'Rosetta','x86_64-linux':'QEMU'},'timing':'not measured','main_changed':False}
(pub/'qualification.json').write_text(json.dumps(q,indent=2));(pub/'README.md').write_text('''# AMD64 folded word-load normalization

Private candidate7e441df0 based on main210a515a (8ec0f00), exact identities/hashes in qualification.json. The core removes only the EAX self-copy emitted after allocated constant-offset word loads. All selected word-result opcodes already write EAX and zero the upper32bits; signed/unsigned opcodes, raw FP bits, long results, scratch/layout/debug and direct/baseline paths are retained. No timing or new proof claim.

Fresh compiler/test build and units pass; exact147 existing audit passes. Corpus1275assemblies/15refusals remain identical;30AMDallocated/optimized assemblies contain exactly34deleted redundant self-copies. All nonAMD/baseline outputs unchanged. Raw comparator labels intended changes failures; separate exact audit classifies them.

Finalv4 helper bothAMD targets:128functions,2048byte-oracle checks per before/afterLCB execution, all3modes. Signed/unsigned byte/half/word and long loads, FP32/64 raw bit patterns, pressure, shared-address/debug boundaries, signed32offset extremes and outside fallback, misalignment and exact-width guarded page ends. Wrong unsigned-to-signed load mutation fails. OriginalQBE unchanged legal-displacement subset112functions/1792checks passes. QBE cannot assemble the out-of-range displacement fixture; exact v1source/assembly/error retained separately, never counted as reference pass. No reference correction.

17target-configured zlib units bothAMD: optimized889self-copies removed, actualtext -1745B; allocated1276/-2578B; baseline exact. All102assembly pairs audited. Actualobjectsize includes assembler branch relaxation/alignment, not simply2bytes per deletion. LinuxQEMU6example runs and72exactGCC/Pythonstream checks pass; Appleworkload objects only. Independent focusedC executes bothtargets.

Emission-only missing-tool guards/defaultCLI and Rosetta explicitCLI pass. Finalhelper fixed relative optionalCLIpaths before finalv4qualification; failedrelativeCLIpreflight retained. Earlier v1 QBE limit failure, early workload path/preflight failures, intermediatehelper reports retained as superseded, not finalbindings. V2 Apple used the pre-CLI helper while V2 Linux observed the CLI-added helper hash; both exact helper byte versions are retained, and final V4 reruns both targets against one frozen helper. Finalv4 helper/core/snapshot hashes and finalguest/host artifact barriers are distinct; no claims that old mutable helper live paths remain bound.
''')
files={str(f.relative_to(pub)):sha(f) for f in sorted(pub.rglob('*')) if f.is_file()};(pub/'manifest.json').write_text(json.dumps(files,indent=2));print(len(files),sha(pub/'manifest.json'),{k:len(v) for k,v in barriers.items()})
