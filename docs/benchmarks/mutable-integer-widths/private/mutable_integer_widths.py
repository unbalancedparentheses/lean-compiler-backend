#!/usr/bin/env python3
"""QBE word-class merging for mutable integer temporaries; long uses remain invalid."""
from pathlib import Path
import hashlib,json
SOURCE='''export function w $long_then_word(l %input, w %n) {
@s
 %v =l copy %input
 %v =w add %v, 1
 ret %v
}
export function w $word_then_long(l %input, w %n) {
@s
 %v =w copy %n
 %v =l add %input, 3
 ret %v
}
export function w $parameter_long(l %input, w %n) {
@s
 %input =w add %input, 17
 ret %input
}
export function w $parameter_word(l %input, w %n) {
@s
 %n =l add %input, 23
 ret %n
}
export function w $branch(l %input, w %n) {
@s
 %flag =w and %n, 1
 jnz %flag, @wide, @narrow
@wide
 %v =l add %input, 7
 jmp @join
@narrow
 %v =w add %input, 13
 jmp @join
@join
 %v =w xor %v, 305419896
 ret %v
}
export function w $loop(l %input, w %n) {
@s
 %v =l copy %input
 %i =w copy 0
 jnz %n, @body, @done
@body
 %v =w add %v, 3
 %wide =l extuw %v
 %v =l add %wide, 7
 %i =w add %i, 1
 %more =w cultw %i, %n
 jnz %more, @body, @done
@done
 ret %v
}
export function w $shift(l %input, w %n) {
@s
 %v =l copy %input
 %v =w add %v, %n
 %wide =l shl %input, %v
 %r =w copy %wide
 ret %r
}
function w $called(w %x) {
@s
 %r =w mul %x, 7
 ret %r
}
export function w $call_word(l %input, w %n) {
@s
 %v =l copy %input
 %v =w add %v, %n
 %r =w call $called(w %v)
 ret %r
}
export function w $word_roles(l %input, w %n) {
@s
 %v =l copy %input
 %v =w xor %v, %n
 %f =s cast %v
 %bits =w cast %f
 %p =l alloc8 8
 storew %bits, %p
 %r =w loadw %p
 ret %r
}
'''
SOURCE += """function $effect(w %x, l %p) {
@s
 storew %x, %p
 ret
}
export function w $void_call_word(l %input, w %n) {
@s
 %v =l copy %input
 %v =w add %v, %n
 %p =l alloc8 8
 storew 0, %p
 call $effect(w %v, l %p)
 %r =w loadw %p
 ret %r
}
"""
NAMES=['long_then_word','word_then_long','parameter_long','parameter_word','branch','loop','shift','call_word','word_roles','void_call_word']
def expected(name,x,n):
 mask=(1<<32)-1
 return {'long_then_word':x+1,'word_then_long':x+3,'parameter_long':x+17,'parameter_word':x+23,'branch':((x+(7 if n&1 else 13))&mask)^305419896,'loop':x+10*n,'shift':x<<((x+n)&63),'call_word':(x+n)*7,'word_roles':x^n,'void_call_word':x+n}[name]&mask
def caller():
 models=['(uint32_t)(x+1)','(uint32_t)(x+3)','(uint32_t)(x+17)','(uint32_t)(x+23)','((uint32_t)(x+((n&1)?7:13))^305419896u)','(uint32_t)(x+10*n)','(uint32_t)(x<<((x+n)&63))','(uint32_t)((x+n)*7)','((uint32_t)x^n)','(uint32_t)(x+n)']
 return '#include <stdint.h>\n'+''.join('extern uint32_t '+name+'(uint64_t,uint32_t);\n' for name in NAMES)+'int main(void){uint64_t x=0xfedcba9876543210ULL;for(unsigned seed=0;seed<128;seed++){x=x*6364136223846793005ULL+1;for(unsigned n=0;n<9;n++){'+''.join(f'if({name}(x,n)!={model})return 1;' for name,model in zip(NAMES,models))+'}}return 0;}\n'
def negatives():
 prefix='function w $bad(l %input) {\n@s\n %v =l copy %input\n %v =w copy 1\n'
 uses={'copy':'%r =l copy %v','add_left':'%r =l add %v,1','add_right':'%r =l add 1,%v','divide':'%r =l div 9,%v','compare':'%r =w ceql %v,1','cast':'%r =d cast %v','float_copy':'%r =s copy %v','float_arithmetic':'%r =s add %v,s_1','float_compare':'%r =w ceqs %v,s_1','conversion':'%r =d sltof %v','load':'%r =w loadw %v','store_address':'storew 1,%v','store_value':'storel %v,%input','call_argument':'%r =w call $external(l %v)','void_call':'call $external(l %v)','indirect':'call %v()','environment':'call $external(env %v)','allocation':'%r =l alloc8 %v','vastart':'vastart %v','vaarg':'%r =w vaarg %v','blit_source':'blit %v,%input,1','blit_destination':'blit %input,%v,1'}
 result={name:prefix+body+'\n ret 0\n}\n' for name,body in uses.items()}
 result['return']=prefix.replace('function w','function l')+' ret %v\n}\n'
 result['before_narrow']='function w $bad(l %input){\n@s\n %v =l copy %input\n %r =l add %v,1\n %v =w copy 1\n ret 0\n}\n'
 result['dead_long']=prefix+' ret %v\n@dead\n %r =l copy %v\n ret 0\n}\n'
 result['dead_definition']='function w $bad(l %input){\n@s\n %v =l copy %input\n %r =l add %v,1\n ret 0\n@dead\n %v =w copy 1\n ret 0\n}\n'
 result['phi']=prefix+' jmp @join\n@join\n %r =l phi @s %v\n ret 0\n}\n'
 result['mixed_float']=prefix+' %v =s copy s_1\n ret 0\n}\n'
 return result

def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
 d=Path(work)/'mutable-integer-widths';d.mkdir(parents=True,exist_ok=True);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
 def checked(cmd,inside=False):
  p=run(list(map(str,cmd)),inside);assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr);return p
 src=d/'mutable.ssa';src.write_text(SOURCE);c=d/'caller.c';c.write_text(caller());r=dict(target=target,compiler_identity=checked([compiler,'--build-identity']).stdout.strip(),compiler_sha256=sha(compiler),helper_sha256=sha(__file__),source_sha256=sha(src),caller_sha256=sha(c),checks_per_backend=11520 if execute else 0,backends={},negatives={})
 for name in NAMES:
  for x,n in [(0,0),(4294967295,1),(18446744073709551615,8)]:
   p=checked([compiler,'--eval',src,name,str(x),str(n)]);assert int(p.stdout)==expected(name,x,n),(name,x,n,p.stdout)
 r['interpreter_checks']=30
 p=run([str(compiler),'--first-path',str(src)],False);assert p.returncode!=0;r['first_path']='refused'
 if before:
  p=run([str(before),'--check',str(src)],False);assert p.returncode!=0 and 'inconsistent types' in p.stderr;r['before_refusal']=p.stderr
 qt={'aarch64-macos':'arm64_apple','aarch64-linux':'arm64','x86_64-macos':'amd64_apple','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}[target]
 for name,body in negatives().items():
  path=d/(name+'.ssa');path.write_text(body);p=run([str(compiler),'--check',str(path)],False);assert p.returncode!=0,(name,p.stdout);r['negatives'][name]={'lcb':p.stderr}
  if execute and qbe:
   p=run(list(map(str,[qbe,'-t',qt,'-o',d/(name+'.s'),path])),True);assert p.returncode!=0,(name,'QBE admitted');r['negatives'][name]['qbe']=p.stderr
 cc=[str(cc)] if isinstance(cc,(str,Path)) else list(map(str,cc))
 for label,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('qbe',[])] if execute and qbe else []):
  asm=d/(label+'.s');checked([qbe,'-t',qt,'-o',asm,src],True) if label=='qbe' else checked([compiler,src,'--target',target,*flags,'-o',asm]);row={'assembly_sha256':sha(asm),'execution':'not-run'};r['backends'][label]=row
  if execute:
   exe=d/label;checked([*cc,'-O2',*(['-no-pie'] if target=='riscv64-linux' and label=='qbe' else []),c,asm,'-o',exe],True);checked([exe],True);row['execution']='passed'
 if execute:
  bad=d/'wrong-word.ssa';bad.write_text(SOURCE.replace('%v =w add %v, 1','%v =w add %v, 2',1));asm=d/'wrong-word.s';exe=d/'wrong-word';checked([compiler,bad,'--target',target,'--optimize','-o',asm]);checked([*cc,'-O2',c,asm,'-o',exe],True);p=run([str(exe)],True);assert p.returncode==1;r['wrong_word_control']='exit1 detected'
 if execute and qbe:r['qbe_sha256']=checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
 assert sha(src)==r['source_sha256'] and sha(c)==r['caller_sha256'];(d/'report.json').write_text(json.dumps(r,indent=2));return r

def main():
 import argparse,os,platform,subprocess,tempfile
 from fuzz import LCB
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--before',type=Path);p.add_argument('--qbe',type=Path);p.add_argument('--target');p.add_argument('--emission-only',action='store_true');p.add_argument('--require-native',action='store_true');args=p.parse_args()
 native={('Darwin','arm64'):'aarch64-macos',('Darwin','x86_64'):'x86_64-macos',('Linux','aarch64'):'aarch64-linux',('Linux','arm64'):'aarch64-linux',('Linux','x86_64'):'x86_64-linux',('Linux','riscv64'):'riscv64-linux'}.get((platform.system(),platform.machine().lower()));target=args.target or native or 'aarch64-macos';execute=not args.emission_only and target==native
 if args.require_native:assert execute,'native execution required'
 def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
 with tempfile.TemporaryDirectory(prefix='lcb-mutable-widths-') as tmp:print(json.dumps(exercise(args.compiler.resolve(),Path(tmp),run,os.environ.get('LCB_CC','cc'),target,execute,args.qbe,args.before),indent=2))
if __name__=='__main__':main()
