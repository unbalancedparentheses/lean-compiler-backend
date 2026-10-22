#!/usr/bin/env python3
"""Exact aggregate declaration aliases, including nested names; no general ABI equivalence."""
from pathlib import Path
import hashlib,json
SHAPES=[('integer','{ l 2 }',16),('floating','{ d 2 }',16),('mixed','{ d, l }',16),('hidden','{ l 4 }',32),('union','{ { l 2 } { d 2 } }',16),('opaque','align 8 { 24 }',24),('nested','{ :innerA 2 }',16)]
def fixtures():
 ir=['type :innerA = { l }','type :innerB = { l }'];c=['#include <stdint.h>','#include <string.h>'];checks=[]
 for name,shape,size in SHAPES:
  ir += [f'type :{name}A = {shape}',f'type :{name}B = {shape.replace(":innerA",":innerB")}']
 for name,shape,size in SHAPES:
  ir += [f'''function :{name}A $echo_{name}(:{name}A %p, w %depth, ...) {{
@s
 %done =w ceqw %depth, 0
 jnz %done, @end, @recur
@recur
 %n =w sub %depth, 1
 %q =:{name}B call $echo_{name}(:{name}B %p, w %n, ..., l 91)
 ret %q
@end
 ret %p
}}''']
  for indirect in [False,True]:
   label=name+('_indirect' if indirect else '_direct');target='%fn' if indirect else '$echo_'+name
   lines=[f'export function l $probe_{label}(l %p) {{','@s']
   if indirect:lines += [f' %fn =l copy $echo_{name}']
   lines += [f' %r =:{name}B call {target}(:{name}B %p, w 2, ..., l 91)']
   for i in range(size):
    lines += [f' %p{i} =l add %r, {i}',f' %b{i} =l loadub %p{i}',f' %h{i} =l add '+('0' if i==0 else f'%h{i-1}')+f', %b{i}']
   lines += [f' ret %h{size-1}','}'];ir += ['\n'.join(lines)]
   c += [f'extern uint64_t probe_{label}(void*);'];checks += [f'{{uint64_t want=0;for(unsigned i=0;i<{size};i++)want+=buf[i];if(probe_{label}(buf)!=want)return 1;}}']
 c += ['int main(void){_Alignas(16) unsigned char buf[32];uint64_t seed=0x123456789abcdefULL;for(unsigned n=0;n<64;n++){for(unsigned i=0;i<32;i++){seed=seed*6364136223846793005ULL+1;buf[i]=(unsigned char)(seed>>32);}'+''.join(checks)+'}return 0;}']
 # A no-argument entry permits module interpreter checking with initialized memory.
 ir += ['export function l $interpreted() {','@s',' %p =l alloc8 32',' storel 72623859790382856, %p',' %p8 =l add %p, 8',' storel 72623859790382856, %p8',' %r =l call $probe_nested_indirect(l %p)',' ret %r','}']
 return '\n'.join(ir)+'\n','\n'.join(c)+'\n'
def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
 d=Path(work)/'aggregate-signature-aliases';d.mkdir(parents=True,exist_ok=True);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 def checked(cmd,inside=False):
  p=run(list(map(str,cmd)),inside);assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr);return p
 ir,caller=fixtures();src=d/'aliases.ssa';src.write_text(ir);c=d/'caller.c';c.write_text(caller)
 r=dict(target=target,compiler_identity=checked([compiler,'--build-identity']).stdout.strip(),compiler_sha256=sha(compiler),helper_sha256=sha(__file__),source_sha256=sha(src),caller_sha256=sha(c),checks_per_backend=896 if execute else 0,backends={},negative_controls={})
 p=checked([compiler,'--eval',src,'interpreted']);assert p.stdout.strip()=='72',p.stdout;r['interpreter']='nested indirect + recursive variadic return passed'
 p=run([str(compiler),'--first-path',str(src)],False);assert p.returncode!=0;r['negative_controls']['first_path']=p.stderr
 if before:
  p=run([str(before),'--check',str(src)],False);assert p.returncode!=0 and 'disagrees' in p.stderr;r['before_refusal']=p.stderr
 # Direct incompatibility is statically refused, indirect mismatch is checked by module interpreter.
 for name,shape in [('fp','{ d }'),('union','{ { l } }'),('opaque','align 8 { 8 }'),('explicit_alignment','align 8 { l }'),('alignment','align 16 { l }'),('count','{ l 2 }'),('width','{ w 2 }')]:
  common=f'type :a = {{ l }}\ntype :b = {shape}\nfunction :a $f(:a %p) {{\n@s\n ret %p\n}}\n'
  for site in ['argument','result','indirect']:
   target='%fn' if site=='indirect' else '$f';arg='b' if site!='result' else 'a';res='b' if site!='argument' else 'a'
   text=common+f'function l $bad() {{\n@s\n %p =l alloc16 32\n storel 1, %p\n %fn =l copy $f\n %r =:{res} call {target}(:{arg} %p)\n %v =l loadl %r\n ret %v\n}}\n';path=d/f'negative-{name}-{site}.ssa';path.write_text(text)
   cmd=[compiler,'--eval',path,'bad'] if site=='indirect' else [compiler,'--check',path];p=run(list(map(str,cmd)),False);assert p.returncode!=0 and ('signature disagrees' in p.stderr if site=='indirect' else 'type disagrees' in p.stderr),(name,site,p.stderr);r['negative_controls'][name+'_'+site]=p.stderr
 qt={'aarch64-macos':'arm64_apple','aarch64-linux':'arm64','x86_64-macos':'amd64_apple','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}[target];cc=[str(cc)] if isinstance(cc,(str,Path)) else list(map(str,cc))
 for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('qbe',[])] if execute and qbe else []):
  asm=d/(label+'.s');checked([qbe,'-t',qt,'-o',asm,src],True) if label=='qbe' else checked([compiler,src,'--target',target,*flags,'-o',asm]);row={'assembly_sha256':sha(asm),'execution':'not-run'};r['backends'][label]=row
  if execute:
   exe=d/label;checked([*cc,'-O2',*(['-no-pie'] if target=='riscv64-linux' and label=='qbe' else []),c,asm,'-o',exe],True);checked([exe],True);row['execution']='passed'
 if execute:
  bad=d/'wrong-callee.ssa';bad.write_text(ir.replace('@end\n ret %p','@end\n storeb 0, %p\n ret %p',1));assert bad.read_text()!=ir;asm=d/'wrong-callee.s';exe=d/'wrong-callee';checked([compiler,bad,'--target',target,'--optimize','-o',asm]);checked([*cc,'-O2',c,asm,'-o',exe],True);p=run([str(exe)],True);assert p.returncode==1,(p.returncode,p.stderr);r['negative_controls']['wrong_callee']='exit1 detected'
 if execute and qbe:r['qbe_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
 assert sha(src)==r['source_sha256'] and sha(c)==r['caller_sha256'];(d/'report.json').write_text(json.dumps(r,indent=2));return r
