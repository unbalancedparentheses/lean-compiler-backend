from pathlib import Path
import json,hashlib,subprocess,shutil,sys
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';work=base/'lua-mixed-review';sys.path.insert(0,str(root/'scripts'));from docker_sync import host_file
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def guest(p):return str(p).replace(str(base),'/work')
def run(cmd,inside=False,cwd=None):
 c=list(map(str,cmd));c=['docker','exec','lcb-parity-linux',*c] if inside else c
 return subprocess.run(c,capture_output=True,text=True,cwd=cwd,timeout=300)
def checked(cmd,inside=False,cwd=None):
 p=run(cmd,inside,cwd);assert p.returncode==0,(cmd,p.returncode,p.stderr);return p
r=json.loads((work/'report.json').read_text());assert sha(work/'compiler')==r['compiler_sha256'];references=json.loads((work/'reference-execution.json').read_text());assert all('failure' not in row for row in references.values()) and len(references)==2
r['reference_execution_sha256']=sha(work/'reference-execution.json')
def save():(work/'report.json').write_text(json.dumps(r,indent=2)+'\n')
lock=json.loads((root/'upstream-lock.json').read_text());patchpath=root/'tests/upstream/qbe-1.3-arm64-extern-offset.json';patch=json.loads(patchpath.read_text());r['oracle_patch_sha256']=sha(patchpath);oracles={};r['oracle_builds']={}
for label in ['qbe-original','qbe-corrected']:
 source=work/(label+'-source');shutil.copytree(root/'third_party/qbe',source)
 files={p:h for p,h in lock['vendored_files'].items() if p.startswith('third_party/qbe/')}
 for path,h in files.items():assert sha(root/path)==h
 if label=='qbe-corrected':
  p=source/patch['source'];s=p.read_text();assert s.count(patch['before'])==1;p.write_text(s.replace(patch['before'],patch['after']))
 checked(['make','clean'],cwd=source);checked(['make','-j2','CC=cc','CFLAGS=-std=c99 -O2'],cwd=source);oracles[label]=source/'qbe';r['oracle_builds'][label]={'binary_sha256':sha(source/'qbe'),'source_hashes':{str(Path(p).relative_to('third_party/qbe')):sha(source/Path(p).relative_to('third_party/qbe')) for p in files},'correction':patch if label=='qbe-corrected' else None};save()
for label in ['lcb-baseline','lcb-allocated','lcb-optimized','qbe-original','qbe-corrected']:
 case=work/label;case.mkdir();objects={};row={'build_status':'running','execution_status':'not-run','objects':{},'ir_compiled_units':[],'gcc_shared_units':r['excluded_frontend_units']};r['backends'][label]=row;save()
 for unit in r['units']:
  if unit in r['excluded_frontend_units']:
   obj=work/'gcc-O2'/(unit+'.o');assert sha(obj)==r['backends']['gcc-O2']['objects'][unit]
  else:
   ir=work/'ir'/(unit+'.ssa');assert sha(ir)==r['frontend'][unit]['ir_sha256'];asm=case/(unit+'.s');obj=case/(unit+'.o')
   if label.startswith('lcb'):
    flags={'lcb-baseline':[],'lcb-allocated':['--allocate'],'lcb-optimized':['--optimize']}[label];p=run([work/'compiler',ir,'--target','aarch64-linux',*flags,'-o',asm])
   else:p=run([oracles[label],'-t','arm64','-o',asm,ir])
   if p.returncode:
    row.update(build_status='failed',failure_unit=unit,stderr=p.stderr);save();break
   host_file(asm,base,'lcb-parity-linux');p=run(['gcc','-c',guest(asm),'-o',guest(obj)],True)
   if p.returncode:row.update(build_status='failed',failure_unit=unit,stderr=p.stderr);save();break
   row['ir_compiled_units'].append(unit);row.setdefault('assembly_hashes',{})[unit]=sha(asm)
  objects[unit]=obj;row['objects'][unit]={'path':str(obj),'sha256':sha(obj)};save()
 if row['build_status']=='failed':
  print(label,'BUILD FAILED',row['failure_unit'],flush=True)
  if label.startswith('lcb'):raise RuntimeError(row['stderr'])
  continue
 assert len(objects)==33 and len(row['ir_compiled_units'])==30
 exe=case/'lua';p=run(['gcc',*map(guest,objects.values()),'-lm','-ldl','-o',guest(exe)],True)
 if p.returncode:row.update(build_status='failed',stderr=p.stderr);save();continue
 row.update(build_status='passed',executable_sha256=sha(exe));save();print(label,'built',flush=True)
for name,h in r['source_hashes'].items():assert sha(work/'source'/name)==h
for unit,row in r['frontend'].items():
 if not row['exit']:assert sha(work/'ir'/(unit+'.ssa'))==row['ir_sha256']
assert sha(work/'compiler')==r['compiler_sha256'];r['build_postvalidation']='passed';save()
