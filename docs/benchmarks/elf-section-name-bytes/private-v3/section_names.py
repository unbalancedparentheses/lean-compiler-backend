#!/usr/bin/env python3
"""Bounded custom-section names, target ambiguity and independent C oracle."""
import argparse,hashlib,json,os,shlex,subprocess
from pathlib import Path
from data_relocations import native_host,QBE_TARGET
from fuzz import LCB

def exercise(compiler,work,run,cc,target,execute=True,qbe=None,before=None):
    cc=list(cc) if isinstance(cc,(list,tuple)) else [cc]
    d=Path(work)/'section-names';d.mkdir(parents=True,exist_ok=True);apple=target.endswith('macos');sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
    report={'harness_sha256':sha(__file__),'target':target,'compiler_sha256':sha(compiler),'runs':[],'executed_c_checks':0,'original_qbe':'not-run','negative_control':'not-run','notes':['Unflagged ELF names are assembly/object-inspection cases only, not runtime-qualified.','ELF retains both string boundaries and literal commas. Apple preserves LCB unquoted combined directives and 16-byte names, deliberately differing from QBE quoted section-name bytes.']}
    def invoke(cmd,inside=False,ok=True):
        cmd=list(map(str,cmd));r=run(cmd,inside);report['runs'].append({'command':cmd,'inside':inside,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
        if ok:assert r.returncode==0,(cmd,r.returncode,r.stdout,r.stderr)
        return r
    report['compiler_identity']=invoke([compiler,'--build-identity']).stdout.strip()
    # ELF runtime cases explicitly request allocated writable/executable sections.
    names=['custom','.foo-bar','foo-bar','with_under','with.dot','with$dollar','literal,comma']
    lines=[];decl=[];checks=[];initial=[]
    for i,n in enumerate(names):
        if apple:data_section=f'"__DATA" "__custom{i}"';code_section=f'"__TEXT" "__code{i}"'
        else:data_section=f'"{n}" "aw"';code_section=f'"{n}_code" "ax"'
        lines += [f'section {data_section} export data $v{i} = {{ l {100+i} }}',f'section {code_section} export function l $f{i}(l %x) {{\n@s\n %v =l loadl $v{i}\n %r =l add %v,%x\n ret %r\n}}']
        initial += [f'if(v{i}!={100+i})return 3;']
        decl += [f'extern uint64_t v{i}, f{i}(uint64_t);'];checks += [f'if(f{i}(x)!=v{i}+x)return 1;v{i}^=x;if(f{i}(x)!=v{i}+x)return 2;']
    source=d/'runtime.ssa';source.write_text('\n'.join(lines)+'\n');caller=d/'caller.c';caller.write_text('#include <stdint.h>\n'+ '\n'.join(decl)+'\nint main(void){'+''.join(initial)+'uint64_t values[]={0,1,UINT64_C(0x8000000000000000),UINT64_MAX};for(unsigned j=0;j<4;j++){uint64_t x=values[j];'+''.join(checks)+'}return 0;}\n')
    report['source_sha256']=sha(source);report['caller_sha256']=sha(caller)
    for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
        asm=d/(mode+'.s');invoke([compiler,source,'--target',target,*flags,'-o',asm])
        if execute:
            exe=d/mode;invoke([*cc,caller,asm,'-o',exe],True);invoke([exe],True);report['executed_c_checks']+=9*len(names)
    # Same source semantics for unchanged QBE, including raw optional flag syntax.
    if execute and qbe:
        asm=d/'qbe.s';exe=d/'qbe';qt={'aarch64-linux':'arm64','x86_64-linux':'amd64_sysv','riscv64-linux':'rv64','aarch64-macos':'arm64_apple','x86_64-macos':'amd64_apple'}[target]
        invoke([qbe,'-t',qt,'-o',asm,source],True);invoke([*cc,caller,asm,'-o',exe],True);invoke([exe],True);report['executed_c_checks']+=9*len(names);report['original_qbe']='passed'
        report['qbe_sha256']=invoke(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
    # Ambiguous flattened comma forms and a dot-leading Apple segment are explicit cases.
    inspect_forms=['"foo" "ax"']+(['".SEG" "sect"','"__DATA" "'+'n'*14+'"'] if apple else ['"foo,ax"','"foo,ax" "aw"']+ ['"custom"','".foo-bar"','"foo-bar"','"'+'n'*128+'"'])
    for i,form in enumerate(inspect_forms):
        src=d/f'inspect{i}.ssa';src.write_text(f'section {form} export data $inspect{i} = {{ l {i+1} }}\n');asm=d/f'inspect{i}.s';invoke([compiler,src,'--target',target,'-o',asm])
        if execute:
            obj=d/f'inspect{i}.o';invoke([*cc,'-c',asm,'-o',obj],True)
            dump=invoke(['otool','-l',obj] if apple else ['readelf','-SW',obj],True).stdout
            expected=(form.split(chr(34))[3] if apple else form.split(chr(34))[1]);assert expected in dump.split(),(form,expected,dump)
            if qbe:
                qa=d/f'inspect{i}-qbe.s';qo=d/f'inspect{i}-qbe.o';invoke([qbe,'-t',qt,'-o',qa,src],True);invoke([*cc,'-c',qa,'-o',qo],True)
                qdump=invoke(['otool','-l',qo] if apple else ['readelf','-SW',qo],True).stdout
                qexpected='"'+expected+'"' if apple else expected
                assert qexpected in qdump.split(),(form,qexpected,qdump)
    if apple:
        # LCB-only legacy extension is explicitly separate from the QBE matrix.
        legacy=d/'legacy.ssa';legacy.write_text('section "__DATA,__legacy,regular,no_dead_strip" data $legacy = { l 42 }\n')
        assembly=d/'legacy.s';invoke([compiler,legacy,'--target',target,'-o',assembly])
        if execute:
            obj=d/'legacy.o';invoke([*cc,'-c',assembly,'-o',obj],True)
            assert '__legacy' in invoke(['otool','-l',obj],True).stdout.split()
        # Retain LCB's full unquoted 16-byte field capacity. QBE's quote bytes
        # exceed the Mach-O field limit here; this is not a common-oracle pass.
        boundary=d/'apple-sixteen.ssa';boundary.write_text('section "__DATA" "'+('n'*16)+'" data $boundary = { l 42 }\n')
        assembly=d/'apple-sixteen.s';invoke([compiler,boundary,'--target',target,'-o',assembly])
        if execute:
            obj=d/'apple-sixteen.o';invoke([*cc,'-c',assembly,'-o',obj],True)
            assert 'n'*16 in invoke(['otool','-l',obj],True).stdout.split()
            if qbe:
                qa=d/'apple-sixteen-qbe.s';invoke([qbe,'-t',qt,'-o',qa,boundary],True)
                qr=invoke([*cc,'-c',qa,'-o',d/'apple-sixteen-qbe.o'],True,ok=False)
                assert qr.returncode!=0 and 'length' in qr.stderr
                report['apple_qbe_16_byte_section']='assembler refusal: quotes exceed section-name capacity; LCB case passed separately'
    bad=['""','"bad\\n.globl injected"','"bad\\tname"','"bad\\000name"','"bad\\177name"','"café"']
    if apple:
        bad += ['"bad name"','"bad;injected"','"bad\\\"name"','"bad\\\\name"']
    bad += (['"__DATA" "'+'x'*17+'"','"__DATA,__x,unknown"','"__DATA,__x,regular,unknown"','"custom"','".foo-bar"'] if apple else ['"'+'n'*129+'"','"custom" "aT"','"custom" "aw,extra"','"__DATA" "__custom"'])
    for i,form in enumerate(bad):
        src=d/f'bad{i}.ssa';src.write_text(f'section {form} data $bad = {{ l 1 }}\n');r=invoke([compiler,src,'--target',target,'-o',d/f'bad{i}.s'],ok=False);assert r.returncode!=0,form
    # Linkage exclusions and certified-profile refusal remain intact.
    for i,prefix in enumerate(['thread section "custom"','common section "custom"']):
        src=d/f'linkage-bad{i}.ssa';src.write_text(prefix+' data $bad = { z 8 }\n');assert invoke([compiler,'--check',src],ok=False).returncode!=0
    assert invoke([compiler,'--first-path',source],ok=False).returncode!=0
    if before and not apple:
        src=d/'before-refusal.ssa';src.write_text('section "custom" data $v = { l 1 }\n');assert invoke([before,src,'--target',target,'-o',d/'before-refusal.s'],ok=False).returncode!=0
    if execute:
        wrong=d/'wrong-value.ssa';wrong.write_text(source.read_text().replace('l 100','l 101',1));asm=d/'wrong-value.s';exe=d/'wrong-value';invoke([compiler,wrong,'--target',target,'-o',asm]);fixed=d/'fixed-caller.c';fixed.write_text('#include <stdint.h>\nextern uint64_t f0(uint64_t);int main(void){return f0(0)!=100;}\n');invoke([*cc,fixed,asm,'-o',exe],True);r=invoke([exe],True,ok=False);assert r.returncode==1;report['negative_control']='wrong global value detected'
    report['status']='passed';(d/'report.json').write_text(json.dumps(report,indent=2)+'\n');return report

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compiler',type=Path,default=LCB)
    p.add_argument('--work',type=Path,default=Path('.build/section-names'))
    p.add_argument('--target',choices=QBE_TARGET,default=native_host())
    p.add_argument('--cc',default=os.environ.get('LCB_CC',os.environ.get('CC','cc')))
    p.add_argument('--runner',default='')
    p.add_argument('--qbe',type=Path);p.add_argument('--before',type=Path)
    p.add_argument('--require-native',action='store_true')
    p.add_argument('--emission-only','--no-execute',action='store_true')
    a=p.parse_args();execute=not a.emission_only and (a.target==native_host() or bool(a.runner))
    assert not a.require_native or execute
    def run(cmd,inside=False):
        if inside and len(cmd)==1:cmd=shlex.split(a.runner)+cmd
        return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    r=exercise(a.compiler.resolve(),a.work.resolve(),run,shlex.split(a.cc),a.target,execute,a.qbe,a.before)
    print(f"{a.target}: section-name matrix passed, {r['executed_c_checks']} C checks; execution={execute}",flush=True)
if __name__=='__main__':main()
