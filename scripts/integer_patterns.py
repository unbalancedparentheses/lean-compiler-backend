#!/usr/bin/env python3
"""Bounded 64-bit decimal magnitudes: independent C bits, layout and size checks."""
import argparse,hashlib,json,os,re,shlex,subprocess
from pathlib import Path
from data_relocations import native_host,QBE_TARGET
from fuzz import LCB

U64=(1<<64)-1
VALUES=[-U64,-U64+1,-U64+7,-(1<<63)-1,-(1<<63),-1,0,1,(1<<63)-1,1<<63,U64]
def wrapped(n):return str(n-(1<<64))
def fixture():
    source='dbgfile "integer-patterns.c"\n'
    source+=f'type :record = align {wrapped(8)} {{ b {wrapped(3)} }}\ntype :opaque = align {wrapped(8)} {{ {wrapped(8)} }}\n'
    expected=[];fields=[]
    for kind,width in [('b',1),('h',2),('w',4),('l',8)]:
        fields.append(kind+' '+' '.join(map(str,VALUES)))
        for v in VALUES:expected+=list((v% (1<<(width*8))).to_bytes(width,'little'))
    source+=f'export data $bytes = align {wrapped(8)} {{ '+', '.join(fields)+f', z {wrapped(3)}, b 167 }}\n'
    expected += [0,0,0,167]
    source+='export data $anchor = { z 16 }\n'
    source+=f'export data $plus = {{ l $anchor + {wrapped(1)} }}\nexport data $minus = {{ l $anchor + {U64} }}\n'
    names=[]
    for i,v in enumerate(VALUES):
        for width,bits in [('w',32),('l',64)]:
            name=f'value_{width}_{i}';source+=f'export function {width} ${name}() {{\n@start\n ret {v}\n}}\n';names.append((name,bits,v% (1<<bits)))
    source+=f'''export function l $size_check() {{
@start
 dbgloc {wrapped(1)}, {wrapped(2)}
 %src =l alloc8 {wrapped(8)}
 %dst =l alloc8 {wrapped(8)}
 storeb 93, %src
 storel 0, %dst
 blit %src, %dst, {wrapped(1)}
 %v =l load %dst
 ret %v
}}
export function w $record_check(:record %p) {{
@start
 %q =l add %p, 2
 %v =w loadub %q
 ret %v
}}
export function l $call_check() {{
@start
 %v =l call $echo(l {wrapped(1)})
 ret %v
}}
export function s $single_bits() {{
@start
 ret {wrapped(1)}
}}
export function d $double_bits() {{
@start
 ret {wrapped(1)}
}}
export function l $reloc_check() {{
@start
 %p =l load $plus
 %m =l load $minus
 %delta =l sub %p, %m
 ret %delta
}}
'''
    caller='#include <stdint.h>\n#include <stdio.h>\n#include <string.h>\n'
    caller+='extern unsigned char bytes[],anchor[];extern uintptr_t plus,minus;extern uint64_t size_check(void),call_check(void),reloc_check(void);extern float single_bits(void);extern double double_bits(void);\n'
    caller+='struct record {_Alignas(8) unsigned char b[3];};extern unsigned record_check(struct record);uint64_t echo(uint64_t x){return x;}\n'
    caller+=''.join(f'extern uint{bits}_t {name}(void);\n' for name,bits,_ in names)
    caller+='static const unsigned char expected[]={'+','.join(map(str,expected))+'};\nint main(void){\n'
    caller+='for(unsigned i=0;i<sizeof expected;i++)if(bytes[i]!=expected[i])return 1;\n'
    caller+=''.join(f'if({name}()!=UINT{bits}_C({v}))return 2;\n' for name,bits,v in names)
    caller+='if(plus!=(uintptr_t)anchor+1||minus!=(uintptr_t)anchor-1||reloc_check()!=2)return 3;\n'
    caller+='if(size_check()!=93||call_check()!=1||record_check((struct record){{17,29,193}})!=193)return 4;\n'
    caller+='float f=single_bits();double d=double_bits();uint32_t fb;uint64_t db;memcpy(&fb,&f,4);memcpy(&db,&d,8);if(fb!=1||db!=1)return 5;puts("integer patterns passed");return 0;}\n'
    return source,caller,names,len(expected)

def exercise(compiler,work,run,cc,target,execute=True,qbe=None):
    work=Path(work);work.mkdir(parents=True,exist_ok=True);text,c,names,bytecount=fixture();src=work/'input.ssa';src.write_text(text);caller=work/'caller.c';caller.write_text(c);commands=[];results=[]
    def invoke(cmd,inside=False):
        cmd=list(map(str,cmd));p=run(cmd,inside=inside);commands.append(dict(command=cmd,inside=inside,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr));return p
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    assert invoke([compiler,'--check',src]).returncode==0,commands[-1]
    # External echo cannot execute in the interpreter; evaluate separate closed functions.
    for name,_,expected in names+[('size_check',64,93),('reloc_check',64,2)]:
        p=invoke([compiler,'--eval',src,name]);assert p.returncode==0 and p.stdout.strip()==str(expected),commands[-1]
    for backend,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('original-qbe',None)] if qbe else []):
        asm=work/(backend+'.s');exe=work/backend
        cmd=[qbe,'-t',QBE_TARGET[target],'-o',asm,src] if flags is None else [compiler,'--target',target,*flags,src,'-o',asm]
        assert invoke(cmd).returncode==0,commands[-1]
        row=dict(backend=backend,assembly_sha256=sha(asm),qualified=False)
        if flags is not None:
            content=asm.read_text();assert ('anchor+1' in content and 'anchor-1' in content)
            assert re.search(r'\.loc [0-9]+ 1 2',content)
        if execute:
            p=invoke([*cc,caller,asm,'-o',exe],True);row['default_link']=commands[-1];row['link_profile']='default'
            if p.returncode:
                assert backend=='original-qbe' and target=='riscv64-linux' and 'R_RISCV_HI20' in p.stderr,commands[-1]
                assert invoke([*cc,caller,asm,'-no-pie','-o',exe],True).returncode==0,commands[-1];row['explicit_no_pie_link']=commands[-1];row['link_profile']='explicit-no-pie-reference-only'
            p=invoke([exe],True);row['execution']=commands[-1];assert p.returncode==0,commands[-1];row['qualified']=True
        results.append(row)
    invalid={
      'positive_overflow':'function l $f(){@s ret 18446744073709551616}',
      'negative_overflow':'function l $f(){@s ret -18446744073709551616}',
      'data_overflow':'data $x={l -18446744073709551616}',
      'addend_overflow':'data $x={l $x+-18446744073709551616}',
      'bad_number':'data $x={l -18446744073709551615oops}',
      'zero_negative':'data $x={z -1}',
      'alignment_negative':'data $x=align -1 {b 0}',
      'repetition_negative':'type :t={b -1}',
      'opaque_negative':'type :t=align 8 {-1}',
      'type_alignment_negative':'type :t=align -1 {b}',
      'debug_negative':'dbgfile "a" function $f(){@s dbgloc -1 ret}',
      'data_size_limit':'data $x={z 268435457}',
      'aggregate_size_limit':'type :t={b 1048577}',
    }
    for name,s in invalid.items():
        p=work/(name+'.ssa');p.write_text(s);assert invoke([compiler,'--check',p]).returncode!=0,commands[-1]
    control=None
    if execute:
        wrong=work/'wrong.ssa';wrong.write_text(text.replace('ret '+wrapped(1)+'\n','ret 2\n',1));asm=work/'wrong.s';exe=work/'wrong'
        assert invoke([compiler,'--target',target,wrong,'-o',asm]).returncode==0
        assert invoke([*cc,caller,asm,'-o',exe],True).returncode==0
        assert invoke([exe],True).returncode!=0;control=commands[-1]
    report=dict(target=target,compiler_identity=invoke([compiler,'--build-identity']).stdout.strip(),compiler_sha256=sha(compiler),qbe_sha256=sha(qbe) if qbe else None,source_sha256=sha(src),caller_sha256=sha(caller),byte_checks=bytecount,value_checks=len(names),interpreter_checks=len(names)+2,negative_cases=len(invalid),results=results,control=control,commands=commands,note='Bounded decimal magnitudes <=UINT64_MAX only. Original QBE unchanged; RV reference-only non-PIE retry separately recorded.')
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: bounded integer bit patterns: {bytecount} byte checks, {len(names)} value checks, {len(names)+2} interpreter checks, {len(invalid)} refusals; execution={execute}',flush=True)
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--work',type=Path,default=Path('.build/integer-patterns'));p.add_argument('--target',choices=QBE_TARGET,default=native_host());p.add_argument('--cc',default=os.environ.get('LCB_CC',os.environ.get('CC','cc')));p.add_argument('--runner',default='');p.add_argument('--qbe',type=Path);p.add_argument('--require-native',action='store_true');p.add_argument('--no-execute',action='store_true');a=p.parse_args();execute=not a.no_execute and (a.target==native_host() or bool(a.runner));assert not a.require_native or execute
    def run(cmd,inside=False):
        if inside and len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(cmd,text=True,capture_output=True,timeout=120)
    r=exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe.resolve() if a.qbe else None);print(a.target,sum(x['qualified'] for x in r['results']),len(r['results']))
if __name__=='__main__':main()
