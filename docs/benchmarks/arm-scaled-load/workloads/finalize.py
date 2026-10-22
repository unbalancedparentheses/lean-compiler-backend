from pathlib import Path
import subprocess,json,hashlib,shutil,time,gzip
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';private=Path('/tmp/lcb-arm-scaled-main-zlib');pub=private/'publication';assert not pub.exists();pub.mkdir()
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
pre=json.loads((private/'sources-before.json').read_text());assert all(sha(Path(k))==v for k,v in pre.items());barriers={};reports={}
for key,name,log in [('zlib','arm-scaled-main-zlib-review','execute.log'),('lua','arm-scaled-main-lua-review','execute-lua.log')]:
 w=base/name;r=json.loads((w/'report.json').read_text());guestlast=json.loads((private/log).read_text().splitlines()[-1]);expected=guestlast.get('report_sha256',guestlast.get('execution_sha256'))
 for _ in range(100):
  if (w/'execution.json').exists() and sha(w/'execution.json')==expected:break
  time.sleep(.05)
 else:raise AssertionError('execution JSON barrier')
 e=json.loads((w/'execution.json').read_text());assert e.get('status',e.get('input_postvalidation'))=='passed'
 bindings=r['bound_inputs'] if key=='zlib' else r['bound_original_inputs'];assert all(sha(Path(k))==v for k,v in bindings.items())
 inputs=e['initial_files'] if key=='zlib' else e['pre_post_bound_files'];assert all(sha(Path(k.replace('/work',str(base),1)))==v for k,v in inputs.items())
 request={str(f.relative_to(base)):sha(f) for f in w.rglob('*') if f.is_file() and not any(x.startswith('tests-') and x!='tests-original' for x in f.relative_to(w).parts) and f.name not in ['guest-host-bindings.json']}
 # Compare both independent sides; no copying guest-generated outputs before this barrier.
 code='import pathlib,hashlib,json;r=pathlib.Path("/work/'+name+'");print(json.dumps({str(p.relative_to(pathlib.Path("/work"))):hashlib.sha256(p.read_bytes()).hexdigest() for p in r.rglob("*") if p.is_file() and not any(x.startswith("tests-") and x!="tests-original" for x in p.relative_to(r).parts)}))'
 gh=json.loads(subprocess.check_output(['docker','exec','lcb-parity-linux','python3','-c',code],text=True));assert gh
 for k,v in gh.items():assert sha(base/k)==v,k
 barriers[key]={'host_files':request,'guest_files':gh,'shared_files':len(set(request)&set(gh))};reports[key]={'report_sha256':sha(w/'report.json'),'execution_sha256':sha(w/'execution.json'),'input_count':len(inputs),'scope':e['scope']}
 dest=pub/key;dest.mkdir()
 for f in w.rglob('*'):
  if not f.is_file() or any(x.startswith('tests-') and x!='tests-original' for x in f.relative_to(w).parts):continue
  if f.suffix not in ['.json','.py','.lua','.c','.ssa']:continue
  d=dest/f.relative_to(w);d.parent.mkdir(parents=True,exist_ok=True)
  if f.suffix=='.ssa':d.with_suffix('.ssa.gz').write_bytes(gzip.compress(f.read_bytes(),mtime=0))
  else:shutil.copy2(f,d)
for f in private.iterdir():
 if f.is_file():shutil.copy2(f,pub/f.name)
q={'status':'passed','identity':'210a515a50b54c9b78a824349deea8e4a78cc0d0b26f9bde5f61a886f8e6b2b5','before_identity':json.loads((base/'arm-scaled-main-zlib-review/report.json').read_text())['before_identity'],'source_pre_post':pre,'reports':reports,'guest_host':barriers,'zlib_assembly_private_bridge':204,'zlib_each_arm_text_delta':-312,'lua_text_delta':-292,'timing':'not run; earlier private timing diagnostics remain uncontrolled-load observations, not clean performance evidence'}
(pub/'qualification.json').write_text(json.dumps(q,indent=2))
(pub/'README.md').write_text('''# Combined-main scaled-load workload correctness

Actual main identity210a515a is qualified against retained-TLS predecessor4b41bddb, with exact full identities/hashes in reports. No compiler source edits or builds and no timing measurements in this replay.

Zlib:17 unchanged target-configured IR units, bothARM targets/all3modes. All204 assemblies exactly match corresponding historical private before/96c8 candidate outputs. Exhaustive delta audit identifies74scaled folds/ARM, optimized text -312bytes; baseline/allocated unchanged. LinuxARM native VM execution passes6example runs and72exact GCC/Pythoncompressed-stream checks. Apple objects assembled only; no Apple zlib executable claim.

MixedLua: optimizedLinuxARM only,30LCB/cprocIRunits plus3unchangedGCC volatile-unit objects.73scaled folds across16units account for allchanges, text -292bytes. Freshbefore/after and reused, hash-verified GCCO0/GCCO2/originalQBE/correctedQBE executables each run independentprobe and two reduced upstream suite profiles (6probes+12suite invocations). Official _U and soft/port exclusions retained; not fullLua, notallLCB, and no fresh reference builds. Empty-main mutation must be detected despite exit0.

Source/compiler/helper/oracle/IR/fixtures/executables have pre/post binding checks. Guest execution reports are digest-gated; finalguest/host hashes checked without overwriting guest-generated outputs. Original andcorrectedQBE remain separately labeled. Staticcode reductions are not runtime performance claims.
''')
files={str(f.relative_to(pub)):sha(f) for f in sorted(pub.rglob('*')) if f.is_file()};(pub/'manifest.json').write_text(json.dumps(files,indent=2));print(len(files),sha(pub/'manifest.json'));print(json.dumps(reports))
