#!/usr/bin/env python3
"""Independent byte and TLS oracles for hexadecimal strings and symbol annotations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
from data_relocations import QBE_TARGET, native_host
from fuzz import LCB


def fixtures():
    literals = []; expected = []
    for i in range(256):
        digits = format(i, 'X' if i % 2 else 'x')
        literals.append('"\\x' + digits + '"'); expected.append(i)
    for digits in ['0', '00', '1ff', '1234', 'f'*16, 'F'*17, '123456789abcdef'*40]:
        literals.append('"\\x' + digits + '"'); expected.append(int(digits,16) % 256)
    literals += ['"\\x41Z"', '"\\000\\001\\077\\177\\377"', '"\\n\\r\\t\\b\\f\\013\\007\\\\\\\""', '"ASCII !#$%&()*+,-./:;<=>?@[]^_`{|}~"']
    expected += [65,90,0,1,63,127,255,10,13,9,8,12,11,7,92,34] + list(b'ASCII !#$%&()*+,-./:;<=>?@[]^_`{|}~')
    source='export data $bytes = { b '+' '.join(literals)+' }\n'
    source+='export function w $byte_at(l %i) {\n@start\n %p =l add $bytes, %i\n %v =w loadub %p\n ret %v\n}\n'
    caller='#include <stdint.h>\n#include <stdio.h>\nextern unsigned char bytes[]; extern unsigned byte_at(uint64_t);\n'
    caller+='static const unsigned char expected[]={'+','.join(map(str,expected))+'};\n'
    caller+='int main(void){for(unsigned i=0;i<sizeof expected;i++)if(bytes[i]!=expected[i]||byte_at(i)!=expected[i])return 1;puts("hex bytes passed");return 0;}\n'
    ann='export thread data $tls_value = { l 42 }\nexport data $ordinary = { l 19 }\n'
    cases=[('plain','extern extern', 'ordinary'),('tls_first','thread extern','tls_value'),('tls_last','extern thread','tls_value'),('tls_repeat','thread extern thread extern','tls_value'),('tls_only','thread thread','tls_value')]
    for name,tags,symbol in cases:
        ann+=f'export function l ${name}() {{\n@start\n %p =l copy {tags} ${symbol}\n %v =l load %p\n ret %v\n}}\n'
    ac='#include <stdint.h>\n#include <stdio.h>\nextern _Thread_local uint64_t tls_value;extern uint64_t ordinary;\n'
    ac+=''.join(f'extern uint64_t {name}(void);\n' for name,_,_ in cases)
    ac+='int main(void){for(unsigned i=0;i<5;i++){uint64_t want=42+193*i;tls_value=want;ordinary=19+i;'
    ac+='if(plain()!=ordinary||'+'||'.join(name+'()!=want' for name,_,_ in cases[1:])+')return 1;}puts("annotations passed");return 0;}\n'
    return {'hex':(source,caller,len(expected)), 'annotations':(ann,ac,25)}


def exercise(compiler, work, run, cc, target, execute=True, qbe=None):
    work=Path(work);work.mkdir(parents=True,exist_ok=True);commands=[];results=[];controls=[]
    def invoke(cmd,inside=False):
        cmd=list(map(str,cmd));p=run(cmd,inside=inside)
        row=dict(command=cmd,inside=inside,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr);commands.append(row);return p
    sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    cases=fixtures()
    for case,(text,c,number) in cases.items():
        source=work/(case+'.ssa');source.write_text(text);caller=work/(case+'.c');caller.write_text(c)
        assert invoke([compiler,'--check',source]).returncode==0,commands[-1]
        if case=='hex':
            # Independently compare interpreter loads at byte/escape boundaries.
            for i,want in [(0,0),(65,65),(255,255),(256,0),(258,255),(259,52),(260,255),(261,255)]:
                p=invoke([compiler,'--eval',source,'byte_at',i]);assert p.returncode==0 and p.stdout.strip()==str(want),commands[-1]
        for backend,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]+([('original-qbe',None)] if qbe else []):
            asm=work/f'{case}-{backend}.s';exe=work/f'{case}-{backend}'
            cmd=[qbe,'-t',QBE_TARGET[target],'-o',asm,source] if flags is None else [compiler,'--target',target,*flags,source,'-o',asm]
            p=invoke(cmd);row=dict(case=case,backend=backend,checks=number,source_sha256=sha(source),caller_sha256=sha(caller),emission=commands[-1],qualified=False)
            if p.returncode:
                assert backend=='original-qbe' and case=='annotations' and target in ('aarch64-linux','riscv64-linux') and 'extern thread unavailable' in p.stderr,commands[-1]
                results.append(row);continue
            row['assembly_sha256']=sha(asm)
            if execute:
                linked=invoke([*cc,caller,asm,'-o',exe],True)
                row['default_link']=commands[-1];row['link_profile']='default'
                if linked.returncode:
                    assert backend=='original-qbe' and target=='riscv64-linux' and 'R_RISCV_HI20' in linked.stderr,commands[-1]
                    assert invoke([*cc,caller,asm,'-no-pie','-o',exe],True).returncode==0,commands[-1]
                    row['explicit_no_pie_link']=commands[-1];row['link_profile']='explicit-no-pie-reference-only'
                p=invoke([exe],True);row['execution']=commands[-1];assert p.returncode==0,commands[-1];row['qualified']=True
            results.append(row)
        if execute:
            # Defined wrong source; verify the independent C oracle rejects it.
            mutant=work/f'{case}-wrong.ssa';wrong=work/f'{case}-wrong.s';exe=work/f'{case}-wrong'
            changed=text.replace('\\x0"','\\x1"',1) if case=='hex' else text.replace(' %v =l load %p',' %v =l copy -1',1)
            assert changed!=text;mutant.write_text(changed)
            assert invoke([compiler,'--target',target,mutant,'-o',wrong]).returncode==0
            assert invoke([*cc,caller,wrong,'-o',exe],True).returncode==0
            assert invoke([exe],True).returncode!=0;controls.append(commands[-1])
    invalid={'hex_empty':'data $x = { b "\\x" }','hex_bad':'data $x = { b "\\xG0" }',
             'bare_extern':'export function l $f() { @s ret extern }',
             'bare_thread':'export function l $f() { @s ret thread extern }',
             'unknown_annotation':'export function l $f() { @s ret thread unknown $x }'}
    for name,text in invalid.items():
        p=work/(name+'.ssa');p.write_text(text);assert invoke([compiler,'--check',p]).returncode!=0,commands[-1]
    report=dict(target=target,compiler_sha256=sha(compiler),compiler_identity=invoke([compiler,'--build-identity']).stdout.strip(),qbe_sha256=sha(qbe) if qbe else None,results=results,negative_cases=len(invalid),controls=controls,commands=commands,note='Original QBE unchanged. ARM/RV Linux extern-thread emitter refusals retained separately; not an executable pass. Hex digits consume through first nonhex character and reduce modulo256; one digit required. Existing octal range restriction unchanged.')
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'{target}: hexadecimal strings and annotation order: {sum(row["qualified"] for row in results)}/{len(results)} executable profiles; 314-byte and 25-annotation suites; 5 negative parses; execution={execute}',flush=True)
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--work',type=Path,default=Path('.build/syntax-edges'));p.add_argument('--target',choices=QBE_TARGET,default=native_host());p.add_argument('--cc',default=os.environ.get('LCB_CC',os.environ.get('CC','cc')));p.add_argument('--runner',default='');p.add_argument('--qbe',type=Path);p.add_argument('--require-native',action='store_true');p.add_argument('--no-execute',action='store_true');a=p.parse_args()
    execute=not a.no_execute and (a.target==native_host() or bool(a.runner));assert not a.require_native or execute
    def run(cmd,inside=False):
        if inside and len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(cmd,text=True,capture_output=True,timeout=120)
    r=exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe.resolve() if a.qbe else None);print(a.target,sum(x['qualified'] for x in r['results']),len(r['results']))
if __name__=='__main__':main()
