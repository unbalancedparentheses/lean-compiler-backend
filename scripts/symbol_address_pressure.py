#!/usr/bin/env python3
"""Independent global-address placement correctness and resource-profile fixtures.

The eight-global CFG cutoff is a profitability heuristic, not a pressure bound.
"""
from pathlib import Path
import hashlib,json
SPECS=[('single'+str(n),n,'single') for n in (8,9,16,64,512)]+[(kind+str(n),n,kind) for kind in ('branch','loop') for n in (8,9)]+[(kind+'16',16,kind) for kind in ('overlap','effect','multi','word')]
def fixture():
 lines=[f'export data $g{i} = align 8 {{ l 0, l 0, l 0 }}' for i in range(512)]
 for name,n,kind in SPECS:
  lines += [f'export function l ${name}(l %seed, w %choice) {{','@entry']
  acc='%seed'
  if kind=='branch':
   lines += [' jnz %choice, @yes, @no','@yes',' %ys =l xor %seed, 12345',' jmp @body','@no',' %ns =l xor %seed, 67890',' jmp @body','@body',' %start =l phi @yes %ys, @no %ns'];acc='%start'
  if kind=='loop':
   lines += [' jmp @body','@body',f' %start =l phi @entry %seed, @body %acc{n-1}',' %iter =w phi @entry 0, @body %next'];acc='%start'
  if kind=='effect':lines += [' call $touch(l $g0)']
  if kind=='multi':lines += [' %extra =l call $pair(l $g0, l $g1)',' %start =l xor %seed, %extra'];acc='%start'
  if kind=='word':lines += [' %low =w loadw $g0',' %wide =l extuw %low',' %start =l xor %seed, %wide'];acc='%start'
  if kind=='overlap':lines += [f' %a{i} =l loadl $g{i}' for i in range(n)]
  for i in range(n):
   if kind!='overlap':lines += [f' %a{i} =l loadl $g{i}']
   lines += [f' %bp{i} =l add $g{i}, 8',f' %b{i} =l loadl %bp{i}',f' %cp{i} =l add $g{i}, 16',f' %c{i} =l loadl %cp{i}',f' %x{i} =l xor %a{i}, %b{i}',f' %y{i} =l add %x{i}, %c{i}',f' %m{i} =l mul {acc}, 33',f' %acc{i} =l add %m{i}, %y{i}'];acc=f'%acc{i}'
  if kind=='loop':lines += [' %next =w add %iter, 1',' %again =w cultw %next, %choice',' jnz %again, @body, @done','@done']
  lines += [f' ret {acc}','}']
 return '\n'.join(lines)+'\n'
def caller():
 decl='\n'.join(f'extern uint64_t g{i}[3];' for i in range(512))
 funcs='\n'.join(f'extern uint64_t {name}(uint64_t,unsigned);' for name,n,k in SPECS)
 cases=[]
 for name,n,k in SPECS:
  init='seed'
  if k=='branch':init='seed ^ (choice ? 12345 : 67890)'
  if k=='multi':init='seed ^ (g0[0] ^ g1[0])'
  if k=='word':init='seed ^ (uint32_t)g0[0]'
  cases += [f'{{uint64_t expected={init};for(unsigned r=0;r<{"(choice?choice:1)" if k=="loop" else "1"};r++)for(unsigned j=0;j<{n};j++)expected=expected*33+((globals[j][0]^globals[j][1])+globals[j][2]);if({name}(seed,choice)!=expected)return 1;}}']
 return '#include <stdint.h>\n'+decl+'\n'+funcs+'\nuint64_t *globals[]={'+','.join(f'g{i}' for i in range(512))+'};\nvoid touch(uint64_t *p){ __asm__ volatile("" : : "r"(p) : "memory"); }\nuint64_t pair(uint64_t *a,uint64_t*b){return *a ^ *b;}\nstatic uint64_t rng(uint64_t*s){*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;return *s;}\nint main(void){uint64_t state=UINT64_C(0xfedcba9876543210);for(unsigned t=0;t<32;t++){for(unsigned i=0;i<512;i++)for(unsigned j=0;j<3;j++)globals[i][j]=rng(&state);uint64_t seed=rng(&state);unsigned choice=t%4;'+''.join(cases)+'}return 0;}\n'
def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
 d=Path(work)/'symbol-address-pressure';d.mkdir(parents=True,exist_ok=True)
 sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 def checked(cmd,inside=False):
  p=run(list(map(str,cmd)),inside);assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr);return p
 src=d/'pressure.ssa';src.write_text(fixture());c=d/'caller.c';c.write_text(caller())
 qtarget={'aarch64-macos':'arm64_apple','aarch64-linux':'arm64','x86_64-macos':'amd64_apple','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}[target]
 report={'target':target,'scope':'Seeded independent uint64 C oracle; CFG cap is profitability heuristic, not pressure bound. No timing claim.','compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'ir_sha256':sha(src),'caller_sha256':sha(c),'cases':SPECS,'checks_per_backend':32*len(SPECS) if execute else 0,'backends':{},'negative_control':'not-run'}
 if before:report['before_identity']=checked([before,'--build-identity']).stdout.strip();report['before_sha256']=sha(before)
 for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('qbe',[])] if execute and qbe else []):
  asm=d/(label+'.s')
  if label=='qbe':checked([qbe,'-t',qtarget,'-o',asm,src],True)
  else:checked([compiler,src,'--target',target,*flags,'-o',asm])
  row={'assembly_sha256':sha(asm),'execution':'not-run'};report['backends'][label]=row
  if before and label in ('baseline','allocated'):
   old=d/(label+'-before.s');checked([before,src,'--target',target,*flags,'-o',old]);assert old.read_bytes()==asm.read_bytes(),(target,label,'unexpected nonoptimized change');row['before_byte_identical']=True
  if execute:
   exe=d/label;checked([cc,'-O2',*(['-no-pie'] if target=='riscv64-linux' and label=='qbe' else []),c,asm,'-o',exe],True);checked([exe],True);row['execution']='passed'
 if execute:
  bad=d/'wrong-global.ssa';bad.write_text(src.read_text().replace('loadl $g0\n','loadl $g1\n',1));assert bad.read_bytes()!=src.read_bytes();ba=d/'wrong-global.s';checked([compiler,bad,'--target',target,'--optimize','-o',ba]);be=d/'wrong-global';checked([cc,'-O2',c,ba,'-o',be],True);p=run([str(be)],True);assert p.returncode==1,(p.returncode,p.stderr);report['negative_control']={'status':'detected','exit':1,'ir_sha256':sha(bad)}
 if execute and qbe:report['original_qbe_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
 assert sha(src)==report['ir_sha256'] and sha(c)==report['caller_sha256']
 (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def main():
    import argparse,os,platform,shutil,subprocess,tempfile
    from fuzz import LCB,ROOT
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--compiler',type=Path,default=LCB);parser.add_argument('--require-native',action='store_true');parser.add_argument('--before',type=Path);args=parser.parse_args()
    machine=platform.machine().lower();target={('Darwin','arm64'):'aarch64-macos',('Darwin','x86_64'):'x86_64-macos',('Linux','aarch64'):'aarch64-linux',('Linux','arm64'):'aarch64-linux',('Linux','x86_64'):'x86_64-linux',('Linux','amd64'):'x86_64-linux',('Linux','riscv64'):'riscv64-linux'}.get((platform.system(),machine));execute=target is not None
    if args.require_native:assert execute,'supported native target required'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-symbol-address-pressure-') as tmp:
        work=Path(tmp);qbe=None;cc=os.environ.get('LCB_CC','cc')
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle);p=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert p.returncode==0,p.stderr;qbe=oracle/'qbe'
        print(json.dumps(exercise(args.compiler.resolve(),work,run,cc,target or 'aarch64-macos',execute,qbe,args.before.resolve() if args.before else None),indent=2))

if __name__=='__main__':main()
