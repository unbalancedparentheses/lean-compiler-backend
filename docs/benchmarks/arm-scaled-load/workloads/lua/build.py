from pathlib import Path
import subprocess,hashlib,json,shutil,sys,re,time
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';old=base/'lua-mixed-review';out=base/'arm-scaled-main-lua-review';out.mkdir(exist_ok=False);sys.path.insert(0,str(root/'scripts'));from docker_sync import host_file
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();guest=lambda p:str(p).replace(str(base),'/work')
def run(cmd,inside=False):
 c=list(map(str,cmd));p=subprocess.run(['docker','exec','lcb-parity-linux',*c] if inside else c,capture_output=True,text=True,timeout=300);assert p.returncode==0,(c,p.returncode,p.stderr);
 if inside and '-o' in c:
  g=c[c.index('-o')+1];f=base/g.removeprefix('/work/');h=subprocess.check_output(['docker','exec','lcb-parity-linux','sha256sum',g],text=True).split()[0]
  for _ in range(100):
   if f.exists() and sha(f)==h:break
   time.sleep(.05)
  else:raise AssertionError(('guest output barrier',f))
 return p.stdout
r=json.loads((old/'report.json').read_text());bound={}
def bind(p,h=None):
 h=h or sha(p);assert sha(p)==h,p;bound[str(p)]=h
for name,h in r['source_hashes'].items():bind(old/'source'/name,h)
for name,h in r['test_hashes'].items():bind(old/'tests-original'/name,h)
for group in ['probe.lua','report.json','qualification.json','final-bindings.json']:bind(old/group)
shutil.copytree(old/'tests-original',out/'tests-original');shutil.copy2(old/'probe.lua',out/'probe.lua');(out/'ir').mkdir();report={'scope':r['scope'],'source_commit':r['source_commit'],'base_qualification_sha256':sha(old/'qualification.json'),'excluded_frontend_units':r['excluded_frontend_units'],'source_hashes':r['source_hashes'],'test_hashes':r['test_hashes'],'labels':{},'bound_original_inputs':bound,'units':r['units']}
for unit in r['units']:
 if unit in r['excluded_frontend_units']:bind(old/'gcc-O2'/(unit+'.o'),r['backends']['gcc-O2']['objects'][unit])
 else:bind(old/'ir'/(unit+'.ssa'),r['frontend'][unit]['ir_sha256']);shutil.copy2(old/'ir'/(unit+'.ssa'),out/'ir'/(unit+'.ssa'))
for label in ['gcc-O0','gcc-O2','qbe-original','qbe-corrected']:
 exe=old/label/'lua';bind(exe,r['backends'][label]['executable_sha256']);case=out/label;case.mkdir();shutil.copy2(exe,case/'lua');report['labels'][label]={'reused_reference':True,'executable_sha256':sha(exe),'oracle_build':r.get('oracle_builds',{}).get(label)}
for label,path in [('before',root/'.build/lcb-retained-tls-main'),('after',root/'.build/lcb-arm-scaled-main')]:
 bind(path);compiler=out/('compiler-'+label);shutil.copy2(path,compiler);case=out/label;case.mkdir();entry={'reused_reference':False,'compiler_identity':run([compiler,'--build-identity']).strip(),'compiler_sha256':sha(compiler),'objects':{},'text_bytes':0};report['labels'][label]=entry;objects=[]
 for unit in r['units']:
  obj=case/(unit+'.o')
  if unit in r['excluded_frontend_units']:shutil.copy2(old/'gcc-O2'/(unit+'.o'),obj);host_file(obj,base,'lcb-parity-linux');entry['objects'][unit]={'gcc_shared':True,'object_sha256':sha(obj)}
  else:
   ir=out/'ir'/(unit+'.ssa');asm=case/(unit+'.s');run([compiler,ir,'--target','aarch64-linux','--optimize','-o',asm]);host_file(asm,base,'lcb-parity-linux');run(['gcc','-c',guest(asm),'-o',guest(obj)],True);sizes=run(['size','-A',guest(obj)],True);text=int(re.search(r'^\.text\s+(\d+)',sizes,re.M)[1]);entry['text_bytes']+=text;entry['objects'][unit]={'gcc_shared':False,'object_sha256':sha(obj),'assembly_sha256':sha(asm),'ir_sha256':sha(ir),'text_bytes':text}
  objects.append(obj)
 run(['gcc',*map(guest,objects),'-lm','-ldl','-o',guest(case/'lua')],True);entry['executable_sha256']=sha(case/'lua');print(label,entry['text_bytes'],flush=True)
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
for p,h in bound.items():assert sha(p)==h,p
for unit in r['excluded_frontend_units']:assert report['labels']['before']['objects'][unit]['object_sha256']==report['labels']['after']['objects'][unit]['object_sha256']
report['build_postvalidation']='passed';(out/'report.json').write_text(json.dumps(report,indent=2)+'\n');shutil.copy2(__file__,out/'build.py')
