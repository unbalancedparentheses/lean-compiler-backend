#!/usr/bin/env python3
"""Qualify an explicitly identified actual-main ELF section names, TLS and retention snapshot; never rebuild."""
import argparse,hashlib,json,shutil,subprocess,sys,time
from pathlib import Path
TARGETS=[('aarch64-macos',['cc'],[]),('x86_64-macos',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux',['gcc'],[]),('x86_64-linux',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]
BEFORE='5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repo',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--identity',required=True);p.add_argument('--before',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--container',default='lcb-parity-linux');p.add_argument('--qbe-guest',default='/tmp/qbe/qbe');a=p.parse_args()
 root=a.repo.resolve();base=root/'.build/linux-arm64';out=a.output.resolve();assert out.is_relative_to(base) and not out.exists(),'fresh mounted directory required';out.mkdir(parents=True);snap=out/'snapshots';snap.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 compiler=snap/'lcb';before=snap/'before';shutil.copy2(a.compiler,compiler);shutil.copy2(a.before,before)
 helpers=['elf_section_names.py','section_names.py','custom_tls_sections.py','elf_retain.py','data_relocations.py','fuzz.py','docker_sync.py']
 for name in helpers:shutil.copy2(root/'scripts'/name,snap/name)
 source_paths=[a.compiler.resolve(),a.before.resolve(),root/'compiler-build.json']+[root/'scripts'/n for n in helpers+['check.sh','linux_arm64.py','linux_targets.py','macos_x86.py','emission_only.py']]+[root/'LeanCompilerBackend'/(n+'.lean') for n in ['Section','Assembly','Validate','IR','AArch64','AMD64','RV64']]+[root/'Tests.lean']
 source_paths += [x for x in (root/'third_party/qbe').rglob('*') if x.is_file() and x.suffix in ['.c','.h']]
 original={str(x):sha(x) for x in source_paths};frozen={str(x):sha(x) for x in snap.iterdir() if x.is_file()};frozen[str(Path(__file__).resolve())]=sha(Path(__file__))
 identity=subprocess.run([str(compiler),'--build-identity'],capture_output=True,text=True,check=True).stdout.strip();assert identity==a.identity,(identity,a.identity)
 bid=subprocess.run([str(before),'--build-identity'],capture_output=True,text=True,check=True).stdout.strip();assert bid==BEFORE,(bid,BEFORE)
 def guest(args):return subprocess.run(['docker','exec',a.container,*map(str,args)],capture_output=True,text=True,timeout=180,check=True)
 qbe_before=guest(['sha256sum',a.qbe_guest]).stdout.split()[0]
 report=dict(status='running',compiler_identity=identity,before_identity=bid,original_bindings=original,snapshot_bindings=frozen,qbe_before_sha256=qbe_before,matrices=[],emission=[],cli=[],combined_context=[])
 def save():(out/'campaign.json').write_text(json.dumps(report,indent=2)+'\n')
 save();sys.path.insert(0,str(snap));import custom_tls_sections as tls;import elf_retain as retain;import elf_section_names as names;import docker_sync
 def guest_path(path):return '/work/'+str(Path(path).relative_to(base))
 def sync_output(path):
  expected=guest(['sha256sum',guest_path(path)]).stdout.split()[0];deadline=time.monotonic()+60
  while not path.is_file() or sha(path)!=expected:
   assert time.monotonic()<deadline,('guest output not synchronized',path)
   time.sleep(.05)
 def tree_barrier(work):
  code='import pathlib,hashlib,json,sys;p=pathlib.Path(sys.argv[1]);print(json.dumps({str(x.relative_to(p)):hashlib.sha256(x.read_bytes()).hexdigest() for x in p.rglob("*") if x.is_file()}))';deadline=time.monotonic()+60
  while True:
   g=json.loads(guest(['python3','-c',code,guest_path(work)]).stdout);h={str(x.relative_to(work)):sha(x) for x in work.rglob('*') if x.is_file()}
   if h==g:return h
   assert time.monotonic()<deadline,('host/guest tree mismatch',work,set(h)^set(g))
   time.sleep(.05)
 try:
  for name,module in [('tls',tls),('retain',retain),('names',names)]:
   for target,cc,runner in TARGETS:
    work=out/name/target;report['current']={'suite':name,'target':target};save();linux=target.endswith('linux')
    def run(cmd,inside=False):
     original_cmd=list(map(str,cmd));cmd=original_cmd[:]
     if inside and cmd[0].startswith(str(work)+'/'):cmd=runner+cmd
     if inside and linux:
      docker_sync.sources(cmd,base,a.container)
      for path in cmd:
       if Path(path).suffix=='.s' and Path(path).exists():docker_sync.host_file(path,base,a.container)
      cmd=['docker','exec',a.container,*[x.replace(str(base),'/work') for x in cmd]]
     result=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
     if inside and linux and result.returncode==0 and '-o' in original_cmd:
      path=Path(original_cmd[original_cmd.index('-o')+1]);assert path.is_relative_to(base);sync_output(path)
     return result
    r=module.exercise(compiler,work,run,cc,target,True,Path(a.qbe_guest) if linux else None,None if name=='retain' else before)
    assert r['compiler_identity']==identity and r['helper_sha256']==sha(snap/{'tls':'custom_tls_sections.py','retain':'elf_retain.py','names':'elf_section_names.py'}[name])
    if name=='tls':assert r['ordinary_equivalence']=='passed' and r['executed_round_groups']==(2048 if linux else 0) and r['negative_cases']==(24 if linux else 18)
    else:assert r['executed_modes']==(4 if linux else 0)
    if linux:assert r['qbe_sha256']==qbe_before
    artifacts=tree_barrier(work) if linux else {str(x.relative_to(work)):sha(x) for x in work.rglob('*') if x.is_file()}
    report['matrices'].append(dict(suite=name,target=target,work=str(work),artifacts=artifacts,guest_host_barrier=linux,execution='native Linux ARM VM' if target=='aarch64-linux' else ('QEMU user-mode' if linux else 'emission/refusal/equivalence only')));save()
   for target,_,_ in TARGETS:
    work=out/'emission-only'/name/target
    def emit_run(cmd,inside=False):
     assert not inside,'emission-only attempted external execution'
     return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    r=module.exercise(compiler,work,emit_run,'/missing/cc',target,False,Path('/missing/qbe'),None if name=='retain' else before)
    assert r['qbe_sha256'] is None and (r['executed_round_groups'] if name=='tls' else r['executed_modes'])==0
    report['emission'].append(dict(suite=name,target=target,work=str(work)));save()
   script=snap/{'tls':'custom_tls_sections.py','retain':'elf_retain.py','names':'elf_section_names.py'}[name];cmd=[sys.executable,str(script),'--compiler',str(compiler),*(['--before',str(before)] if name!='retain' else []),'--work',str(out/'native-cli'/name),'--require-native'];r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);assert r.returncode==0,(cmd,r.stdout,r.stderr);report['cli'].append(dict(suite=name,command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));save()
  # R admission in ordinary ELF sections must not expand the independent TLS whitelist.
  for target,_,_ in TARGETS:
   if not target.endswith('linux'):continue
   work=out/'context-composition'/target;work.mkdir(parents=True);source=work/'tls-retain-invalid.ssa';source.write_text('section ".bad_tls" "awTR" thread data $x = { l 1 }\n')
   for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
    cmd=[str(compiler),str(source),'--target',target,*flags,'-o',str(work/(mode+'.s'))];r=subprocess.run(cmd,capture_output=True,text=True,timeout=120);assert r.returncode!=0 and 'TLS flags' in r.stderr,(cmd,r.stderr);report['combined_context'].append(dict(command=cmd,exit=r.returncode,stderr=r.stderr))
  assert all(sha(path)==digest for path,digest in original.items()),'original source/helper/core/hook binding changed'
  assert all(sha(path)==digest for path,digest in frozen.items()),'snapshot or runner changed'
  report['qbe_after_sha256']=guest(['sha256sum',a.qbe_guest]).stdout.split()[0];assert report['qbe_after_sha256']==qbe_before
  report['artifacts']={str(path.relative_to(out)):sha(path) for path in out.rglob('*') if path.is_file() and path!=out/'campaign.json'}
  report['status']='passed'
 except BaseException as error:report['status']='failed';report['error']=repr(error);raise
 finally:save()
 print(out/'campaign.json')
if __name__=='__main__':main()
