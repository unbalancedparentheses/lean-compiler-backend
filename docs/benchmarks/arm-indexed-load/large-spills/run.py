from pathlib import Path
import subprocess,json,hashlib,sys,re,time,shutil
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');w=Path(__file__).resolve().parent;base=root/'.build/linux-arm64';sys.path.insert(0,str(root/'scripts'));import docker_sync
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
compilers={'before':root/'.build/lcb-amd-leaf','after':root/'.build/lcb-arm-indexed'};qbe=root/'.build/syntax-main-review/qbe-snapshot';report={'source_sha256':sha(w/'input.ssa'),'caller_sha256':sha(w/'caller.c'),'compilers':{},'qbe_binary_sha256':sha(qbe),'runs':[],'checks_per_execution':28,'execution_modes':{'aarch64-macos':'native Apple ARM','aarch64-linux':'native ARM Linux Docker VM'}}
def run(cmd,inside=False):
 cmd=list(map(str,cmd));start=time.monotonic()
 if inside:
  for x in cmd:
   p=Path(x)
   if p.is_file() and p.is_relative_to(base):docker_sync.host_file(p,base,'lcb-parity-linux')
  cmd=['docker','exec','lcb-parity-linux',*[('/work/'+str(Path(x).relative_to(base))) if x.startswith(str(base)+'/') else x for x in cmd]]
 r=subprocess.run(cmd,text=True,capture_output=True,timeout=180);entry={'command':cmd,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr,'seconds':time.monotonic()-start};report['runs'].append(entry);(w/'report.json').write_text(json.dumps(report,indent=2)+'\n');return r
for label,p in compilers.items():
 r=run([p,'--build-identity']);assert r.returncode==0;report['compilers'][label]={'identity':r.stdout.strip(),'sha256':sha(p)}
for target in ['aarch64-macos','aarch64-linux']:
 inside=target.endswith('linux');cc='gcc' if inside else 'cc'
 for label,p in compilers.items():
  for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
   stem=f'{target}-{label}-{mode}';asm=w/(stem+'.s');exe=w/stem
   r=run([p,w/'input.ssa','--target',target,*flags,'-o',asm]);assert r.returncode==0
   text=asm.read_text()
   if label=='after' and mode!='baseline':
    pat=r'add x15, sp, #8, lsl #12\n\tadd x15, x15, #(\d+)\n\tldr x9, \[x15\]\n\tadd x15, sp, #8, lsl #12\n\tadd x15, x15, #(\d+)\n\tldr x10, \[x15\]\n\tldr x9, \[x9, x10\]\n\tadd x15, sp, #8, lsl #12\n\tadd x15, x15, #(\d+)\n\tstr x9, \[x15\]'
    m=re.search(pat,text);assert m,stem
    offsets=[32768+int(x) for x in m.groups()];assert all(x>32760 for x in offsets);report.setdefault('structural',{})[stem]={'offsets_left_right_result':offsets,'assembly_sha256':sha(asm),'sequence':m.group()}
   r=run([cc,'-O2',w/'caller.c',asm,'-o',exe],inside);assert r.returncode==0
   r=run([exe],inside);assert r.returncode==0 and r.stdout=='28 large spill checks passed\n'
 for label,p in [('original-qbe',qbe)]:
  asm=w/(target+'-qbe.s');exe=w/(target+'-qbe');r=run([p,'-t','arm64' if inside else 'arm64_apple','-o',asm,w/'input.ssa']);assert r.returncode==0
  r=run([cc,'-O2',w/'caller.c',asm,'-o',exe],inside);assert r.returncode==0
  r=run([exe],inside);assert r.returncode==0 and r.stdout=='28 large spill checks passed\n'
report['status']='passed';(w/'report.json').write_text(json.dumps(report,indent=2)+'\n');print('all14 executions passed')
