from pathlib import Path
import argparse,subprocess,sys,hashlib,json,shutil,time
p=argparse.ArgumentParser();p.add_argument('--compiler',type=Path,required=True);p.add_argument('--identity',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path.cwd();base=root/'.build/linux-arm64';out=a.out.resolve();assert out.is_relative_to(base) and not out.exists();out.mkdir();snap=out/'snapshot';snap.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for n in ['aggregate_signature_aliases.py','docker_sync.py','fuzz.py']:shutil.copy2(root/'scripts'/n,snap/n)
shutil.copy2(a.compiler,snap/'lcb');compiler=snap/'lcb';before=root/'.build/lcb-elf-names-main';qhost=root/'.build/syntax-main-review/qbe-snapshot';shutil.copy2(qhost,snap/'qbe');qhost=snap/'qbe'
paths=[root/'scripts'/n for n in ['aggregate_signature_aliases.py','docker_sync.py','check.sh','linux_arm64.py','linux_targets.py','macos_x86.py','emission_only.py']]+[root/'LeanCompilerBackend'/(n+'.lean') for n in ['Aggregate','Semantics','Validate']]+[root/'Tests.lean',root/'compiler-build.json',Path(__file__).resolve(),before,root/'.build/syntax-main-review/qbe-snapshot']+list(snap.iterdir());bindings={str(p):sha(p) for p in paths};assert subprocess.check_output([compiler,'--build-identity'],text=True).strip()==a.identity
sys.path.insert(0,str(snap));import aggregate_signature_aliases as helper;import docker_sync
r=dict(status='running',identity=a.identity,bindings=bindings,matrices=[],emission=[])
def save():(out/'campaign.json').write_text(json.dumps(r,indent=2)+'\n')
def guest(cmd):return subprocess.run(['docker','exec','lcb-parity-linux',*map(str,cmd)],capture_output=True,text=True,check=True,timeout=180)
def gp(p):return '/work/'+str(Path(p).relative_to(base))
qhash=guest(['sha256sum','/tmp/qbe/qbe']).stdout.split()[0];r['qbe_guest_before']=qhash
try:
 for target,cc,runner in [('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
  work=out/target;linux=target.endswith('linux');r['current']=target;save()
  def run(cmd,inside=False):
   original=list(map(str,cmd));cmd=original[:]
   if inside and len(cmd)==1:cmd=runner+cmd
   if inside and linux:
    docker_sync.sources(cmd,base,'lcb-parity-linux')
    for path in cmd:
     if Path(path).suffix=='.s' and Path(path).exists():docker_sync.host_file(path,base,'lcb-parity-linux')
    cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
   result=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
   if inside and linux and result.returncode==0 and '-o' in original:
    path=Path(original[original.index('-o')+1]);want=guest(['sha256sum',gp(path)]).stdout.split()[0];deadline=time.monotonic()+60
    while not path.exists() or sha(path)!=want:
     assert time.monotonic()<deadline,path
     time.sleep(.05)
   return result
  report=helper.exercise(compiler,work,run,cc,target,True,Path('/tmp/qbe/qbe') if linux else qhost,before)
  assert report['compiler_identity']==a.identity and report['checks_per_backend']==896 and len(report['backends'])==4
  artifacts={str(p.relative_to(work)):sha(p) for p in work.rglob('*') if p.is_file()}
  if linux:
   code='import pathlib,hashlib,json,sys;p=pathlib.Path(sys.argv[1]);print(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob("*") if x.is_file()}))'
   expected=json.loads(guest(['python3','-c',code,gp(work)]).stdout);assert artifacts==expected
  r['matrices'].append(dict(target=target,artifacts=artifacts,guest_host=linux));save();print(target,'passed',flush=True)
  def emit(cmd,inside=False):
   assert not inside
   return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
  report=helper.exercise(compiler,out/'emission'/target,emit,['/missing/cc'],target,False,Path('/missing/qbe'),before);assert report['checks_per_backend']==0;r['emission'].append(target);save()
 cmd=[sys.executable,str(snap/'aggregate_signature_aliases.py'),'--compiler',str(compiler),'--qbe',str(qhost),'--require-native'];v=subprocess.run(cmd,capture_output=True,text=True,timeout=180);r['cli']=dict(command=cmd,exit=v.returncode,stdout=v.stdout,stderr=v.stderr);assert v.returncode==0
 assert all(sha(p)==want for p,want in bindings.items());r['qbe_guest_after']=guest(['sha256sum','/tmp/qbe/qbe']).stdout.split()[0];assert r['qbe_guest_after']==qhash
 r['artifacts']={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file() and p!=out/'campaign.json'};r['status']='passed'
except BaseException as error:r['error']=repr(error);r['status']='failed';raise
finally:save()
