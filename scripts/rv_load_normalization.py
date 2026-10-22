#!/usr/bin/env python3
"""Independent integer/FP bit oracle for RV64 load result normalization."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import subprocess
import tempfile
from fuzz import LCB


def fixture():
    functions, declarations, checks, cases = [], [], [], []
    kinds = [(k, bits, signed, width) for k, bits, signed in
             [('sb',8,True),('ub',8,False),('sh',16,True),('uh',16,False),
              ('sw',32,True),('uw',32,False)] for width in ['w','l']]
    kinds += [('',32,False,'w'),('w',32,False,'w'),('l',64,False,'l'),('s',32,False,'s'),('d',64,False,'d')]
    for kind, bits, signed, width in kinds:
        for folded in [False, True]:
            name = f'load_{kind}_{width}_{"folded" if folded else "direct"}'
            address = '%address' if folded else '%p'
            lines = [f'export function l ${name}(l %p,l %out) {{', '@start']
            if folded: lines += [' %address =l add %p,16']
            lines += [f' %value ={width} load{kind} {address}']
            value = '%value'
            if width in ['s','d']:
                lines += [f' store{width} %value,%out',
                          f' %bits ={"w" if width=="s" else "l"} cast %value']
                value = '%bits'
            if width in ['w','s']:
                lines += [f' %wide =l extuw {value}']; value = '%wide'
            lines += [f' ret {value}', '}']
            functions.append('\n'.join(lines))
            declarations.append(f'extern uint64_t {name}(void *,void *);')
            narrow = f'{"int" if signed else "uint"}{bits}_t'
            result = f'(uint64_t)({"uint32_t" if width in ["w","s"] else "uint64_t"})({narrow})seed'
            checks.append(f'''memcpy(bytes+{16 if folded else 0},&seed,8);memset(output,0xa5,8);
 if({name}(bytes,output)!={result})return 1;''')
            if width in ['s','d']:
                checks.append(f'if(memcmp(output,&seed,{bits//8}))return 2;')
            cases.append({'name':name,'kind':kind,'width':width,'folded':folded})
    # Narrowing an existing SSA long remains necessary, as do signed loads.
    functions += ['''export function l $copy_narrow(l %x) {
@s
 %word =w copy %x
 %wide =l extuw %word
 ret %wide
}''', '''export function l $cast_narrow(l %x) {
@s
 %word =w copy %x
 %fp =s cast %word
 %bits =w cast %fp
 %wide =l extuw %bits
 ret %wide
}''']
    declarations += ['extern uint64_t copy_narrow(uint64_t);','extern uint64_t cast_narrow(uint64_t);']
    checks += ['if(copy_narrow(seed)!=(uint32_t)seed)return 3;',
               'if(cast_narrow(seed)!=(uint32_t)seed)return 4;']
    caller = '''#include <stdint.h>
#include <string.h>
'''+'\n'.join(declarations)+'''
int main(void){
 const uint64_t edges[]={0,1,127,128,255,256,32767,32768,65535,65536,
 UINT64_C(0x7fffffff),UINT64_C(0x80000000),UINT64_C(0xffffffff),
 UINT64_C(0x100000000),UINT64_C(0x8000000000000000),UINT64_MAX,
 UINT64_C(0x7f800000),UINT64_C(0xff800000),UINT64_C(0x7fc12345),
 UINT64_C(0xffc12345),UINT64_C(0x7f812345),UINT64_C(0x7ff0000000000000),
 UINT64_C(0xfff0000000000000),UINT64_C(0x7ff8123456789abc),
 UINT64_C(0xfff8123456789abc),UINT64_C(0x7ff0123456789abc)};
 _Alignas(8) unsigned char bytes[32],output[8];uint64_t random=UINT64_C(0x924f123456789abc);
 for(unsigned i=0;i<256;i++){
  random^=random<<13;random^=random>>7;random^=random<<17;
  uint64_t seed=i<sizeof(edges)/sizeof(edges[0])?edges[i]:random;
'''+ '\n'.join(checks)+'''
 }return 0;
}
'''
    return '\n'.join(functions)+'\n', caller, cases, (len(cases)+2)*256


def exercise(compiler, work, run, cc, target='riscv64-linux', execute=True):
    assert target == 'riscv64-linux'
    case = Path(work)/'rv-load-normalization';case.mkdir(parents=True,exist_ok=True)
    ir,c,cases,count = fixture();source,caller=case/'input.ssa',case/'caller.c'
    source.write_text(ir);caller.write_text(c)
    def checked(cmd,inside=False):
        result=run(cmd,inside);assert result.returncode==0,(cmd,result.stdout,result.stderr);return result
    report={'target':target,'execution':execute,'cases_per_mode':count,
            'compiler_identity':checked([compiler,'--build-identity']).stdout.strip(),
            'compiler_sha256':hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'caller_sha256':hashlib.sha256(caller.read_bytes()).hexdigest(),'modes':{},'negative_controls':[]}
    caller_object=case/'caller.o'
    if execute:checked([cc,'-std=c11','-O2','-c',caller,'-o',caller_object],True)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(mode+'.s'),case/mode
        checked([compiler,source,'--target',target,*flags,'-o',asm])
        text=asm.read_text()
        def body(name):
            start=text.index('\n'+name+':\n');end=text.index('\n.size '+name+',',start)
            return text[start:end]
        for item in cases:
            b=body(item['name']);kind=item['kind'];width=item['width']
            op={'sb':'lb','ub':'lbu','sh':'lh','uh':'lhu','sw':'lw','uw':'lwu','':'lwu','w':'lw','l':'ld','s':'lwu','d':'ld'}[kind]
            offset=16 if item['folded'] and mode!='baseline' else 0
            load=f'\t{op} t0, {offset}(t0)'
            assert load in b,(mode,item,'missing expected load')
            normalized=load+'\n\tslli t0, t0, 32\n\tsrli t0, t0, 32'
            assert (normalized in b)==(kind in ['sb','sh','sw','w'] and width=='w'),(mode,item,'unexpected normalization')
        assert '\tslli t0, t0, 32\n\tsrli t0, t0, 32' in body('copy_narrow')
        report['modes'][mode]={'structural':'passed','execution':'not-run'}
        if execute:
            checked([cc,caller_object,asm,'-o',exe],True);checked([exe],True)
            report['modes'][mode]['execution']='passed'
            if mode=='optimized':
                # Signed instead of unsigned load must fail on the high-bit cases.
                # Corrupt a long result so later legitimate word narrowing cannot mask it.
                for label,name,old,new in [
                    ('signed-unsigned-word','load_uw_l_folded','\tlwu t0, 16(t0)','\tlw t0, 16(t0)'),
                    ('unsigned-signed-byte','load_sb_l_direct','\tlb t0, 0(t0)','\tlbu t0, 0(t0)')]:
                    original=body(name);assert old in original
                    damaged=text.replace(original,original.replace(old,new,1),1)
                    bad,badexe=case/(label+'.s'),case/label;bad.write_text(damaged)
                    checked([cc,caller_object,bad,'-o',badexe],True)
                    result=run([badexe],True);assert result.returncode==1,(label,result.returncode,result.stderr)
                    report['negative_controls'].append({'label':label,'exit':result.returncode,'status':'detected'})
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: {count} independent load/cast bit cases per mode, structural checks and {len(report["negative_controls"])} detected corruption controls; execution={execute}',flush=True)
    return report


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--compiler',type=Path,default=LCB);ap.add_argument('--work',type=Path)
    ap.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));ap.add_argument('--runner',default='')
    ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    execute=(platform.system()=='Linux' and platform.machine()=='riscv64') or bool(args.runner)
    if args.require_native:assert execute,'RV64 execution unavailable; supply --runner'
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside:cmd=shlex.split(args.cc)+cmd[1:] if cmd[0]==args.cc else shlex.split(args.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=120)
    if args.work:exercise(args.compiler.resolve(),args.work.resolve(),run,args.cc,execute=execute)
    else:
        with tempfile.TemporaryDirectory(prefix='lcb-rv-load-') as directory:
            exercise(args.compiler.resolve(),Path(directory),run,args.cc,execute=execute)


if __name__=='__main__':main()
