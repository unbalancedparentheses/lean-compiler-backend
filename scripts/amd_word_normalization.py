#!/usr/bin/env python3
"""AMD64 word operations checked with explicit widening and ABI controls."""
import argparse
import os
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB
from unused_environment import native_target
import json
from pathlib import Path
from rv_immediates import fixture as binary_fixture, SEEDS


def fixture():
    ir,c=binary_fixture()
    extra=[];decl=[];checks=[]
    def case(name,body,expected,arg='l %x',carg='uint64_t',actual='x'):
        extra.append(f'export function l ${name}({arg}) {{\n@s\n {body}\n %r =l extuw %v\n ret %r\n}}\n')
        decl.append(f'extern uint64_t {name}({carg});\n')
        checks.append(f'if({name}({actual})!=({expected}))return 2;\n')
    case('word_copy','%v =w copy %x','(uint32_t)x')
    case('word_cast','%v =w cast %x','(uint32_t)x',arg='s %x',carg='float',actual='bits.f')
    for op,expr in [('neg','(uint32_t)(0-(uint32_t)x)'),('extsb','(uint32_t)((x&255)^128)-128U'),('extub','x&255'),('extsh','(uint32_t)((x&65535)^32768)-32768U'),('extuh','x&65535')]:
        case('unary_'+op,f'%v =w {op} %x',f'(uint32_t)({expr})')
    for op,expr in [('loadsb','(uint32_t)((x&255)^128)-128U'),('loadub','x&255'),('loadsh','(uint32_t)((x&65535)^32768)-32768U'),('loaduh','x&65535'),('loadsw','(uint32_t)x'),('loaduw','(uint32_t)x'),('loadw','(uint32_t)x')]:
        case(op,f'%v =w {op} %x',f'(uint32_t)({expr})',actual='(uintptr_t)&x')
    extra.append('export data $object = { l 9 }\nexport thread data $tls_object = { l 7 }\n')
    decl += ['extern uint64_t object; extern __thread uint64_t tls_object;\n']
    case('symbol_word','%v =w copy $object','(uint32_t)(uintptr_t)&object',arg='',carg='void',actual='')
    case('tls_word','%v =w copy thread $tls_object','(uint32_t)(uintptr_t)&tls_object',arg='',carg='void',actual='')
    extra.append('export function l $dirty_direct() {\n@s\n %v =w call $dirty()\n %r =l extuw %v\n ret %r\n}\n')
    extra.append('export function l $dirty_indirect(l %fn) {\n@s\n %v =w call %fn()\n %r =l extuw %v\n ret %r\n}\n')
    decl += ['extern uint64_t dirty_direct(void),dirty_indirect(uintptr_t);extern uint64_t dirty(void);\n']
    case('unsigned_conversion','%v =w dtoui %x','(uint32_t)conversion_value',arg='d %x',carg='double',actual='conversion_value')
    c=c.replace('static const uint64_t seeds', ''.join(decl)+'static const uint64_t seeds')
    c=c.replace('int main(void){','int main(void){if(dirty_direct()!=UINT64_C(0x80000001)||dirty_indirect((uintptr_t)dirty)!=UINT64_C(0x80000001))return 4;')
    c=c.replace('uint64_t x=seeds[i];','uint64_t x=seeds[i];union {uint32_t u;float f;} bits;bits.u=(uint32_t)x;double conversion_value=(double)(uint32_t)x;')
    c=c.replace('}return 0;}',''.join(checks)+'}return 0;}')
    return ir+''.join(extra),c


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,qtarget=None):
    assert target in ['x86_64-linux','x86_64-macos']
    case=Path(work)/'amd-word-normalization';case.mkdir(parents=True,exist_ok=True)
    src,c=case/'input.ssa',case/'caller.c';ir,ct=fixture();src.write_text(ir);c.write_text(ct)
    prefix='_' if target.endswith('macos') else ''
    probe=case/'dirty.s';probe.write_text(f'.text\n.globl {prefix}dirty\n{prefix}dirty:\n movabsq $0xdeadbeef80000001,%rax\n ret\n')
    obj=case/'caller.o'
    if execute:
        r=run([cc,'-O2','-c',c,'-o',obj],True);assert r.returncode==0,r.stderr
    modes={}
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm,exe=case/(mode+'.s'),case/mode
        r=run([compiler,'--target',target,*flags,src,'-o',asm]);assert r.returncode==0,r.stderr
        text=asm.read_text()
        assert f'\tcall {prefix}dirty\n\tmovl %eax, %eax\n' in text, 'call normalization must remain'
        assert '\tcvttsd2siq %xmm0, %rax\n\tmovl %eax, %eax\n' in text, 'unsigned FP-to-word normalization must remain'
        modes[mode]='emitted'
        if execute:
            r=run([cc,obj,probe,asm,'-o',exe],True);assert r.returncode==0,r.stderr
            r=run([exe],True);assert r.returncode==0,(mode,r.returncode,r.stderr);modes[mode]='passed'
    if execute:
        asm,exe=case/'corrupt-call-result.s',case/'corrupt-call-result'
        text=(case/'baseline.s').read_text();start=text.index(prefix+'dirty_direct:');end=text.index('\tret',start)
        body=text[start:end];changed=body.replace('\tmovl %eax, %eax\n','\txorl %eax, %eax\n',1);assert changed!=body
        asm.write_text(text[:start]+changed+text[end:])
        r=run([cc,obj,probe,asm,'-o',exe],True);assert r.returncode==0,r.stderr
        r=run([exe],True);assert r.returncode==4,'corrupted call result escaped C oracle'
    # Unchanged QBE reference checks the independent arithmetic subset only.
    qcount=0
    if execute and qbe:
        qi,qc=binary_fixture(True);qsrc,qcaller=case/'qbe-input.ssa',case/'qbe-caller.c';qsrc.write_text(qi);qcaller.write_text(qc)
        qasm,qexe=case/'qbe.s',case/'qbe';r=run([qbe,'-t',qtarget,'-o',qasm,qsrc],True);assert r.returncode==0,r.stderr
        r=run([cc,qcaller,qasm,'-o',qexe],True);assert r.returncode==0,r.stderr
        r=run([qexe],True);assert r.returncode==0,r.stderr;qcount=qi.count('export function')*len(SEEDS)
    report={'target':target,'modes':modes,'binary_checks_per_mode':576*len(SEEDS) if execute else 0,'additional_checks_per_mode':17*len(SEEDS)+2 if execute else 0,'call_result_corruption_detected':execute,'qbe_arithmetic_checks':qcount,'qbe_profile':'arithmetic/bitwise constants and legal immediate shifts only; C independently checks all LCB cases, including extra narrowing/ABI/TLS controls'}
    (case/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True);return report


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    target=native_target();execute=target in ['x86_64-linux','x86_64-macos']
    if args.require_native:assert execute,'AMD64 native target required'
    target=target if execute else 'x86_64-linux'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-unused-env-var-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=None
        if execute:
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            r=run(['make','-C',oracle,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr;qbe=oracle/'qbe'
        exercise(LCB,work,run,cc,target,execute,qbe,'amd64_apple' if target.endswith('macos') else 'amd64_sysv')


if __name__=='__main__':main()
