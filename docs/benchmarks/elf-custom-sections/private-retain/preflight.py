from pathlib import Path
import sys,subprocess,json,hashlib
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(root/'scripts'));import docker_sync
base=root/'.build/linux-arm64'
IR='''section ".lcb.keep_rw" "awR" export data $keep_rw = { l 37 }
section ".lcb.keep_ro" "aR" export data $keep_ro = { l 83 }
section ".lcb.drop_data" "aw" export data $drop_data = { l 99 }
section ".lcb.ref_data" "aw" export data $ref_data = { l 19 }
section ".lcb.keep_code" "axR" export function l $keep_code() {
@s
 ret 71
}
section ".lcb.drop_code" "ax" export function l $drop_code() {
@s
 ret 101
}
section ".lcb.ref_code" "ax" export function l $anchor() {
@s
 ret 17
}
'''
C='''#include <stdint.h>
#include <stdlib.h>
extern uint64_t anchor(void),ref_data;
int main(int argc,char**argv){if(argc!=4||anchor()!=17||ref_data!=19)return 1;
 uintptr_t base=(uintptr_t)&anchor;
 volatile uint64_t *a=(volatile uint64_t*)(base+(uintptr_t)strtoll(argv[1],0,10));
 volatile uint64_t *b=(volatile uint64_t*)(base+(uintptr_t)strtoll(argv[2],0,10));
 uint64_t(*f)(void)=(uint64_t(*)(void))(base+(uintptr_t)strtoll(argv[3],0,10));
 return *a!=37||*b!=83||f()!=71;}
'''
def symbols(text):
 out={}
 for line in text.splitlines():
  parts=line.split()
  if len(parts)==3:
   try:out[parts[2]]=int(parts[0],16)
   except ValueError:pass
 return out
for target,qt,cc,runner in [('aarch64-linux','arm64','gcc',[]),('x86_64-linux','amd64_sysv','x86_64-linux-gnu-gcc',['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux','rv64','riscv64-linux-gnu-gcc',['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
 work=base/('retain-preflight-v2-'+target);work.mkdir(exist_ok=False);calls=[]
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for p in cmd:
    if Path(p).suffix=='.s' and Path(p).exists():docker_sync.host_file(p,base,'lcb-parity-linux')
   cmd=['docker','exec','lcb-parity-linux',*[x.replace(str(base),'/work') for x in cmd]]
  r=subprocess.run(cmd,capture_output=True,text=True,timeout=120);calls.append(dict(command=cmd,exit=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,calls[-1];return r.stdout
 src=work/'input.ssa';src.write_text(IR);caller=work/'caller.c';caller.write_text(C);asm=work/'qbe.s';obj=work/'qbe.o';exe=work/'qbe'
 run(['/tmp/qbe/qbe','-t',qt,'-o',asm,src],True);run([cc,'-c',asm,'-o',obj],True);sec=run(['readelf','-SW',obj],True)
 for name in ['.lcb.keep_rw','.lcb.keep_ro','.lcb.keep_code']:
  line=next(x for x in sec.splitlines() if name in x);assert 'R' in line.split()[-4],line
 run([cc,caller,obj,'-Wl,--gc-sections','-o',exe],True);syms=symbols(run(['nm','-n','--defined-only',exe],True));assert all(x in syms for x in ['keep_rw','keep_ro','keep_code','anchor','ref_data']);assert all(x not in syms for x in ['drop_data','drop_code'])
 args=[str(syms[x]-syms['anchor']) for x in ['keep_rw','keep_ro','keep_code']];run([*runner,exe,*args],True)
 bad=work/'no-retain.ssa';bad.write_text(IR.replace('awR','aw').replace('aR','a').replace('axR','ax'));ba=work/'no-retain.s';be=work/'no-retain';run(['/tmp/qbe/qbe','-t',qt,'-o',ba,bad],True);run([cc,caller,ba,'-Wl,--gc-sections','-o',be],True);bs=symbols(run(['nm','-n','--defined-only',be],True));assert all(x not in bs for x in ['keep_rw','keep_ro','keep_code'])
 qhash=run(['sha256sum','/tmp/qbe/qbe'],True).split()[0]
 report=dict(target=target,status='passed',execution='native ARM in Linux VM' if not runner else 'QEMU user-mode',source_sha256=hashlib.sha256(IR.encode()).hexdigest(),caller_sha256=hashlib.sha256(C.encode()).hexdigest(),qbe_sha256=qhash,commands=calls,note='Default PIE executable with --gc-sections; only anchor/ref_data referenced by C. Postlink nm offsets passed as runtime integers do not create linker roots. RemovingR drops all three retained-only symbols.')
 (work/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(target,'originalQBE retention and noR control passed',flush=True)
