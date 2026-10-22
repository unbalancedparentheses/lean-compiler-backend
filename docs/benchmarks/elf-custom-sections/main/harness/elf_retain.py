#!/usr/bin/env python3
"""ELF GNU retain sections: linker-GC survival without creating oracle roots."""
import argparse,hashlib,json,os,shlex,subprocess
from pathlib import Path
from data_relocations import native_host,QBE_TARGET
from fuzz import LCB
IR='section ".lcb.keep_rw" "awR" export data $keep_rw = { l 37 }\nsection ".lcb.keep_ro" "aR" export data $keep_ro = { l 83 }\nsection ".lcb.drop_data" "aw" export data $drop_data = { l 99 }\nsection ".lcb.ref_data" "aw" export data $ref_data = { l 19 }\nsection ".lcb.keep_code" "axR" export function l $keep_code() {\n@s\n ret 71\n}\nsection ".lcb.drop_code" "ax" export function l $drop_code() {\n@s\n ret 101\n}\nsection ".lcb.ref_code" "ax" export function l $anchor() {\n@s\n ret 17\n}\n'
C='#include <stdint.h>\n#include <stdlib.h>\nextern uint64_t anchor(void),ref_data;\nint main(int argc,char**argv){if(argc!=4||anchor()!=17||ref_data!=19)return 1;\n uintptr_t base=(uintptr_t)&anchor;\n volatile uint64_t *a=(volatile uint64_t*)(base+(uintptr_t)strtoll(argv[1],0,10));\n volatile uint64_t *b=(volatile uint64_t*)(base+(uintptr_t)strtoll(argv[2],0,10));\n uint64_t(*f)(void)=(uint64_t(*)(void))(base+(uintptr_t)strtoll(argv[3],0,10));\n return *a!=37||*b!=83||f()!=71;}\n'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def symbols(text):
    out={}
    for line in text.splitlines():
        parts=line.split()
        if len(parts)==3:
            try:out[parts[2]]=int(parts[0],16)
            except ValueError:pass
    return out

def metadata(text):
    found={}
    for name,expected in [('.lcb.keep_rw','WAR'),('.lcb.keep_ro','AR'),('.lcb.keep_code','AXR'),('.lcb.drop_data','WA'),('.lcb.drop_code','AX'),('.lcb.ref_data','WA'),('.lcb.ref_code','AX')]:
        line=next(x for x in text.splitlines() if name in x)
        flags=line.split()[-4];assert set(flags)==set(expected),(name,flags,expected);found[name]=flags
    return found

KEEP=['keep_rw','keep_ro','keep_code']
DROP=['drop_data','drop_code']
def linked(text):
    syms=symbols(text)
    assert all(x in syms for x in KEEP+['anchor','ref_data']),syms
    assert all(x not in syms for x in DROP),syms
    return [str(syms[x]-syms['anchor']) for x in KEEP]

def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
    work=Path(work)/'elf-retain';work.mkdir(parents=True,exist_ok=True);cc=list(cc) if isinstance(cc,(list,tuple)) else [cc];commands=[];rows=[];controls=[]
    def invoke(cmd,inside=False,ok=True):
        cmd=list(map(str,cmd));r=run(cmd,inside);commands.append(dict(command=cmd,inside=inside,exit=r.returncode,stdout=r.stdout,stderr=r.stderr))
        if ok:assert r.returncode==0,commands[-1]
        return r
    source=work/'input.ssa';source.write_text(IR);caller=work/'caller.c';caller.write_text(C);identity=invoke([compiler,'--build-identity']).stdout.strip();apple=target.endswith('macos')
    modes=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]
    if not apple and execute and qbe:modes.append(('qbe',None))
    def emit(label,flags,src,asm):
        return invoke([qbe,'-t',QBE_TARGET[target],'-o',asm,src],True) if label=='qbe' else invoke([compiler,src,'--target',target,*flags,'-o',asm])
    for label,flags in modes:
        asm=work/(label+'.s');obj=work/(label+'.o');exe=work/label;emit(label,flags,source,asm)
        row=dict(mode=label,execution='not-run')
        if apple:
            # These two fields are segment and literal section name on Apple, not ELF flags.
            if before:
                old=work/(label+'-before.s');invoke([before,source,'--target',target,*flags,'-o',old]);assert asm.read_bytes()==old.read_bytes();row['before_byte_equal']=True
            row['scope']='Apple grammar emission only; R in second field is a literal name, no retention claim'
        elif execute:
            invoke([*cc,'-c',asm,'-o',obj],True);row['metadata']=metadata(invoke(['readelf','-SW',obj],True).stdout)
            invoke([*cc,caller,obj,'-Wl,--gc-sections','-o',exe],True);args=linked(invoke(['nm','-n','--defined-only',exe],True).stdout);invoke([exe,*args],True);row.update(execution='passed',runtime_offsets=args)
        rows.append(row)
    if execute and not apple:
        # A flag-removal control must lose both metadata and all unreferenced symbols.
        for label,flags in [('optimized',['--optimize'])]+([('qbe',None)] if qbe else []):
            bad=work/(label+'-noR.ssa');bad.write_text(IR.replace('awR','aw').replace('aR','a').replace('axR','ax'));asm=work/(label+'-noR.s');obj=work/(label+'-noR.o');exe=work/(label+'-noR');emit(label,flags,bad,asm)
            invoke([*cc,'-c',asm,'-o',obj],True)
            try:metadata(invoke(['readelf','-SW',obj],True).stdout)
            except AssertionError:pass
            else:raise AssertionError('removed retain flag escaped object oracle')
            invoke([*cc,caller,obj,'-Wl,--gc-sections','-o',exe],True);text=invoke(['nm','-n','--defined-only',exe],True).stdout;syms=symbols(text);assert all(x not in syms for x in KEEP)
            try:linked(text)
            except AssertionError:pass
            else:raise AssertionError('removed retain flag escaped linked-symbol oracle')
            controls.append(dict(mode=label,control='removedR detected in metadata and linked symbols'))
        bad=work/'wrong-value.ssa';bad.write_text(IR.replace('{ l 37 }','{ l 38 }'));asm=work/'wrong-value.s';exe=work/'wrong-value';emit('optimized',['--optimize'],bad,asm);invoke([*cc,caller,asm,'-Wl,--gc-sections','-o',exe],True);args=linked(invoke(['nm','-n','--defined-only',exe],True).stdout);r=invoke([exe,*args],True,False);assert r.returncode==1;controls.append(dict(control='retained wrong value detected by C',exit=r.returncode))
    if not apple:
        for flags in ['aT','aG','aR,extra','aZ']:
            src=work/('bad-'+flags.replace(',','_')+'.ssa');src.write_text('section ".lcb.bad" "'+flags+'" data $bad = { l 1 }\n')
            assert invoke([compiler,src,'--target',target,'-o',work/'bad.s'],ok=False).returncode!=0
        if before:
            assert invoke([before,source,'--target',target,'-o',work/'before.s'],ok=False).returncode!=0
    assert invoke([compiler,'--first-path',source],ok=False).returncode!=0
    qhash=None
    if execute and qbe and not apple:qhash=invoke(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
    report=dict(status='passed',target=target,compiler_identity=identity,compiler_sha256=sha(compiler),helper_sha256=sha(__file__),source_sha256=sha(source),caller_sha256=sha(caller),before_sha256=sha(before) if before else None,qbe_sha256=qhash,results=rows,controls=controls,executed_modes=sum(r['execution']=='passed' for r in rows),commands=commands,scope='ELF R retention in default link profile with --gc-sections; C references only anchor and ref_data. Post-link numeric offsets create no linker roots. Apple emission/literal-name behavior only. No timing claim.')
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(target,'ELF retain checks passed; executed modes',report['executed_modes'],flush=True);return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,default=LCB);p.add_argument('--work',type=Path,default=Path('.build/elf-retain'));p.add_argument('--target',choices=QBE_TARGET,default=native_host());p.add_argument('--cc',default=os.environ.get('LCB_CC',os.environ.get('CC','cc')));p.add_argument('--runner',default='');p.add_argument('--qbe',type=Path);p.add_argument('--before',type=Path);p.add_argument('--require-native',action='store_true');p.add_argument('--emission-only','--no-execute',action='store_true');a=p.parse_args()
    execute=not a.emission_only and (a.target==native_host() or bool(a.runner));assert not a.require_native or execute
    def run(cmd,inside=False):
        cmd=list(map(str,cmd))
        if inside and len(cmd)==4 and Path(cmd[0]).parent==a.work.resolve()/'elf-retain':cmd=shlex.split(a.runner)+cmd
        return subprocess.run(cmd,capture_output=True,text=True,timeout=120)
    exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe,a.before)
if __name__=='__main__':main()
