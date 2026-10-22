from pathlib import Path
import json,hashlib,shutil,tarfile
p=Path('/tmp/lcb-data-definition-limit');root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');out=p/'.build/data-limit';pub=out/'publication';pub.mkdir(exist_ok=True)
reports=json.loads((out/'reports.json').read_text());assert len(reports)==5
for path in out.iterdir():
 if path.is_file() and path.name!='after' and path.suffix in ['.py','.json','.log','.patch']:
  shutil.copy2(path,pub/path.name)
shutil.copytree(out/'discovery',pub/'discovery',dirs_exist_ok=True)
for name in ['data_definition_limit.py','check.sh','emission_only.py','linux_arm64.py','linux_targets.py','macos_x86.py']:
 target=pub/'scripts'/name;target.parent.mkdir(exist_ok=True);shutil.copy2(p/'scripts'/name,target)
shutil.copy2(Path('/tmp/lcb-retained-tls/.build/retained-tls/audit.sh'),pub/'audit.sh')
shutil.copy2(p/'scripts/ProofAudit.lean',pub/'ProofAudit.lean')
shutil.copy2(p/'upstream-lock.json',pub/'upstream-lock.json')
source=pub/'compiler-source';source.mkdir(exist_ok=True)
for name in list(json.loads((p/'compiler-build.json').read_text())['files'])+['compiler-build.json','LeanCompilerBackend/Verified/BuildIdentity.lean','Tests.lean']:
 target=source/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p/name,target)
raw={};summary=[]
for row in reports:
 path=Path(row['report']);r=json.loads(path.read_text());assert len(r['results'])==4 and all(b.get('execution')=='passed' for x in r['results'] for b in x['backends'] if 'refused' not in b)
 shutil.copy2(path,pub/(row['target']+'.json'));summary.append(dict(target=row['target'],lcb_object_checks=sum(b.get('objects_checked',0) for x in r['results'] for b in x['backends'] if b['mode']!='qbe'),qbe_object_checks=sum(b.get('objects_checked',0) for x in r['results'] for b in x['backends'] if b['mode']=='qbe'),controls=r['controls'],negative_cases=r['negative_cases']))
 for file in path.parent.rglob('*'):
  if file.is_file():raw[str(file)]=hashlib.sha256(file.read_bytes()).hexdigest()
 with tarfile.open(pub/(row['target']+'-inputs-assembly.tar.gz'),'w:gz') as archive:
  for file in path.parent.rglob('*'):
   if file.is_file() and file.suffix in ['.ssa','.c','.s']:archive.add(file,arcname=file.name)
probe=root/'.build/linux-arm64/frontend-data-count-probe-v2';catalog=root/'.build/linux-arm64/data-limit-catalog-candidate'
for directory in [probe,catalog]:
 with tarfile.open(pub/(directory.name+'.tar.gz'),'w:gz') as archive:
  for file in directory.rglob('*'):
   if file.is_file():
    raw[str(file)]=hashlib.sha256(file.read_bytes()).hexdigest()
    if file.suffix in ['.ssa','.c','.s','.json']:archive.add(file,arcname=file.name)
(pub/'raw-artifact-bindings.json').write_text(json.dumps(raw,indent=2));(pub/'summary.json').write_text(json.dumps(summary,indent=2))
text=(pub/'README.md').read_text();text+='\nFinal five-target matrix: 92,175 LCB object checks (5 targets × 3 modes × 6,145 objects), 51,210 unchanged-QBE object checks (including its admitted 4,097 case), 65 bounded rejection/budget checks and five detected wrong-last-entry mutations. The candidate also executes the unchanged 4,096-definition cproc catalog on Linux ARM in all three modes (12,285 string checks). All-five missing-tool emission controls and the default native CLI passed. Fresh units and the 147-entry proof audit passed. One initial unit syntax/build preflight is retained separately and superseded by the successful build.\n';(pub/'README.md').write_text(text)
manifest={str(x.relative_to(pub)):hashlib.sha256(x.read_bytes()).hexdigest() for x in pub.rglob('*') if x.is_file() and x.name!='manifest.json'};(pub/'manifest.json').write_text(json.dumps(manifest,indent=2));print('files',len(manifest),'manifest',hashlib.sha256((pub/'manifest.json').read_bytes()).hexdigest())
