from pathlib import Path
import json,hashlib,shutil,gzip
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');w=root/'.build/linux-arm64/amd-folded-main-review';p=Path(__file__).parent;pub=p/'publication';assert not pub.exists();pub.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
r=json.loads((w/'replay-report.json').read_text());assert r['status']=='passed';assert all(sha(k)==v for k,v in r['inputs_before'].items());assert r['inputs_before']==r['inputs_after']
for k,v in json.loads((w/'artifact-hashes.json').read_text()).items():assert sha(w/k)==v,k
old=root/'.build/linux-arm64/amd-folded-load-zlib-v2';bridges=[]
for target in ['x86_64-linux','x86_64-macos']:
 for mode in ['baseline','allocated','optimized']:
  for label in ['before','after']:
   for a in sorted((w/'zlib'/target/mode/label).glob('*.s')):
    b=old/target/mode/label/a.name;assert a.read_bytes()==b.read_bytes(),a;bridges.append({'target':target,'mode':mode,'label':label,'unit':a.stem,'sha256':sha(a),'private_path':str(b)})
assert len(bridges)==204
(pub/'private-assembly-bridge.json').write_text(json.dumps({'status':'passed','assemblies':bridges,'scope':'Combined main e095 and210 outputs match private7e441 and210 respectively on all17units,all3modes,bothAMD targets.'},indent=2))
def copy(src,name):
 d=pub/name;d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,d)
for f in w.rglob('*'):
 if not f.is_file() or f.name in ['before','after']:continue
 if f.suffix in ['.json','.py','.log','.c']:copy(f,f.relative_to(w))
 elif f.suffix=='.ssa':
  d=pub/f.relative_to(w);d.parent.mkdir(parents=True,exist_ok=True);d.with_suffix('.ssa.gz').write_bytes(gzip.compress(f.read_bytes(),mtime=0))
for src,name in [(p/'audit.py','corpus/audit.py'),(p/'corpus-audit.json','corpus/audit.json'),(root/'.build/amd-folded-main-corpus-raw.json','corpus/raw.json'),(root/'compiler-build.json','source/compiler-build.json'),(root/'LeanCompilerBackend/AMD64.lean','source/AMD64.lean'),(Path('/tmp/lcb-amd-folded-main-prepared/manifest.json'),'prepared-manifest.json'),(Path(__file__),'package.py')]:copy(src,name)
q={'status':'passed','compiler_identity':r['compiler_identity'],'before_identity':r['before_identity'],'source_bindings':len(r['inputs_before']),'barrier_counts':{k:len(v) for k,v in r['guest_host'].items()},'assembly_bridge':len(bridges),'actual_main_replay_report_sha256':sha(w/'replay-report.json'),'timing':'not measured'};(pub/'qualification.json').write_text(json.dumps(q,indent=2))
(pub/'README.md').write_text('''# Actual combined-main AMD folded-load qualification

Final compiler e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e combines AMD normalization deletion and the separately qualified data-catalog limit change. Predecessor is210a515a. Immutable snapshots are copied by the runner; exact source/helper/hook/QBE/runner pre/post bindings and guest-host artifact barriers are retained. No compiler builds/source edits or timing measurements in this replay.

Both AMD targets pass before/after all3modes against independent raw-byte C oracles:128functions/2048checks per LCB execution; originalQBE legal-displacement subset112functions/1792checks. Wrong-signedness mutation is detected. Signed/unsigned widths,FP32/64rawbits,pressure,debug/shared-use exclusions,signed32displacement boundaries, outside-bound fallback and exact-width guard-page ends are covered. Rosetta and LinuxQEMU are explicitly the execution modes. Emission-only missing-tool guards, default emission CLI and explicit Rosetta CLI pass. OriginalQBE out-of-range displacement refusal remains in the private precursor evidence, not counted as a reference pass here.

Zlib17target-configured units:102before/after assembly pairs pass exact-deletion audit; all204assemblies bridge byte-for-byte to corresponding private qualified snapshots. Each AMD target optimized889self-copies removed/text-1745B; allocated1276/text-2578B; baseline unchanged. Object text includes assembler branch relaxation/alignment. Fresh LinuxQEMU6examples+72exactGCC/Pythonstreams pass; Appleworkload objects only. No speed claim.

Current corpus:1275identicalassemblies+15identicalrefusals;30AMDallocated/optimized changed outputs contain exactly34expectedself-copy deletions. Every baseline/nonAMD output unchanged. Raw comparator's intended byte-difference failures are retained alongside the exhaustive structural audit.
''')
files={str(f.relative_to(pub)):sha(f) for f in sorted(pub.rglob('*')) if f.is_file()};(pub/'manifest.json').write_text(json.dumps(files,indent=2));print(len(files),sha(pub/'manifest.json'),json.dumps(q))
