import hashlib,json,shutil,subprocess,sys
from pathlib import Path
sys.path.insert(0,'scripts')
from docker_sync import sources
root=Path.cwd();mount=root/'.build/linux-arm64';out=mount/'chacha-double-round-review';out.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
src=root/'third_party/qbe/test/_chacha20.ssa';assert sha(src)==json.load(open('upstream-lock.json'))['vendored_files']['third_party/qbe/test/_chacha20.ssa']
compiler=out/'lcb';shutil.copy2(root/'.build/lcb-arm-leaf',compiler)
qbe=root/'.build/linux-arm64/libyaml-benchmark-aarch64/qbe-host/qbe'
shutil.copy2(root/'.build/chacha-leaf-caller.c',out/'caller.c');shutil.copy2(src,out/'input.ssa')
report={'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(out/'caller.c'),'qbe_sha256':sha(qbe),'status':'running','targets':{}}
def run(cmd,guest=False,check=True):
 cmd=list(map(str,cmd))
 if guest:
  sources(cmd,mount,'lcb-parity-linux');cmd=['docker','exec','lcb-parity-linux']+[x.replace(str(mount),'/work') for x in cmd]
 p=subprocess.run(cmd,capture_output=True,text=True,timeout=180)
 if check:assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr)
 return p
for target in ['aarch64-macos','aarch64-linux']:
 guest=target.endswith('linux');d=out/target;d.mkdir(exist_ok=True);records={};report['targets'][target]=records
 for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize']),('qbe',[])]:
  asm=d/(mode+'.s');exe=d/mode
  run([qbe,'-t','arm64' if guest else 'arm64_apple','-o',asm,out/'input.ssa'] if mode=='qbe' else [compiler,out/'input.ssa','--target',target,*flags,'-o',asm])
  run(['cc','-O2',out/'caller.c',asm,'-o',exe],guest);p=run([exe],guest);assert p.stdout=='1536 independent round/alias/canary cases passed\n'
  records[mode]={'status':'passed','checks':1536,'assembly_sha256':sha(asm),'executable_sha256':run(['sha256sum' if guest else 'shasum',*([] if guest else ['-a','256']),exe],guest).stdout.split()[0]}
 bad=out/'wrong-add.ssa';s=src.read_text();needle='%t0 =w add %t0, %t4';assert needle in s;bad.write_text(s.replace(needle,'%t0 =w sub %t0, %t4',1))
 asm=d/'wrong-add.s';exe=d/'wrong-add';run([compiler,bad,'--target',target,'--optimize','-o',asm]);run(['cc','-O2',out/'caller.c',asm,'-o',exe],guest);p=run([exe],guest,False);assert p.returncode==1
 records['wrong_add']={'exit':1,'status':'detected'}
assert sha(compiler)==report['compiler_sha256'] and sha(src)==report['source_sha256'] and sha(qbe)==report['qbe_sha256']
report['status']='passed';(out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
