#!/usr/bin/env python3
"""Ordinary ELF SHF_EXCLUDE: exact object metadata and independent linker controls."""
import argparse,hashlib,itertools,json,os,shlex,subprocess
from pathlib import Path
from data_relocations import native_host,QBE_TARGET
from elf_section_names import ELF_READ
from fuzz import LCB

FLAGS=[''.join(c for c,b in zip('awxR',bits) if b)+'e' for bits in itertools.product([False,True],repeat=4)]+['eRawx','ee']
MASK={'a':2,'w':1,'x':4,'R':0x200000,'e':0x80000000}
C='extern long kept; extern int ordinary(void); int main(void){return kept!=41 || ordinary()!=42;}\n'
REF='extern long metadata8; extern int excluded_function(void); int main(void){return metadata8!=81 || excluded_function()!=17;}\n'

def fixture(excluded=True):
    lines=[];wanted={}
    for i,flags in enumerate(FLAGS):
        flags=flags if excluded else flags.replace('e','')
        name=f'.lcb_exclude_{i}'
        lines.append(f'section "{name}" "{flags}" export data $metadata{i} = align 8 {{ l {73+i} }}')
        wanted[name]=dict(flags=sum(MASK[c] for c in set(flags)),size=8)
    flags='axRe' if excluded else 'axR'
    lines += [f'section ".lcb_exclude_function" "{flags}" export function w $excluded_function() {{\n@s\n ret 17\n}}',
              'export data $kept = { l 41 }','export function w $ordinary() {\n@s\n ret 42\n}']
    wanted['.lcb_exclude_function']=dict(flags=sum(MASK[c] for c in set(flags)),size=None)
    return '\n'.join(lines)+'\n',wanted


def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
    work=Path(work)/'elf-exclude';work.mkdir(parents=True,exist_ok=True)
    cc=shlex.split(cc) if isinstance(cc,str) else list(map(str,cc));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();commands=[]
    def invoke(cmd,inside=False,ok=True):
        cmd=list(map(str,cmd));p=run(cmd,inside);commands.append(dict(command=cmd,inside=inside,exit=p.returncode,stdout=p.stdout,stderr=p.stderr));assert not ok or p.returncode==0,commands[-1];return p
    result={'target':target,'compiler_identity':invoke([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'helper_sha256':sha(__file__),'metadata_reader_sha256':hashlib.sha256(ELF_READ.encode()).hexdigest(),'rows':[],'controls':{},'execution':execute}
    modes=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])];apple=target.endswith('macos')
    caller=work/'caller.c';caller.write_text(C);reference=work/'reference.c';reference.write_text(REF)
    src=work/'excluded.ssa';src.write_text(fixture()[0]);removed=work/'without-e.ssa';removed.write_text(fixture(False)[0])
    ordinary=work/'ordinary.ssa';ordinary.write_text('export data $kept = { l 41 }\nexport function w $ordinary() {\n@s\n ret 42\n}\n')
    def metadata(obj,expected):
        rows=json.loads(invoke(['python3','-c',ELF_READ,obj],True).stdout);custom={bytes.fromhex(x['name']).decode():x for x in rows if bytes.fromhex(x['name']).startswith(b'.lcb_exclude_')};assert set(custom)==set(expected),(custom,expected)
        for name,want in expected.items():
            got=custom[name];assert got['flags']==want['flags'] and got['type']==1,(name,got,want)
            assert got['size']==want['size'] if want['size'] is not None else got['size']>0
        return custom
    for label,flags in modes:
        asm=work/('ordinary-'+label+'.s');invoke([compiler,ordinary,'--target',target,*flags,'-o',asm])
        if before:
            old=work/('ordinary-'+label+'-before.s');invoke([before,ordinary,'--target',target,*flags,'-o',old]);assert asm.read_bytes()==old.read_bytes()
        if apple:
            assert invoke([compiler,src,'--target',target,*flags,'-o',work/'apple-invalid.s'],ok=False).returncode!=0
            literal=work/'apple-literal.ssa';literal.write_text('section "__DATA" "e" export data $literal = { l 7 }\n');asm=work/('apple-literal-'+label+'.s');invoke([compiler,literal,'--target',target,*flags,'-o',asm])
            if before:
                old=work/('apple-literal-'+label+'-before.s');invoke([before,literal,'--target',target,*flags,'-o',old]);assert asm.read_bytes()==old.read_bytes()
            continue
    if not apple:
        if before:assert invoke([before,src,'--target',target,'-o',work/'before.s'],ok=False).returncode!=0
        for label,flags in modes+([('qbe',None)] if execute and qbe else []):
            for excluded,path in [(True,src),(False,removed)]:
                suffix=label+('-excluded' if excluded else '-without-e');asm=work/(suffix+'.s');obj=work/(suffix+'.o');exe=work/suffix
                invoke([qbe,'-t',QBE_TARGET[target],'-o',asm,path],True) if flags is None else invoke([compiler,path,'--target',target,*flags,'-o',asm])
                if before and not excluded and flags is not None:
                    old=work/(suffix+'-before.s');invoke([before,path,'--target',target,*flags,'-o',old]);assert old.read_bytes()==asm.read_bytes()
                row={'mode':label,'excluded':excluded,'assembly_sha256':sha(asm),'executed':False}
                if execute:
                    invoke([*cc,'-c',asm,'-o',obj],True);row['object_sections']=metadata(obj,fixture(excluded)[1])
                    invoke([*cc,caller,obj,'-o',exe],True);linked=json.loads(invoke(['python3','-c',ELF_READ,exe],True).stdout);names={bytes.fromhex(x['name']).decode() for x in linked};expected=set(fixture()[1]);assert not (expected&names) if excluded else expected<=names
                    invoke([exe],True);row['executed']=True;row['linked_custom_sections']=sorted(expected&names)
                    refexe=work/(suffix+'-referenced');p=invoke([*cc,reference,obj,'-o',refexe],True,False)
                    if excluded:assert p.returncode!=0 and 'metadata8' in p.stderr and 'excluded_function' in p.stderr
                    else:assert p.returncode==0,p.stderr;invoke([refexe],True)
                    row['referenced_profile']='expected-link-refusal' if excluded else 'passed'
                result['rows'].append(row)
        if execute:
            # Removing e from only one section must be detected by the exact object oracle.
            text=fixture()[0].replace('"e"','""',1);bad=work/'missing-e.ssa';bad.write_text(text);asm=work/'missing-e.s';obj=work/'missing-e.o';invoke([compiler,bad,'--target',target,'-o',asm]);invoke([*cc,'-c',asm,'-o',obj],True)
            try:metadata(obj,fixture()[1])
            except AssertionError:result['controls']['missing_e']='detected'
            else:raise AssertionError('missing e mutation not detected')
            bad.write_text(fixture()[0].replace('$kept = { l 41 }','$kept = { l 40 }'));asm=work/'wrong-kept.s';exe=work/'wrong-kept';invoke([compiler,bad,'--target',target,'-o',asm]);invoke([*cc,caller,asm,'-o',exe],True);assert invoke([exe],True,False).returncode==1;result['controls']['wrong_kept']='detected'
    for i,(flags,tls) in enumerate([('eT',False),('eG',False),('eM',False),('eS',False),('e,extra',False),('e\\n',False),('awTe',True),('awTRe',True)]):
        p=work/f'invalid-{i}.ssa';p.write_text(f'section ".invalid" "{flags}" '+('thread ' if tls else '')+'data $x = { l 1 }\n')
        for label,options in modes:assert invoke([compiler,p,'--target',target,*options,'-o',work/'invalid.s'],ok=False).returncode!=0
    result['negative_cases']=24;result['source_hashes']={p.name:sha(p) for p in [src,removed,caller,reference,ordinary]};result['commands']=commands
    (work/'report.json').write_text(json.dumps(result,indent=2)+'\n');return result


def main():
    import tempfile
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--before',type=Path);p.add_argument('--target');p.add_argument('--cc',default=os.environ.get('LCB_CC','cc'));p.add_argument('--qbe',type=Path);p.add_argument('--emission-only',action='store_true');p.add_argument('--require-native',action='store_true');a=p.parse_args();target=a.target or native_host() or 'aarch64-macos';execute=not a.emission_only and target==native_host()
    if a.require_native:assert execute,'native target required'
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    with tempfile.TemporaryDirectory(prefix='lcb-elf-exclude-') as d:print(json.dumps(exercise(a.compiler.resolve(),Path(d),run,a.cc,target,execute,a.qbe,a.before),indent=2))
if __name__=='__main__':main()
