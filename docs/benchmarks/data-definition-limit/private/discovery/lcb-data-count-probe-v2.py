from pathlib import Path
import subprocess,json,hashlib,re,sys,time
sys.path.insert(0,"/Users/unbalancedparen/projects/lean-compiler-backend/scripts")
import docker_sync
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';w=base/'frontend-data-count-probe-v2';w.mkdir(exist_ok=True);frontend=base/'combined-scaled-v2-cproc-aarch64-linux/cproc-source/cproc-qbe';compiler=root/'.build/lcb-arm-scaled-main';qbe=root/'.build/syntax-main-review/qbe-snapshot'
def run(cmd):
 p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);return dict(command=list(map(str,cmd)),exit=p.returncode,stdout=p.stdout,stderr=p.stderr)
def guest(cmd):
 docker_sync.sources(list(map(str,cmd)),base,'lcb-parity-linux')
 for x in cmd:
  if str(x).endswith('.s') and Path(x).exists(): docker_sync.host_file(x,base,'lcb-parity-linux')
 return run(['docker','exec','lcb-parity-linux',*[str(x).replace(str(base),'/work') for x in cmd]])
def barrier(path):
 expected=run(['docker','exec','lcb-parity-linux','sha256sum',str(path).replace(str(base),'/work')])['stdout'].split()[0]
 for _ in range(100):
  if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==expected:return
  time.sleep(.05)
 raise AssertionError('guest-host digest mismatch '+str(path))
rows=[]
for n in [1023,1024,2047,4095,4096]:
 src=w/f'catalog-{n}.c';src.write_text('const char * const messages[] = {\n'+',\n'.join('"message-%04d"'%i for i in range(n))+'\n};\nconst char *lookup(unsigned long i){return messages[i];}\n');ir=src.with_suffix('.ssa');fr=guest([frontend,'-t','aarch64','-o',ir,src]);assert fr['exit']==0,fr;barrier(ir)
 c=w/f'caller-{n}.c';c.write_text('#include <stdio.h>\n#include <string.h>\nextern const char*lookup(unsigned long);int main(void){char want[32];for(unsigned i=0;i<'+str(n)+';i++){snprintf(want,sizeof want,"message-%04u",i);if(strcmp(lookup(i),want))return 1;}return 0;}\n')
 for target,qt,cc,runner in [('aarch64-macos','arm64_apple',['cc'],[]),('x86_64-macos','amd64_apple',['cc','-arch','x86_64'],['arch','-x86_64']),('aarch64-linux','arm64',['gcc'],[]),('x86_64-linux','amd64_sysv',['x86_64-linux-gnu-gcc'],['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux','rv64',['riscv64-linux-gnu-gcc'],['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
  native=guest if target.endswith('linux') else run;r=dict(strings=n,data_definitions=len(re.findall(r'\bdata \$',ir.read_text())),target=target,ir_bytes=ir.stat().st_size,frontend=fr)
  asm=w/f'{n}-{target}.s';exe=w/f'{n}-{target}';r['lcb']=run([compiler,ir,'--target',target,'-o',w/f'{n}-{target}-lcb.s']);r['qbe']=run([qbe,'-t',qt,'-o',asm,ir]);assert r['qbe']['exit']==0,r
  r['link']=native([*cc,'-O2',c,asm,'-o',exe]);assert r['link']['exit']==0,r;r['execute']=native([*runner,exe]);assert r['execute']['exit']==0,r
  # Same source compiled by the independent platform C compiler.
  exe=w/f'{n}-{target}-c';r['c_build']=native([*cc,'-O2',c,src,'-o',exe]);assert r['c_build']['exit']==0,r;r['c_execute']=native([*runner,exe]);assert r['c_execute']['exit']==0,r
  rows.append(r)
  (w/'report.json').write_text(json.dumps(rows,indent=2))
  print(n,target,r['lcb']['exit'],flush=True)
(w/'report.json').write_text(json.dumps(rows,indent=2));(w/'bindings.json').write_text(json.dumps({str(x):hashlib.sha256(x.read_bytes()).hexdigest() for x in [compiler,qbe,frontend,Path(__file__)]},indent=2));print([(r['data_definitions'],r['target'],r['lcb']['exit'],r['execute']['exit']) for r in rows])
