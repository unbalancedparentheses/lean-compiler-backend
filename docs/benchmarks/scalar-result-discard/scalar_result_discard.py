#!/usr/bin/env python3
"""Scalar call results may be discarded; aggregate hidden-return storage stays guarded.

Unknown external/indirect native signatures remain link-time ABI assumptions.
"""
from pathlib import Path
import hashlib,json,re
TYPES=[('w','uint32_t','4294967295'),('l','uint64_t','18446744073709551615'),('s','float','s_1.5'),('d','double','d_-2.5'),('sb','int8_t','255'),('ub','uint8_t','255'),('sh','int16_t','65535'),('uh','uint16_t','65535')]
def fixtures():
 ir=[];c=['#include <stdint.h>'];checks=[]
 for i,(kind,ctype,value) in enumerate(TYPES,1):
  ir += [f'function {kind} $local_{kind}(l %p) {{ @s %v =l loadl %p %r =l add %v, {i} storel %r, %p ret {value} }}',f'export function $probe_{kind}(l %p, l %fn) {{ @s call $local_{kind}(l %p) %f =l copy $local_{kind} call %f(l %p) call $external_{kind}(l %p) call %fn(l %p) ret }}',f'export function l $interpret_{kind}() {{ @s %p =l alloc8 8 storel 0, %p call $local_{kind}(l %p) %f =l copy $local_{kind} call %f(l %p) %r =l loadl %p ret %r }}']
  c += [f'{ctype} external_{kind}(uint64_t *p){{*p+={i};return ({ctype})-1;}}',f'extern void probe_{kind}(uint64_t*,{ctype}(*)(uint64_t*));']
  checks += [f'{{uint64_t value=seed;probe_{kind}(&value,external_{kind});if(value!=seed+UINT64_C({4*i}))return 1;}}']
 # Existing opposite-direction SSA normalization: a dead bound result from void.
 ir += ['function $nothing(l %p) { @s %v =l loadl %p %r =l add %v, 9 storel %r, %p ret }','export function $dead_void(l %p) { @s %unused =w call $nothing(l %p) ret }','function w $variadic(l %p, ...) { @s %v =l loadl %p %r =l add %v, 10 storel %r, %p ret 99 }','export function $discard_variadic(l %p) { @s call $variadic(l %p, ...) ret }']
 c += ['extern void dead_void(uint64_t*),discard_variadic(uint64_t*);','int main(void){uint64_t seed=UINT64_C(0xfedcba9876543210);for(unsigned t=0;t<32;t++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;'+''.join(checks)+'{uint64_t v=seed;dead_void(&v);if(v!=seed+9)return 2;discard_variadic(&v);if(v!=seed+19)return 3;}}return 0;}']
 text='\n'.join(ir)+'\n'
 text=re.sub(r' (?=@s|%[A-Za-z0-9_]+ =|call |storel |ret |\})','\n',text)
 text=text.replace('=w\ncall ','=w call ')
 return text,'\n'.join(c)+'\n'
NEGATIVES={
'aggregate':'type :big = { l 4 } function :big $f() { @s %p =l alloc8 32 ret %p } function $bad() { @s call $f() ret }',
'used_void':'function $f() { @s ret } function w $bad() { @s %x =w call $f() ret %x }',
'used_float_mismatch':'function d $f() { @s ret d_1.5 } function l $bad() { @s %x =l call $f() ret %x }',
'argument_mismatch':'function w $f(l %p) { @s ret 1 } function $bad() { @s call $f(w 1) ret }',
'used_environment':'function w $f(env %e) { @s %w =w copy %e ret %w } function $bad() { @s call $f() ret }'}
def exercise(compiler,work,run,cc,target,execute=True,qbe=None):
 d=Path(work)/'scalar-result-discard';d.mkdir(parents=True,exist_ok=True);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 def checked(cmd,inside=False):
  p=run(list(map(str,cmd)),inside);assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr);return p
 src=d/'calls.ssa';c=d/'caller.c';ir,caller=fixtures();src.write_text(ir);c.write_text(caller)
 r={'target':target,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(c),'checks_per_backend':320 if execute else 0,'scalar_abi_types':[x[0] for x in TYPES],'backends':{},'negative_controls':{},'original_qbe':'not-run','scope':'Scalar result discard only. Unknown native external/indirect signatures remain ABI assumptions; no aggregate result omission support.'}
 for name,body in NEGATIVES.items():
  p=d/(name+'.ssa');p.write_text(body+'\n');res=run([str(compiler),'--check',str(p)],False);assert res.returncode!=0,(name,'unexpected admission');r['negative_controls'][name]=res.stderr.strip()
 indirect=d/'aggregate-indirect.ssa';indirect.write_text('type :big = { l 4 } function :big $f() { @s %p =l alloc8 32 ret %p } function $bad() { @s %fn =l copy $f call %fn() ret }\n');p=run([str(compiler),'--eval',str(indirect),'bad'],False);assert p.returncode!=0 and 'indirect call signature' in p.stderr,p.stderr;r['negative_controls']['aggregate_indirect_interpreter']=p.stderr.strip()
 for i,(kind,_,_) in enumerate(TYPES,1):
  p=checked([compiler,'--eval',src,'interpret_'+kind]);assert p.stdout.strip()==str(2*i),(kind,p.stdout)
 r['interpreter_checks']=8
 qt={'aarch64-macos':'arm64_apple','aarch64-linux':'arm64','x86_64-macos':'amd64_apple','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}[target]
 for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('qbe',[])] if execute and qbe else []):
  asm=d/(label+'.s')
  if label=='qbe':checked([qbe,'-t',qt,'-o',asm,src],True)
  else:checked([compiler,src,'--target',target,*flags,'-o',asm])
  row={'assembly_sha256':sha(asm),'execution':'not-run'};r['backends'][label]=row
  if execute:
   exe=d/label;checked([cc,'-O2',*(['-no-pie'] if target=='riscv64-linux' and label=='qbe' else []),c,asm,'-o',exe],True);checked([exe],True);row['execution']='passed'
 if execute:
  bad=d/'wrong-effect.ssa';bad.write_text(ir.replace('add %v, 1\nstorel','add %v, 2\nstorel',1));assert bad.read_bytes()!=src.read_bytes();asm=d/'wrong-effect.s';exe=d/'wrong-effect';checked([compiler,bad,'--target',target,'--optimize','-o',asm]);checked([cc,'-O2',c,asm,'-o',exe],True);p=run([str(exe)],True);assert p.returncode==1,(p.returncode,p.stderr);r['negative_controls']['wrong_effect']='detected exit1'
 if execute and qbe:r['original_qbe']='passed';r['qbe_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
 assert sha(src)==r['source_sha256'] and sha(c)==r['caller_sha256'];(d/'report.json').write_text(json.dumps(r,indent=2)+'\n');return r

def main():
    import argparse,os,platform,shutil,subprocess,tempfile
    from fuzz import LCB,ROOT
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--compiler',type=Path,default=LCB);parser.add_argument('--require-native',action='store_true');args=parser.parse_args()
    machine=platform.machine().lower();target={('Darwin','arm64'):'aarch64-macos',('Darwin','x86_64'):'x86_64-macos',('Linux','aarch64'):'aarch64-linux',('Linux','arm64'):'aarch64-linux',('Linux','x86_64'):'x86_64-linux',('Linux','amd64'):'x86_64-linux',('Linux','riscv64'):'riscv64-linux'}.get((platform.system(),machine));execute=target is not None
    if args.require_native:assert execute,'supported native target required'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-scalar-result-discard-') as tmp:
        work=Path(tmp);qbe=None;cc=os.environ.get('LCB_CC','cc')
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);p=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert p.returncode==0,p.stderr;qbe=oracle/'qbe'
        print(json.dumps(exercise(args.compiler.resolve(),work,run,cc,target or 'aarch64-macos',execute,qbe),indent=2))

if __name__=='__main__':main()
