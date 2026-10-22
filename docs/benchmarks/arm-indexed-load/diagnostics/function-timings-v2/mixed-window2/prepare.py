from pathlib import Path
import copy,hashlib,json,shutil,subprocess,sys,time
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';src=base/'zlib-inprocess-indexed-hybrids';w=base/'zlib-inprocess-indexed-functions';sys.path.insert(0,str(root/'scripts'));import docker_sync
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def guest(p):return '/work/'+str(Path(p).relative_to(base))
def cmd(args):
 r=subprocess.run(list(map(str,args)),text=True,capture_output=True,timeout=300);assert r.returncode==0,(args,r.returncode,r.stdout,r.stderr);return r.stdout
def docker(args):return cmd(['docker','exec','lcb-parity-linux',*args])
def barrier(p):
 wanted=docker(['sha256sum',guest(p)]).split()[0]
 for _ in range(100):
  if p.exists() and sha(p)==wanted:return wanted
  time.sleep(.05)
 raise AssertionError(str(p))
def sync(p):docker_sync.host_file(p,base,'lcb-parity-linux')
original=json.loads((src/'manifest.json').read_text());assert sha(root/'scripts/zlib_inprocess.py')==original['script_sha256']
# Preserve original qualification and exact compiled controls. No frontend/compiler execution.
assert not w.exists();w.mkdir();(w/'origin').mkdir()
for n in ['manifest.json','correctness.json','provenance.json']:shutil.copy2(src/n,w/'origin'/n)
for n in ['source','ir','qbe-original-source','qbe-corrected-source','gcc','phi','indexed','deflate-only','qbe-original','qbe-corrected']:shutil.copytree(src/n,w/n)
for n in ['caller.c','caller.o','probe.py','negative-driver','binding-report.json','compiler-phi','compiler-indexed',*original['payload_hashes']]:shutil.copy2(src/n,w/n)
shutil.copy2(Path(__file__),w/'prepare.py')
m=copy.deepcopy(original);m['schema']=2;m['diagnostic_mixed_objects']=True;m['origin_manifest']={'path':str(src/'manifest.json'),'sha256':sha(src/'manifest.json')};m['adapter_sha256']=sha(w/'prepare.py');m['notes']+=['Diagnostic object mixtures, not compiler identities. Only hybrid drivers are freshly linked; controls and common caller are exact copies of previously qualified artifacts.','Every hybrid object is bound to original label, compiler identity and object hash. No source/IR changes or recompilation.','crc32-only compression is an unused-code/layout control: compress2 uses adler32, not CRC32.']
# Re-emit original deflate assemblies using immutable snapshots before composing bodies.
import re
m['assembly_origins']={}
for origin in ['phi','indexed']:
 fresh=w/('verified-'+origin+'-deflate.s');command=[w/('compiler-'+origin),w/'ir/deflate.ssa','--target','aarch64-linux','--optimize','-o',fresh];cmd(command)
 retained=src/origin/'deflate.s';assert fresh.read_bytes()==retained.read_bytes()
 m['assembly_origins'][origin]={'sha256':sha(fresh),'compiler_identity':original['backends'][origin]['compiler_identity'],'command':list(map(str,command))}
def bodies(text):
 result={}
 for match in re.finditer(r'// function ([^;]+);[^\n]*\n',text):
  name=match[1];end=text.index('.size '+name+', .-'+name,match.start());end=text.index('\n',end)+1
  result[name]=(match.start(),end,text[match.start():end])
 return result
texts={l:(w/('verified-'+l+'-deflate.s')).read_text() for l in ['phi','indexed']};maps={l:bodies(t) for l,t in texts.items()};assert maps['phi'].keys()==maps['indexed'].keys()
selections={'longest-only':('phi','indexed'),'deflate-except-longest':('indexed','phi')};labels=['phi','indexed','deflate-only',*selections];m['lcb_labels']=labels;m['successful_builds']=['gcc',*labels,'qbe-original','qbe-corrected'];m['backends']={k:v for k,v in m['backends'].items() if k in m['successful_builds']};units=list(original['backends']['phi']['objects']);m['notes']+=['Function diagnostics keep every non-deflate object phi. Exact longest_match function region (comment through .size) swapped between re-emitted unchanged assemblies; no instruction editing or compiler identity claim.']
for label,(baseorigin,replacement) in selections.items():
 d=w/label;d.mkdir();start,end,old=maps[baseorigin]['longest_match'];new=maps[replacement]['longest_match'][2];text=texts[baseorigin][:start]+new+texts[baseorigin][end:];mixed=bodies(text)
 for name,(_,_,body) in mixed.items():assert body==maps[replacement if name=='longest_match' else baseorigin][name][2]
 asm=d/'deflate.s';asm.write_text(text);sync(asm)
 entry={'status':'building','kind':'diagnostic mixed function assembly','compiler_identity':None,'objects':{},'function_body_origins':{name:{'origin':replacement if name=='longest_match' else baseorigin,'sha256':hashlib.sha256(body.encode()).hexdigest()} for name,(_,_,body) in mixed.items()},'assembly_sha256':sha(asm)};m['backends'][label]=entry
 for unit in units:
  dest=d/(unit+'.o')
  if unit=='deflate':
   command=['gcc','-c',guest(asm),'-o',guest(dest)];docker(command);entry['assembly_command']=['docker','exec','lcb-parity-linux',*command];wanted=barrier(dest);origin='mixed functions; see function_body_origins'
  else:
   origin='phi';obj=src/origin/(unit+'.o');wanted=original['backends'][origin]['objects'][unit]['sha256'];assert sha(obj)==wanted;shutil.copy2(obj,dest);sync(dest)
  entry['objects'][unit]={'sha256':wanted,'origin_label':origin}
 sync(w/'caller.o');link=['gcc',guest(w/'caller.o'),*[guest(d/(u+'.o')) for u in units],'-o',guest(d/'driver')];docker(link);entry.update(status='built',executable_sha256=barrier(d/'driver'),link_command=['docker','exec','lcb-parity-linux',*link])
(w/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');sync(w/'manifest.json')
def bindings(manifest,work):
 e={}
 def add(p,h):e[str(p)]=h
 for k in ['source_hashes','configuration_hashes']:
  for n,h in manifest[k].items():add(work/'source'/n,h)
 for n,h in manifest['ir_hashes'].items():add(work/'ir'/(n+'.ssa'),h)
 for n,h in manifest['payload_hashes'].items():add(work/n,h)
 for n,k in [('caller.c','caller_sha256'),('caller.o','caller_object_sha256'),('probe.py','probe_sha256'),('negative-driver','negative_driver_sha256'),('binding-report.json','binding_report_sha256')]:add(work/n,manifest[k])
 for l,v in manifest['backends'].items():
  for n,o in v['objects'].items():add(work/l/(n+'.o'),o['sha256'])
  add(work/l/'driver',v['executable_sha256'])
  if v.get('compiler_sha256'):add(work/('compiler-'+l),v['compiler_sha256'])
  if l.startswith('qbe-'):
   add(work/(l+'-source')/'qbe',v['oracle_binary_sha256'])
   for n,h in v['source_files'].items():add(work/(l+'-source')/n,h)
 return e
expected=bindings(original,src)|bindings(m,w);expected[str(w/'prepare.py')]=m['adapter_sha256'];expected[str(src/'manifest.json')]=m['origin_manifest']['sha256'];expected[str(w/'manifest.json')]=sha(w/'manifest.json')
for label in ['phi','indexed']:expected[str(w/('verified-'+label+'-deflate.s'))]=m['assembly_origins'][label]['sha256']
for label in selections:expected[str(w/label/'deflate.s')]=m['backends'][label]['assembly_sha256']
(w/'bindings.json').write_text(json.dumps(expected,indent=2)+'\n');sync(w/'bindings.json')
def validate(stage,reports):
 assert sha(root/'scripts/zlib_inprocess.py')==m['script_sha256']
 for p,h in expected.items():assert sha(p)==h,('host',p)
 actual=json.loads(docker(['python3','-c','import sys,json,hashlib;from pathlib import Path;print(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in json.loads(sys.argv[1])}))',json.dumps([guest(Path(p)) for p in expected])]))
 for p,h in expected.items():assert actual[guest(Path(p))]==h,('guest',p)
 rec={'stage':stage,'status':'passed','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'bound_files_checked_host_and_guest':len(expected),'bindings_sha256':sha(w/'bindings.json'),'reports':{n:barrier(w/n) for n in reports}}
 p=w/'provenance.json';records=json.loads(p.read_text()) if p.exists() else [];records.append(rec);p.write_text(json.dumps(records,indent=2)+'\n');sync(p)
validate('before_correctness',['manifest.json'])
output=docker(['python3',guest(w/'probe.py'),guest(w),'check']);(w/'correctness.log').write_text(output)
validate('after_correctness',['manifest.json','correctness.json']);c=json.loads((w/'correctness.json').read_text());assert c['status']=='passed';assert all(x['status']=='passed' and len(x['checks'])==15 for x in c['backends'].values());assert not (w/'timing.json').exists();print('8 labels x15 correctness profiles passed; bound files',len(expected))
