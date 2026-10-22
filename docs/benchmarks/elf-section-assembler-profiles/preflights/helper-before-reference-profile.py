#!/usr/bin/env python3
"""Printable ELF section names: explicit GNU/LLVM byte profiles and quoting isolation."""
import argparse,hashlib,json,os,shlex,subprocess
from pathlib import Path
from data_relocations import native_host,QBE_TARGET
from fuzz import LCB

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def quote(s):return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
BASE=['','plain','space name','colon:name','slash/name','plus+name','at@name','quote"name','back\\name','literal\\n','x"; .globl injected; #','x\\"; .section injected; #',''.join(chr(i) for i in range(32,127)),'x'*127]

def fixture():
    lines=[];checks=[];decl=[];expected={};symbols=[]
    for i,base in enumerate(BASE):
        d='d'+base;f='f'+base;value=37+i
        lines.extend([f'section {quote(d)} "aw" export data $value{i} = {{ l {value} }}',f'section {quote(f)} "ax" export function l $get{i}() {{\n@s\n %v =l loadl $value{i}\n ret %v\n}}'])
        expected[d.encode().hex()]=3;expected[f.encode().hex()]=6
        decl.append(f'extern uint64_t value{i},get{i}(void);');checks.append(f'if(value{i}!={value}||get{i}()!={value})return {i+1};')
        symbols += [f'value{i}',f'get{i}']
    # Equivalent decoded spellings share exactly one custom data section.
    for i,name in enumerate(['"d space"',r'"d\040space"',r'"d\x20space"']):
        lines.append(f'section {name} "aw" export data $equiv{i} = {{ l {91+i} }}');decl.append(f'extern uint64_t equiv{i};');checks.append(f'if(equiv{i}!={91+i})return 80;');symbols.append(f'equiv{i}')
    expected[b'd space'.hex()]=3
    caller='#include <stdint.h>\n'+''.join(decl)+'\nint main(void){'+''.join(checks)+'return 0;}\n'
    return '\n'.join(lines)+'\n',caller,expected,sorted(symbols)

ELF_READ='''import struct,json,sys
b=open(sys.argv[1],'rb').read();assert b[:6]==b'\\x7fELF\\x02\\x01'
o=struct.unpack_from('<Q',b,40)[0];s,n,k=struct.unpack_from('<HHH',b,58)
h=[struct.unpack_from('<IIQQQQIIQQ',b,o+i*s) for i in range(n)];t=h[k];names=b[t[4]:t[4]+t[5]]
print(json.dumps([{'name':names[x[0]:names.index(b'\\0',x[0])].hex(),'flags':x[2],'type':x[1],'size':x[5]} for x in h]))
'''
ORDINARY='section "foo,bar" "aw" export data $ordinary = { l 31 }\nexport function l $get_ordinary() {\n@s\n %v =l loadl $ordinary\n ret %v\n}\n'
APPLE='section "__DATA,__safe" export data $ordinary = { l 31 }\nexport function l $get_ordinary() {\n@s\n %v =l loadl $ordinary\n ret %v\n}\n'

def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
    work=Path(work)/'elf-section-names';work.mkdir(parents=True,exist_ok=True);cc=list(cc) if isinstance(cc,(list,tuple)) else [cc];commands=[];rows=[];controls=[];apple=target.endswith('macos')
    def invoke(cmd,inside=False,ok=True):
        cmd=list(map(str,cmd));p=run(cmd,inside);commands.append(dict(command=cmd,inside=inside,exit=p.returncode,stdout=p.stdout,stderr=p.stderr))
        if ok:assert p.returncode==0,commands[-1]
        return p
    identity=invoke([compiler,'--build-identity']).stdout.strip();text,c,expected,names=fixture();decoded_expected=expected.copy();profile={'name':'not measured: emission/refusal only'};src=work/'input.ssa';src.write_text(text);caller=work/'caller.c';caller.write_text(c)
    ordinary=work/'ordinary.ssa';ordinary.write_text(APPLE if apple else ORDINARY)
    modes=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]
    for label,flags in modes:
        asm=work/(label+'-ordinary.s');invoke([compiler,ordinary,'--target',target,*flags,'-o',asm])
        if before:
            old=work/(label+'-ordinary-before.s');invoke([before,ordinary,'--target',target,*flags,'-o',old]);assert asm.read_bytes()==old.read_bytes()
    if execute and not apple:
        # Independent fixed assembly distinguishes the two supported assembler
        # string conventions. Never derive expected fixture names from LCB output.
        decoded='lcb"probe\\tail'
        escaped=decoded.replace('\\','\\\\').replace('"','\\"')
        probe=work/'assembler-profile.s';probe.write_text('.section '+quote(decoded)+',"aw"\n.byte 1\n')
        obj=work/'assembler-profile.o';invoke([*cc,'-c',probe,'-o',obj],True)
        probe_rows=json.loads(invoke(['python3','-c',ELF_READ,obj],True).stdout)
        choices={decoded.encode().hex():'GNU-decoded',escaped.encode().hex():'LLVM-literal'}
        matches=[row for row in probe_rows if row['name'] in choices]
        assert len(matches)==1 and matches[0]['flags']==3 and matches[0]['type']==1 and matches[0]['size']==1, ('unknown assembler section-name profile',probe_rows)
        profile={'name':choices[matches[0]['name']], 'probe_source_sha256':sha(probe),'probe_object_sha256':sha(obj),'section':matches[0]}
        if profile['name']=='LLVM-literal':
            expected={bytes.fromhex(name).decode('ascii').replace('\\','\\\\').replace('"','\\"').encode().hex():flags for name,flags in expected.items()}
    def metadata(obj):
        result=json.loads(invoke(['python3','-c',ELF_READ,obj],True).stdout)
        matched=[x for x in result if x['name'] in expected]
        assert len(matched)==len(expected), 'duplicate or missing custom section header'
        actual={x['name']:x for x in matched};assert set(actual)==set(expected),(actual.keys(),expected.keys())
        for name,flags in expected.items():assert actual[name]['flags']==flags and actual[name]['type']==1,(name,actual[name])
        ordinary_names={b''.hex(),b'.text'.hex(),b'.data'.hex(),b'.bss'.hex(),b'.note.GNU-stack'.hex(),b'.symtab'.hex(),b'.strtab'.hex(),b'.shstrtab'.hex()}
        if target=='riscv64-linux':
            attr=next(x for x in result if x['name']==b'.riscv.attributes'.hex())
            assert attr['type']==0x70000003 and attr['flags']==0,attr
            ordinary_names.add(b'.riscv.attributes'.hex())
        extra=[x for x in result if x['name'] not in expected and x['name'] not in ordinary_names and x['type'] not in [4,9]]
        assert not extra,extra
        output=invoke(['nm','-g','--defined-only',obj],True).stdout
        syms=sorted(x.split()[-1] for x in output.splitlines() if len(x.split())>=3);assert syms==names,syms
        return result
    if apple:
        for i,name in enumerate(['a b','a:b','a/b','a"b','a\\b']):
            bad=work/f'apple-{i}.ssa';bad.write_text(f'section {quote(name)} "aw" data $x = {{ l 1 }}\n')
            for label,flags in modes:assert invoke([compiler,bad,'--target',target,*flags,'-o',work/'bad.s'],ok=False).returncode!=0
        rows.append(dict(scope='Apple negative and ordinary fixture emission only',executed=False))
    else:
        for label,flags in modes+([('qbe',None)] if execute and qbe else []):
            asm=work/(label+'.s');obj=work/(label+'.o');exe=work/label
            invoke([qbe,'-t',QBE_TARGET[target],'-o',asm,src],True) if label=='qbe' else invoke([compiler,src,'--target',target,*flags,'-o',asm])
            row=dict(mode=label,executed=False)
            if execute:
                invoke([*cc,'-c',asm,'-o',obj],True);row['sections']=metadata(obj)
                invoke([*cc,caller,obj,'-o',exe],True);invoke([exe],True);row['executed']=True
            rows.append(row)
        if execute:
            wrong=work/'wrong-name.s';assembly=(work/'optimized.s').read_text();assert 'dplain' in assembly;wrong.write_text(assembly.replace('dplain','dwrong'));obj=work/'wrong-name.o';invoke([*cc,'-c',wrong,'-o',obj],True)
            try:metadata(obj)
            except AssertionError:controls.append('wrong exact section name detected')
            else:raise AssertionError('wrong name escaped exact section oracle')
            wrong=work/'wrong-value.s';assert '\t.quad 37' in assembly;wrong.write_text(assembly.replace('\t.quad 37','\t.quad 38'));exe=work/'wrong-value';invoke([*cc,caller,wrong,'-o',exe],True);assert invoke([exe],True,False).returncode==1;controls.append('wrong value detected by C')
    # These decoded names remain invalid for the ELF grammar.
    invalid=['', 'x'*129, '\\000', '\\001', '\\011', '\\012', '\\015', '\\177', 'λ']
    if not apple:
        for i,name in enumerate(invalid):
            bad=work/f'invalid-{i}.ssa';bad.write_text(f'section "{name}" "aw" data $x = {{ l 1 }}\n')
            for label,flags in modes:assert invoke([compiler,bad,'--target',target,*flags,'-o',work/'bad.s'],ok=False).returncode!=0
        assert invoke([compiler,'--first-path',src],ok=False).returncode!=0
    qhash=None
    if execute and qbe and not apple:qhash=invoke(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
    report=dict(status='passed',target=target,compiler_identity=identity,compiler_sha256=sha(compiler),before_sha256=sha(before) if before else None,helper_sha256=sha(__file__),source_sha256=sha(src),caller_sha256=sha(caller),qbe_sha256=qhash,results=rows,controls=controls,executed_modes=sum(x['executed'] for x in rows),ordinary_equivalence='passed' if before else 'skipped: no before snapshot supplied',expected_names=expected,decoded_expected_names=decoded_expected,section_name_profile=profile,commands=commands,scope='14data/function name pairs +3equivalent spellings; exact29custom section names and31global symbols. PrintableASCII1..128 decoded input bytes. GNU assembler decodes quoted escapes; LLVM preserves them literally. A fixed independent assembly probe selects the exact expected object-name profile; both retain all31global symbols and C execution. Linux executes independentC; Apple unchanged fixture emission/negatives only. No timing claim.')
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--work',type=Path,default=Path('.build/elf-section-names'));p.add_argument('--target',choices=QBE_TARGET,default=native_host());p.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));p.add_argument('--qbe',type=Path);p.add_argument('--runner',default='');p.add_argument('--before',type=Path);p.add_argument('--emission-only','--no-execute',action='store_true');p.add_argument('--require-native',action='store_true');a=p.parse_args();execute=not a.emission_only and (a.target==native_host() or bool(a.runner));assert not a.require_native or execute
    def run(cmd,inside=False):
        if inside and len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    r=exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe,a.before);print(a.target,'ELF names passed; executed modes',r['executed_modes'])
if __name__=='__main__':main()
