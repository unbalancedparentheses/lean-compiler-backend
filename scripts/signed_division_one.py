#!/usr/bin/env python3
"""Independent C oracle for signed division/remainder by width-normalized +1."""
import argparse,hashlib,json,os,platform,re,shlex,subprocess,tempfile
from pathlib import Path
from fuzz import LCB


def fixture():
    functions=[];declarations=[];checks=[];names=[]
    for width,constants in [('w',[1,4294967297,-4294967295,18446744069414584321]),('l',[1,-18446744073709551615])]:
        for op in ['div','rem']:
            for i,n in enumerate(constants):
                name=f'{op}_{width}_{i}';names.append(name)
                finish=' %r =l extuw %v\n ret %r' if width=='w' else ' ret %v'
                functions.append(f'export function l ${name}(l %x) {{\n@s\n %v ={width} {op} %x,{n}\n'+finish+'\n}')
                declarations.append(f'extern uint64_t {name}(uint64_t);')
                expected=('(uint32_t)x' if width=='w' else 'x') if op=='div' else '0'
                checks.append(f'if({name}(x)!=(uint64_t)({expected}))return 1;')
    for op in ['div','rem']:
        name='effect_'+op;names.append(name)
        functions.append(f'''export function l ${name}(l %x) {{
@s
 %a =l call $side_effect(l %x)
 %v =w {op} %a,1
 %r =l extuw %v
 ret %r
}}''')
        declarations.append(f'extern uint64_t {name}(uint64_t);')
        checks.append(f'calls=0;if({name}(x)!=(uint64_t)'+('(uint32_t)x' if op=='div' else '0')+'||calls!=1)return 2;')
    guards=[]
    for w,zero,minus in [('w','4294967296','4294967295'),('l','0','-1')]:
        for op in ['div','rem']:
            for tag,n in [('zero',zero),('minus',minus),('eight','8')]:
                name=f'guard_{op}_{w}_{tag}';guards.append(name)
                finish=' %r =l extuw %v\n ret %r' if w=='w' else ' ret %v'
                functions.append(f'export function l ${name}(l %x) {{\n@s\n %v ={w} {op} %x,{n}\n'+finish+'\n}')
                if tag!='zero':
                    declarations.append(f'extern uint64_t {name}(uint64_t);')
                    st='int32_t' if w=='w' else 'int64_t';ut='uint32_t' if w=='w' else 'uint64_t';bits=32 if w=='w' else 64
                    expr=f'signed_x {"/" if op=="div" else "%"} '+('-1' if tag=='minus' else '8')
                    checks.append(f'{{{ut} raw=x;{st} signed_x;memcpy(&signed_x,&raw,sizeof raw);'+(f'if(raw!=UINT64_C({1<<(bits-1)}))' if tag=='minus' else '')+f'if({name}(x)!=(uint64_t)({ut})({expr}))return 3;}}')
    caller='#include <stdint.h>\n#include <string.h>\n'+'\n'.join(declarations)+'''
static unsigned calls;
uint64_t side_effect(uint64_t x){calls++;return x;}
int main(void){uint64_t state=UINT64_C(0x876543210abcd);
uint64_t edges[]={0,1,2,7,8,9,0x7fffffff,0x80000000,0xffffffff,UINT64_C(0x100000000),UINT64_C(0x100000001),UINT64_C(0x7fffffffffffffff),UINT64_C(0x8000000000000000),UINT64_MAX};
for(unsigned i=0;i<256;i++){state^=state<<13;state^=state>>7;state^=state<<17;uint64_t x=i<14?edges[i]:state;
'''+ '\n'.join(checks)+'\n}return 0;}\n'
    # The four signed MIN/-1 combinations are intentionally not executed in C.
    return '\n'.join(functions)+'\n',caller,names,guards,len(checks)*256-4


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None):
    d=Path(work)/'signed-division-one';d.mkdir(parents=True,exist_ok=True)
    ir,c,names,guards,count=fixture();src=d/'input.ssa';caller=d/'caller.c';src.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        p=run(cmd,inside);assert p.returncode==0,(cmd,p.stdout,p.stderr);return p
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'target':target,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(caller),'emitted_checks_per_mode':count,'executed_checks_per_mode':count if execute else 0,'qbe_sha256':checked(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip() if execute and qbe else None,'modes':{},'undefined_guards':[],'negative_control':'not-run'}
    for w,bits in [('w',32),('l',64)]:
        for op in ['div','rem']:
            for tag,value in [('zero',7),('minus',1<<(bits-1))]:
                name=f'guard_{op}_{w}_{tag}'
                p=run([compiler,'--eval',src,name,str(value)],False)
                assert p.returncode!=0 and ('division/remainder' in p.stderr),(name,p.stdout,p.stderr)
                report['undefined_guards'].append({'name':name,'exit':p.returncode,'diagnostic':p.stderr})
    obj=d/'caller.o'
    if execute:checked([cc,'-O2','-c',caller,'-o',obj],True)
    modes=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]
    if execute and qbe:modes.append(('qbe',None))
    division=re.compile(r'\t(?:sdiv|idiv[lq]?|divw?|remw?)\b')
    for mode,flags in modes:
        asm=d/(mode+'.s');exe=d/mode
        checked([qbe,'-t',qtarget,'-o',asm,src] if flags is None else [compiler,src,'--target',target,*flags,'-o',asm],flags is None);text=asm.read_text()
        def body(name):
            label=('_' if target.endswith('macos') else '')+name
            return text.split('\n'+label+':\n',1)[1].split('\n.globl ',1)[0].split('\n.size ',1)[0]
        if mode=='optimized':
            for name in names:assert not division.search(body(name)),name
            for name in guards:assert division.search(body(name)),name
        report['modes'][mode]={'emission':'passed','execution':'not-run','assembly_sha256':sha(asm)}
        if execute:
            checked([cc,obj,asm,'-o',exe],True);checked([exe],True);report['modes'][mode]['execution']='passed'
            if mode=='optimized':
                b=body('div_w_0')
                mutation={'aarch64':'\tadd x0, x0, #1','x86_64':'\taddq $1, %rax','riscv64':'\taddi a0, a0, 1'}[target.split('-')[0]]
                changed=b.replace('\tret',mutation+'\n\tret');assert changed!=b
                bad=d/'bad.s';bad.write_text(text.replace(b,changed,1));badexe=d/'bad';checked([cc,obj,bad,'-o',badexe],True)
                p=run([badexe],True);assert p.returncode==1,(p.returncode,p.stderr);report['negative_control']='detected'
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(target,count,'checks per mode passed; execution',execute,flush=True);return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--target',default=('aarch64' if platform.machine() in ['aarch64','arm64'] else 'x86_64')+('-macos' if platform.system()=='Darwin' else '-linux'));ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='');ap.add_argument('--work',type=Path);ap.add_argument('--qbe',type=Path);ap.add_argument('--qtarget');ap.add_argument('--require-native',action='store_true');a=ap.parse_args()
    host=('aarch64' if platform.machine() in ['aarch64','arm64'] else platform.machine())+('-macos' if platform.system()=='Darwin' else '-linux');execute=a.target==host or bool(a.runner)
    if a.require_native:assert execute
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:
            if cmd[0]==a.cc:cmd=shlex.split(a.cc)+cmd[1:]
            elif len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(cmd,text=True,capture_output=True,timeout=180)
    if a.work:exercise(a.compiler.resolve(),a.work.resolve(),run,a.cc,a.target,execute,a.qbe,a.qtarget)
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-signed-one-') as d:exercise(a.compiler.resolve(),Path(d),run,a.cc,a.target,execute,a.qbe,a.qtarget)
if __name__=='__main__':main()
