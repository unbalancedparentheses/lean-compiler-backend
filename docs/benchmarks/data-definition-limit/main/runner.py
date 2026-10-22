#!/usr/bin/env python3
"""Fresh actual-main data-limit replay. Does not build or modify compiler sources."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,shutil,subprocess,sys,time
ROOT=Path('/Users/unbalancedparen/projects/lean-compiler-backend')
PRIVATE=Path('/tmp/lcb-data-definition-limit')
BEFORE_ID='210a515a50b54c9b78a824349deea8e4a78cc0d0b26f9bde5f61a886f8e6b2b5'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,x):Path(p).write_text(json.dumps(x,indent=2))
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--compiler',type=Path,required=True);parser.add_argument('--identity',required=True);parser.add_argument('--work',type=Path,required=True);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--container',default='lcb-parity-linux');a=parser.parse_args()
 root=a.root.resolve();base=root/'.build/linux-arm64';work=a.work.resolve();compiler=a.compiler.resolve();before=root/'.build/lcb-arm-scaled-main'
 assert work.is_relative_to(base) and work!=base and not work.exists(),'fresh named mounted work directory required'
 source=json.loads((root/'compiler-build.json').read_text());assert source['identity']==a.identity
 for name,digest in source['files'].items():assert sha(root/name)==digest,name
 assert subprocess.check_output([compiler,'--build-identity'],text=True).strip()==a.identity
 assert subprocess.check_output([before,'--build-identity'],text=True).strip()==BEFORE_ID
 helper=root/'scripts/data_definition_limit.py';assert sha(helper)==sha(PRIVATE/'scripts/data_definition_limit.py'),'integrated helper differs from qualified private helper'
 work.mkdir();frozen=work/'frozen';frozen.mkdir();scripts=frozen/'scripts';scripts.mkdir()
 hooks=['scripts/check.sh','scripts/linux_arm64.py','scripts/linux_targets.py','scripts/macos_x86.py','scripts/emission_only.py']
 bound=[compiler,before,Path(__file__),root/'compiler-build.json',root/'Tests.lean',root/'LeanCompilerBackend/Verified/BuildIdentity.lean',root/'upstream-lock.json']+[root/n for n in source['files']]+[root/n for n in hooks]+[root/'scripts'/n for n in ['data_definition_limit.py','docker_sync.py','fuzz.py']]
 qbe_host=root/'.build/syntax-main-review/qbe-snapshot';bound.append(qbe_host)
 catalog=base/'frontend-data-count-probe-v2';catalog_files=[catalog/n for n in ['catalog-4095.c','catalog-4095.ssa','caller-4095.c']]
 retained=json.loads((PRIVATE/'.build/data-limit/publication/raw-artifact-bindings.json').read_text())
 for p in catalog_files:assert sha(p)==retained[str(p)],p
 bound+=catalog_files+[PRIVATE/'.build/data-limit/publication/raw-artifact-bindings.json',PRIVATE/'.build/data-limit/discovery/bindings.json']
 # Record the unchanged cproc producer's binary without rerunning its frontend.
 frontend=base/'combined-scaled-v2-cproc-aarch64-linux/cproc-source/cproc-qbe';bound.append(frontend)
 discovery=json.loads((PRIVATE/'.build/data-limit/discovery/bindings.json').read_text());assert sha(frontend)==discovery[str(frontend)]
 pre={str(p):sha(p) for p in bound};write(work/'pre-bindings.json',pre)
 for n in ['data_definition_limit.py','docker_sync.py','fuzz.py']:shutil.copy2(root/'scripts'/n,scripts/n)
 for label,p in [('compiler',compiler),('before',before),('qbe-host',qbe_host)]:shutil.copy2(p,frozen/label);assert sha(frozen/label)==sha(p)
 for name in source['files']:
  out=frozen/'compiler-source'/name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/name,out)
 shutil.copy2(root/'compiler-build.json',frozen/'compiler-build.json');shutil.copy2(root/'upstream-lock.json',frozen/'upstream-lock.json');shutil.copy2(Path(__file__),frozen/'runner.py')
 for p in catalog_files:shutil.copy2(p,frozen/p.name)
 for name in hooks:
  out=frozen/name;out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/name,out)
 sys.path.insert(0,str(scripts));import data_definition_limit as h;import docker_sync
 def guest(cmd):return subprocess.run(['docker','exec',a.container,*map(str,cmd)],capture_output=True,text=True,timeout=180)
 pinned=json.loads((root/'upstream-lock.json').read_text())['vendored_files'];qbe_files={n.removeprefix('third_party/qbe/'):v for n,v in pinned.items() if n.startswith('third_party/qbe/') and Path(n).suffix in ['.c','.h']}
 def oracle_bindings():
  code='import pathlib,hashlib,json,sys;p=pathlib.Path("/tmp/qbe");names=json.loads(sys.argv[1]);r={n:hashlib.sha256((p/n).read_bytes()).hexdigest() for n in names};r["qbe"]=hashlib.sha256((p/"qbe").read_bytes()).hexdigest();print(json.dumps(r))'
  p=guest(['python3','-c',code,json.dumps(list(qbe_files))]);assert p.returncode==0,p.stderr;result=json.loads(p.stdout)
  for n,digest in qbe_files.items():assert result[n]==digest,('modified original QBE source',n)
  return result
 oracle_pre=oracle_bindings();write(work/'oracle-pre.json',oracle_pre)
 def wrapper(linux,runner):
  def run(cmd,inside=False):
   cmd=list(map(str,cmd));original=cmd[:]
   if inside and len(cmd)==1:cmd=runner+cmd
   if inside and linux:
    docker_sync.sources(cmd,base,a.container)
    for arg in cmd:
     if Path(arg).suffix=='.s' and Path(arg).exists():docker_sync.host_file(arg,base,a.container)
    cmd=['docker','exec',a.container,*[x.replace(str(base),'/work') for x in cmd]]
   p=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
   if inside and linux and p.returncode==0 and '-o' in original:
    path=Path(original[original.index('-o')+1]);digest=guest(['sha256sum',str(path).replace(str(base),'/work')]);assert digest.returncode==0;expected=digest.stdout.split()[0]
    for _ in range(100):
     if path.exists() and sha(path)==expected:break
     time.sleep(.05)
    else:raise AssertionError('guest/host output mismatch '+str(path))
   return p
  return run
 def barrier(directory):
  # Host-authored report bytes must also cross the mount before comparing trees.
  for p in directory.rglob('*.json'):docker_sync.host_file(p,base,a.container)
  host={str(p.relative_to(directory)):sha(p) for p in directory.rglob('*') if p.is_file()}
  p=guest(['python3','-c','import pathlib,hashlib,json,sys;p=pathlib.Path(sys.argv[1]);print(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob("*") if x.is_file()}))',str(directory).replace(str(base),'/work')]);assert p.returncode==0;assert host==json.loads(p.stdout);return host
 reports=[]
 for target,cc,runner in [('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu']),('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64'])]:
  linux=target.endswith('linux');directory=work/target;r=h.exercise(frozen/'compiler',directory,wrapper(linux,runner),cc,target,True,Path('/tmp/qbe/qbe') if linux else frozen/'qbe-host',frozen/'before');assert r['compiler_identity']==a.identity and r['checks_per_backend']==6145
  reports.append(dict(target=target,report=str(directory/'data-definition-limit/report.json')));write(work/'reports.json',reports)
  if linux:write(work/(target+'-guest-host.json'),barrier(directory))
  print(target,'passed',flush=True)
 # Missing-tool controls must not execute a compiler/linker/oracle callback.
 def no_tools(cmd,inside=False):
  assert not inside,cmd
  return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
 emission=[]
 for target in h.TARGETS:
  r=h.exercise(frozen/'compiler',work/'emission'/target,no_tools,Path('/nonexistent/cc'),target,False,Path('/nonexistent/qbe'));assert r['checks_per_backend']==0 and r['before_equivalence']=='skipped: no before snapshot';emission.append(target)
 write(work/'emission.json',emission)
 cli=subprocess.run([sys.executable,str(scripts/'data_definition_limit.py'),'--compiler',str(frozen/'compiler'),'--require-native'],capture_output=True,text=True,timeout=1200,env={**os.environ,'LCB_CC':'cc'});(work/'native-cli.json').write_text(cli.stdout);(work/'native-cli.stderr').write_text(cli.stderr);assert cli.returncode==0;assert json.loads(cli.stdout)['checks_per_backend']==6145
 # Retained unchanged frontend IR, newly emitted/linked and executed in all modes.
 directory=work/'catalog-arm';directory.mkdir();commands=[];run=wrapper(True,[])
 for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
  asm=directory/(label+'.s');exe=directory/label
  for cmd,inside in [([frozen/'compiler',frozen/'catalog-4095.ssa','--target','aarch64-linux',*flags,'-o',asm],False),(['gcc','-O2',frozen/'caller-4095.c',asm,'-o',exe],True),([exe],True)]:
   p=run(cmd,inside);commands.append(dict(command=list(map(str,cmd)),inside=inside,exit=p.returncode,stdout=p.stdout,stderr=p.stderr));assert p.returncode==0,commands[-1]
 write(directory/'report.json',dict(definitions=4096,strings_checked_per_mode=4095,compiler_identity=a.identity,source_sha256=sha(frozen/'catalog-4095.ssa'),caller_sha256=sha(frozen/'caller-4095.c'),commands=commands));write(work/'catalog-guest-host.json',barrier(directory))
 post={str(p):sha(p) for p in bound};assert post==pre;write(work/'post-bindings.json',post);oracle_post=oracle_bindings();assert oracle_post==oracle_pre;write(work/'oracle-post.json',oracle_post)
 write(work/'qualification.json',dict(status='passed',compiler_identity=a.identity,before_identity=BEFORE_ID,targets=5,lcb_object_checks=92175,qbe_object_checks=51210,negative_cases=65,wrong_last_mutations=5,catalog_string_checks=12285,emission_targets=5,native_cli='passed',post_validation='passed',limitations='Finite fixtures; Linux x86/RV execute through QEMU and Apple x86 through Rosetta. Original QBE admits 4097 while LCB intentionally refuses. Catalog frontend is not rerun. Timings are diagnostic only.'))
 write(work/'manifest.json',{str(p.relative_to(work)):sha(p) for p in work.rglob('*') if p.is_file() and p!=work/'manifest.json'});print('post-validation passed',flush=True)
if __name__=='__main__':main()
