#!/usr/bin/env python3
"""Typed ARM phi identity omission: raw bits, spill cycles and narrowing guards."""
import hashlib,json,re
from pathlib import Path


def fixture():
    sources=[];decl=[];checks=[];names=[]
    for kind,width in [('w',32),('l',64),('s',32),('d',64)]:
        for size in [2,4,12,24]:
            for variant in ['identity','rotate','partial','update']:
                perm=list(range(size)) if variant in ['identity','update'] else [(i+1)%size for i in range(size)] if variant=='rotate' else [0]+[1+(i%(size-1)) for i in range(1,size)]
                name=f'phi_{kind}_{size}_{variant}';names.append(name);lines=[f'export function l ${name}(l %p,w %n) {{','@s']
                for i in range(size):lines += [f' %p{i} =l add %p,{8*i}',f' %initial{i} ={kind} load{kind} %p{i}']
                lines += [' jmp @loop','@loop']
                for i,j in enumerate(perm):
                    incoming=f'%nextv{i}' if variant=='update' else f'%v{j}'
                    lines += [f' %v{i} ={kind} phi @s %initial{i},@loop {incoming}']
                lines += [' %i =w phi @s 0,@loop %next']
                if variant=='update':
                    for i in range(size):
                        value=f'%v{i}';iw='w' if width==32 else 'l';mask=(0x9e3779b9*(i+1))&((1<<width)-1)
                        if kind in ['s','d']:lines += [f' %oldbits{i} ={iw} cast {value}'];value=f'%oldbits{i}'
                        lines += [f' %newbits{i} ={iw} xor {value},{mask}']
                        lines += [f' %nextv{i} ={kind} '+('cast' if kind in ['s','d'] else 'copy')+f' %newbits{i}']
                lines += [' %next =w add %i,1',' %more =w cultw %next,%n',' dbgloc 777, 1',' jnz %more,@loop,@done','@done',' %hash0 =l copy 1469598103934665603']
                for i in range(size):
                    value=f'%nextv{i}' if variant=='update' else f'%v{i}'
                    if kind in ['s','d']:lines += [f' %bits{i} ={ "w" if width==32 else "l"} cast {value}'];value=f'%bits{i}'
                    if width==32:lines += [f' %wide{i} =l extuw {value}'];value=f'%wide{i}'
                    lines += [f' %mix{i} =l xor %hash{i},{value}',f' %hash{i+1} =l mul %mix{i},1099511628211']
                lines += [f' ret %hash{size}','}'];sources.append('\n'.join(lines));decl.append(f'extern uint64_t {name}(uint64_t*,unsigned);')
                update='for(unsigned step=0;step<n;step++)for(unsigned i=0;i<SIZE;i++)values[i]^=(UINT64_C(0x9e3779b9)*(i+1))&MASK;' if variant=='update' else 'for(unsigned step=1;step<n;step++){for(unsigned i=0;i<SIZE;i++)next[i]=values[perm[i]];for(unsigned i=0;i<SIZE;i++)values[i]=next[i];}'
                checks.append('''{unsigned perm[]={PERM};for(unsigned trial=0;trial<8;trial++){
 uint64_t input[24],values[24],next[24];for(unsigned i=0;i<SIZE;i++){state^=state<<13;state^=state>>7;state^=state<<17;input[i]=(trial<2)?edges[(i+trial)%16]:state;}
 for(unsigned n=1;n<=9;n++){for(unsigned i=0;i<SIZE;i++)values[i]=input[i]&MASK;
 UPDATE
 uint64_t expected=UINT64_C(1469598103934665603);for(unsigned i=0;i<SIZE;i++)expected=(expected^values[i])*UINT64_C(1099511628211);
 if(NAME(input,n)!=expected)return 1;}}}'''.replace('UPDATE',update).replace('PERM',','.join(map(str,perm))).replace('SIZE',str(size)).replace('MASK','UINT64_C(0xffffffff)' if width==32 else 'UINT64_MAX').replace('NAME',name))
    sources += ['''export function l $dirty_narrow(l %x) {
@s
 jmp @join
@join
 %v =w phi @s %x
 %r =l extuw %v
 ret %r
}
export function l $overlap_narrow(l %x) {
@s
 jmp @join
@join
 %v =w phi @s %x
 %saved =l phi @s %x
 %r =l extuw %v
 %out =l xor %r,%saved
 ret %out
}''']
    decl += ['extern uint64_t dirty_narrow(uint64_t),overlap_narrow(uint64_t);']
    checks += ['for(unsigned i=0;i<128;i++){state^=state<<13;state^=state>>7;state^=state<<17;uint64_t x=state|UINT64_C(0xffff000000000000);if(dirty_narrow(x)!=(uint32_t)x)return 2;if(overlap_narrow(x)!=(x^(uint32_t)x))return 3;}']
    # High pressure forces physical stack homes at both sides of narrowing and
    # explicit widening. Unlike implicit w-to-l phi, this is valid QBE input.
    for widen in [False,True]:
        name='spill_widen' if widen else 'spill_narrow';names.append(name);lines=[f'export function l ${name}(l %p) {{','@s']
        for i in range(24):lines += [f' %p{i} =l add %p,{8*i}',f' %initial{i} =l loadl %p{i}']
        lines += [' jmp @narrow','@narrow']
        for i in range(24):lines += [f' %word{i} =w phi @s %initial{i}']
        if widen:
            for i in range(24):lines += [f' %wide{i} =l extuw %word{i}']
            lines += [' jmp @wide','@wide']
            for i in range(24):lines += [f' %final{i} =l phi @narrow %wide{i}']
        else:
            for i in range(24):lines += [f' %final{i} =l extuw %word{i}']
        lines += [' %sentinel =l loadl %p',' %hash0 =l xor 1469598103934665603,%sentinel']
        for i in range(24):lines += [f' %mix{i} =l xor %hash{i},%final{i}',f' %hash{i+1} =l mul %mix{i},1099511628211']
        lines += [' ret %hash24','}'];sources.append('\n'.join(lines));decl.append(f'extern uint64_t {name}(uint64_t*);')
        checks += [f'for(unsigned trial=0;trial<128;trial++){{uint64_t input[24],expected=UINT64_C(1469598103934665603);for(unsigned i=0;i<24;i++){{state^=state<<13;state^=state>>7;state^=state<<17;input[i]=state|UINT64_C(0xa5a5ffff00000000);if(i==0)expected^=input[i];expected=(expected^(uint32_t)input[i])*UINT64_C(1099511628211);}}if({name}(input)!=expected)return 4;}}']
    c='#include <stdint.h>\n'+ '\n'.join(decl)+'''\nint main(void){uint64_t state=UINT64_C(0xfeed123456789abc);uint64_t edges[]={0,1,UINT64_MAX,0x80000000,0x7fffffff,0x8000000000000000,0x7fffffffffffffff,0x7fc12345,0xffc12345,0x7ff8123456789abc,0xfff8123456789abc,0x7f800000,0xff800000,0x7ff0000000000000,0xfff0000000000000,0xffffffff00000000};\n'''+ '\n'.join(checks)+'\nreturn 0;}\n'
    return 'dbgfile "arm-phi-identity.c"\n'+'\n'.join(sources)+'\n',c,names,64*72+256+256


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
    assert target in ['aarch64-linux','aarch64-macos'];d=Path(work)/'arm-phi-identity';d.mkdir(parents=True,exist_ok=True)
    ir,c,names,count=fixture();src=d/'input.ssa';caller=d/'caller.c';src.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        p=run(cmd,inside);assert p.returncode==0,(cmd,p.stdout,p.stderr);return p
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'target':target,'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'source_sha256':sha(src),'caller_sha256':sha(caller),'checks_per_mode':count if execute else 0,'modes':{},'wrong_narrowing':'not-run','original_qbe':'not-run'}
    bad=d/'implicit-widen.ssa';bad.write_text('function l $bad(w %x) { @s jmp @j @j %v =l phi @s %x ret %v }')
    p=run([compiler,bad,'--target',target,'--allocate','-o',d/'bad.s']);assert p.returncode and 'implicit w-to-l extension' in p.stderr
    obj=d/'caller.o'
    if execute:checked([cc,'-O2','-c',caller,'-o',obj],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/(mode+'.s');exe=d/mode;checked([compiler,src,'--target',target,*flags,'-o',asm]);text=asm.read_text()
        def body(name):
            label=('_' if target.endswith('macos') else '')+name
            return text.split('\n'+label+':\n',1)[1].split('\n.globl ',1)[0].split('\n.size ',1)[0]
        entry={'assembly_sha256':sha(asm),'execution':'not-run'};report['modes'][mode]=entry
        if mode=='allocated':
            assert not re.search(r'\tmov w(\d+), w\1\b',body('phi_w_24_identity')),'word phi identity still copied'
            assert re.search(r'\tmov w(\d+), w\1\b',body('dirty_narrow')),'narrowing GP phi lost normalization'
            for name in ['phi_w_24_identity','phi_d_24_identity']:
                edge=body(name).split(' 777 1\n',1)[1].split(f'L_lcb_block_{len(name)}_{name}_done:',1)[0]
                assert '\tstr ' not in edge,'same-width spilled identity still stages on loop edge'
            assert len(re.findall(r'ldr w9, \[sp, #(\d+)\]\n\tstr x9, \[sp, #\1\]',body('spill_widen')))==12,'explicit widening did not normalize dirty spill upper bytes'
        if before:
            old=d/(mode+'-before.s');checked([before,src,'--target',target,*flags,'-o',old]);previous=old.read_text()
            if mode=='allocated':
                def oldbody(name):
                    label=('_' if target.endswith('macos') else '')+name
                    return previous.split('\n'+label+':\n',1)[1].split('\n.globl ',1)[0].split('\n.size ',1)[0]
                assert oldbody('spill_narrow')==body('spill_narrow'),'cross-width same-stack fallback changed'
                name='spill_widen';marker=f'L_lcb_block_{len(name)}_{name}_narrow:'
                assert oldbody(name).split(marker)[0]==body(name).split(marker)[0],'initial narrowing spill edge changed'
                import difflib
                deleted=[line[2:] for line in difflib.ndiff(oldbody(name).splitlines(),body(name).splitlines()) if line.startswith('- ')]
                assert len(deleted)==48 and all(re.fullmatch(r'\t(?:ldr|str) x9, \[sp, #\d+\]',x) for x in deleted),'expected twelve long stack identity roundtrips not removed'
                entry['same_stack_narrow_fallback']='byte-identical';entry['same_stack_long_identities_removed']=12
            if mode=='baseline':assert previous==text;entry['baseline_identical']=True
            else:
                # Identity omission changes no branch targets or other operations.
                remaining=iter(previous.splitlines());assert all(any(x==line for x in remaining) for line in text.splitlines()),'candidate adds/reorders assembly'
                entry['instructions_removed']=sum(bool(re.match(r'\t[a-z]',x)) for x in previous.splitlines())-sum(bool(re.match(r'\t[a-z]',x)) for x in text.splitlines())
        if execute:
            checked([cc,obj,asm,'-o',exe],True);checked([exe],True);entry['execution']='passed'
            if mode=='allocated':
                b=body('dirty_narrow');damaged=re.sub(r'\tmov w(\d+), w\1\b','\tnop',b,count=1);assert damaged!=b
                corrupted=d/'wrong-narrow.s';corrupted.write_text(text.replace(b,damaged,1));badexe=d/'wrong-narrow';checked([cc,obj,corrupted,'-o',badexe],True);p=run([badexe],True);assert p.returncode==2,(p.returncode,p.stderr);report['wrong_narrowing']={'status':'detected','exit':p.returncode}
    if execute and qbe:
        asm=d/'qbe.s';exe=d/'qbe';checked([qbe,'-t','arm64_apple' if target.endswith('macos') else 'arm64','-o',asm,src],True);checked([cc,obj,asm,'-o',exe],True);checked([exe],True);report['original_qbe']='passed'
    (d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report


def main():
    import argparse,os,platform,shutil,subprocess,tempfile
    from fuzz import LCB,ROOT
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--before',type=Path);a=ap.parse_args()
    execute=platform.machine() in ['arm64','aarch64'] and platform.system() in ['Darwin','Linux']
    if a.require_native:assert execute,'ARM64 native host required'
    target='aarch64-macos' if platform.system()=='Darwin' else 'aarch64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-arm-phi-') as tmp:
        work=Path(tmp);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            p=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert p.returncode==0,p.stderr;qbe=oracle/'qbe'
        print(json.dumps(exercise(a.compiler.resolve(),work,run,cc,target,execute,qbe,a.before.resolve() if a.before else None),indent=2))
if __name__=='__main__':main()
