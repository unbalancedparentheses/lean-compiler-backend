#!/usr/bin/env python3
"""Bounded ELF custom TLS storage: C thread isolation and exact ELF metadata."""
import argparse,hashlib,json,os,re,shlex,subprocess
from data_relocations import native_host,QBE_TARGET
from fuzz import LCB
from pathlib import Path

IR='''section ".lcb_tls.init" "awT"
export thread data $custom_init = align 16 { l 37 }
section ".lcb_tls.zero" "waT"
export thread data $custom_zero = align 32 { z 8 }
section ".lcb_tls.local" "Taw"
thread data $custom_local = { l 73 }
export thread data $ordinary = { l 19 }
export function l $read_custom(w %i) {
@s
 jnz %i, @zero, @init
@zero
 %z =l loadl thread $custom_zero
 ret %z
@init
 %a =l loadl thread $custom_init
 ret %a
}
export function $write_custom(l %a, l %z) {
@s
 storel %a, thread $custom_init
 storel %z, thread $custom_zero
 ret
}
export function l $read_local() {
@s
 %v =l loadl thread $custom_local
 ret %v
}
export function $write_local(l %v) {
@s
 storel %v, thread $custom_local
 ret
}
export function l $read_ordinary() {
@s
 %v =l loadl thread $ordinary
 ret %v
}
export function $write_ordinary(l %v) {
@s
 storel %v, thread $ordinary
 ret
}
'''
C='''#include <pthread.h>
#include <stdint.h>
extern __thread uint64_t custom_init,custom_zero,ordinary;
extern uint64_t read_custom(int),read_local(void),read_ordinary(void);
extern void write_custom(uint64_t,uint64_t),write_local(uint64_t),write_ordinary(uint64_t);
static int failed;
static int initial(void){return read_custom(0)!=37||read_custom(1)!=0||read_local()!=73||read_ordinary()!=19||custom_init!=37||custom_zero!=0||ordinary!=19||((uintptr_t)&custom_init%16)||((uintptr_t)&custom_zero%32);}
static void* worker(void*p){
 if(initial())failed=1;
 for(uint64_t i=0;i<128;i++){
  uint64_t a=UINT64_C(0x8123456789abcdef)^i,z=UINT64_C(0xfedcba9876543210)+i;
  write_custom(a,z);write_local(a+1);write_ordinary(z+1);
  if(read_custom(0)!=a||read_custom(1)!=z||read_local()!=a+1||read_ordinary()!=z+1||custom_init!=a||custom_zero!=z||ordinary!=z+1)failed=2;
 }
 return 0;
}
int main(void){if(initial())return 1;write_custom(51,52);write_local(53);write_ordinary(54);
 for(int i=0;i<4;i++){pthread_t t;if(pthread_create(&t,0,worker,0)||pthread_join(t,0))return 3;if(failed)return 4;if(read_custom(0)!=51||read_custom(1)!=52||read_local()!=53||read_ordinary()!=54)return 5;}
 return 0;}
'''
ORDINARY='thread data $normal = { l 41 }\nexport function l $normal_read() {\n@s\n %v =l loadl thread $normal\n ret %v\n}\n'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def metadata(sections,symbols):
    found={}
    for line in sections.splitlines():
        m=re.match(r'\s*\[\s*(\d+)\]\s+(\S+)\s+(\S+)\s+\S+\s+\S+\s+(\S+)\s+\S+\s+(\S+)\s+\S+\s+\S+\s+(\d+)',line)
        if m:found[m[2]]={'index':m[1],'type':m[3],'size':int(m[4],16),'flags':m[5],'alignment':int(m[6])}
    for name,section,alignment in [('custom_init','.lcb_tls.init',16),('custom_zero','.lcb_tls.zero',32),('custom_local','.lcb_tls.local',8),('ordinary','.tdata',8)]:
        s=found[section];assert s['type']=='PROGBITS' and set(s['flags'])==set('WAT') and s['size']==8 and s['alignment']==alignment,(section,s)
        matches=[line.split() for line in symbols.splitlines() if line.split() and line.split()[-1]==name]
        assert len(matches)==1 and matches[0][3]=='TLS' and matches[0][-2]==s['index'],(name,matches,s)
    return found

def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
    work=Path(work)/'custom-tls-sections';work.mkdir(parents=True,exist_ok=True);cc=list(cc) if isinstance(cc,(list,tuple)) else [cc];commands=[];results=[]
    def invoke(cmd,inside=False):
        cmd=list(map(str,cmd));p=run(cmd,inside);commands.append(dict(command=cmd,inside=inside,exit=p.returncode,stdout=p.stdout,stderr=p.stderr));return p
    source=work/'input.ssa';caller=work/'caller.c';source.write_text(IR);caller.write_text(C)
    ordinary=work/'ordinary.ssa';ordinary.write_text(ORDINARY)
    identity=invoke([compiler,'--build-identity']);assert identity.returncode==0
    flagslist=[('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]
    for mode,flags in flagslist:
        a=work/(mode+'-ordinary.s');b=work/(mode+'-before-ordinary.s')
        assert invoke([compiler,ordinary,'--target',target,*flags,'-o',a]).returncode==0
        if before is not None:
            assert invoke([before,ordinary,'--target',target,*flags,'-o',b]).returncode==0
            assert a.read_bytes()==b.read_bytes()
    if target.endswith('macos'):
        for mode,flags in flagslist:
            p=invoke([compiler,source,'--target',target,*flags,'-o',work/(mode+'.s')]);assert p.returncode and 'Apple thread data cannot have a custom section' in p.stderr
        results.append(dict(apple_custom_tls='refused',ordinary_tls='byte-identical in three modes' if before is not None else 'emitted; before comparison skipped'))
    else:
        for mode,flags in flagslist+([('qbe',None)] if execute and qbe else []):
            asm=work/(mode+'.s');obj=work/(mode+'.o');exe=work/mode
            qt={'aarch64-linux':'arm64','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64'}[target]
            cmd=[qbe,'-t',qt,'-o',asm,source] if mode=='qbe' else [compiler,source,'--target',target,*flags,'-o',asm]
            assert invoke(cmd,mode=='qbe').returncode==0,commands[-1]
            row=dict(mode=mode,executed=False,assembly_sha256=sha(asm))
            if execute:
                assert invoke([*cc,'-c',asm,'-o',obj],True).returncode==0,commands[-1]
                sec=invoke(['readelf','-SW',obj],True);sym=invoke(['readelf','-sW',obj],True);assert sec.returncode==sym.returncode==0
                row['metadata']=metadata(sec.stdout,sym.stdout)
                assert invoke([*cc,caller,obj,'-pthread','-o',exe],True).returncode==0,commands[-1]
                assert invoke([exe],True).returncode==0,commands[-1];row['executed']=True
            results.append(row)
        if execute:
            wrong=work/'wrong-section.s';text=(work/'optimized.s').read_text();assert '.lcb_tls.init' in text;wrong.write_text(text.replace('.lcb_tls.init','.lcb_tls.wrong'))
            obj=work/'wrong-section.o';assert invoke([*cc,'-c',wrong,'-o',obj],True).returncode==0
            sec=invoke(['readelf','-SW',obj],True);sym=invoke(['readelf','-sW',obj],True)
            try:metadata(sec.stdout,sym.stdout)
            except (AssertionError,KeyError):pass
            else:raise AssertionError('wrong-section control escaped metadata oracle')
            wrong=work/'wrong-value.s';text=(work/'optimized.s').read_text();assert '\t.quad 37' in text;wrong.write_text(text.replace('\t.quad 37','\t.quad 38'));exe=work/'wrong-value'
            assert invoke([*cc,caller,wrong,'-pthread','-o',exe],True).returncode==0
            p=invoke([exe],True);assert p.returncode==1,commands[-1]
    invalid=[('missing','section ".bad" thread data $x = { l 1 }'),('no-t','section ".bad" "aw" thread data $x = { l 1 }'),('read-only','section ".bad" "aT" thread data $x = { l 1 }'),('no-a','section ".bad" "wT" thread data $x = { l 1 }'),('execute','section ".bad" "awTRx" thread data $x = { l 1 }'),('ordinary','section ".bad" "awT" data $x = { l 1 }'),('function','section ".bad" "awT" function $x() { @s ret }'),('common','common thread data $x = { z 8 }')]
    if target.endswith('macos'):
        # Two strings name an Apple segment/section, not ELF flags. Preserve that grammar.
        invalid=[(name,text) for name,text in invalid if name not in ['ordinary','function']]
    for name,text in invalid:
        p=work/(name+'.ssa');p.write_text(text+'\n')
        for mode,flags in flagslist:assert invoke([compiler,p,'--target',target,*flags,'-o',work/(name+'-'+mode+'.s')]).returncode!=0,(name,mode)
    qhash=None
    if qbe and execute and target.endswith('linux'):
        p=invoke(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True);assert p.returncode==0;qhash=p.stdout.strip()
    report=dict(target=target,compiler_identity=identity.stdout.strip(),compiler_sha256=sha(compiler),before_sha256=sha(before) if before is not None else None,ordinary_equivalence='passed' if before is not None else 'skipped: no before snapshot supplied',helper_sha256=sha(__file__),input_sha256=sha(source),caller_sha256=sha(caller),qbe_sha256=qhash,results=results,executed_round_groups=sum(512 for row in results if row.get('executed')),negative_cases=len(invalid)*3,commands=commands,scope='This fixture covers ELF explicit awT permutations; optional R is qualified separately by retained_tls.py; read-only aT excluded; custom zero initialization remains PROGBITS. Four sequential child threads each perform128 read/write rounds; same main-thread state retained. Ordinary TLS emission required; optional before equivalence status recorded separately. Apple custom TLS refused. No timing claim.')
    (work/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler',type=Path,default=LCB)
    p.add_argument('--before',type=Path)
    p.add_argument('--work',type=Path,default=Path('.build/custom-tls-sections'))
    p.add_argument('--target',choices=QBE_TARGET,default=native_host())
    p.add_argument('--cc',default=os.environ.get('LCB_CC','cc'))
    p.add_argument('--qbe',type=Path)
    p.add_argument('--runner',default='')
    p.add_argument('--emission-only','--no-execute',action='store_true')
    p.add_argument('--require-native',action='store_true')
    a=p.parse_args()
    execute=not a.emission_only and (a.target==native_host() or bool(a.runner))
    assert not a.require_native or execute, 'native execution or an explicit runner is required'
    def run(cmd,inside=False):
        if inside and len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(list(map(str,cmd)),capture_output=True,text=True,timeout=180)
    result=exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe,a.before.resolve() if a.before else None)
    print(a.target,'custom TLS qualification passed;',result['executed_round_groups'],'executed round groups;',result['ordinary_equivalence'])

if __name__=='__main__':main()
