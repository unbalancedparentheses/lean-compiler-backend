#!/usr/bin/env python3
"""Quoted global symbols through code, relocations, TLS, control flow and C ABI."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT,LCB,native_host

SOURCE='''export data $"data with spaces#;" = { l 37 }
data $"pointer+name" = { l $"data with spaces#;" }
export thread data $"thread with spaces" = { l 5 }
function l $"callee (quoted)"(l %x) {
@start
 %c =w ceql %x, 1
 jnz %c, @yes, @no
@yes
 jmp @join
@no
 jmp @join
@join
 %p =l phi @yes $"pointer+name", @no $"pointer+name"
 %q =l load %p
 %v =l load %q
 ret %v
}
export function l $"entry with spaces"() {
@start
 %r =l call $"callee (quoted)"(l 1)
 %tls =l copy thread $"thread with spaces"
 %v =l load %tls
 %sum =l add %r, %v
 ret %sum
}
export function l $quoted_entry() {
@start
 %fn =l copy $"entry with spaces"
 %r =l call %fn()
 ret %r
}
function l $"plain"() {
@s
 ret 42
}
export function l $plain_alias() {
@s
 %r =l call $"plain"()
 ret %r
}
'''
CALLER='''#include <stdint.h>
#include <dlfcn.h>
extern uint64_t quoted_entry(void),plain_alias(void);
int main(void){
 uint64_t (*entry)(void)=(uint64_t(*)(void))dlsym(RTLD_DEFAULT,"entry with spaces");
 uint64_t *data=(uint64_t*)dlsym(RTLD_DEFAULT,"data with spaces#;");
 return !entry || !data || entry()!=42 || *data!=37 || quoted_entry()!=42 || plain_alias()!=42;
}
'''

def exercise(compiler,work,run,cc,qbe,target,qtarget,execute=True):
    case=Path(work)/'quoted-names';case.mkdir(exist_ok=True)
    source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
    text=SOURCE.replace('$"','$"_') if target.endswith('-macos') else SOURCE
    caller_text=CALLER
    if target.endswith('-macos'):
        text += '\nfunction l $identity() {\n@s\n ret 42\n}\nfunction l $"identity"() {\n@s\n ret 43\n}\nexport function l $names_identity() {\n@s\n %a =l call $identity()\n %b =l call $"identity"()\n %sum =l add %a, %b\n ret %sum\n}\n'
        caller_text='extern unsigned long names_identity(void);\n'+CALLER.replace('return !entry','return names_identity()!=85 || !entry')
    source.write_text(text);caller.write_text(caller_text)
    result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
    result=run([compiler,'--eval',source,'quoted_entry']);assert result.returncode==0 and result.stdout.strip()=='42',(result.stdout,result.stderr)
    for i,bad in enumerate(['function l $""() { @s ret 0 }', 'function l $"unterminated() { @s ret 0 }', 'function l $"a"() { @s ret 0 } function l $"a"() { @s ret 1 }']):
        path=case/f'bad{i}.ssa';path.write_text(bad)
        result=run([compiler,'--check',path]);assert result.returncode!=0,'malformed/duplicate quoted name accepted'
    restricted=case/'first-path.ssa';restricted.write_text('function l $"quoted name"() { @s ret 42 }')
    result=run([compiler,'--first-path',restricted]);assert result.returncode!=0 and 'quoted global' in result.stderr
    if execute:
        # Pinned Apple QBE appends its TLS suffix outside the quoted name.
        # Keep the original Lean TLS input; rename only the QBE TLS reference.
        if target.endswith('-macos'):
            original=case/'qbe-original.s'
            result=run([qbe,'-t',qtarget,'-o',original,source],True);assert result.returncode==0,result.stderr
            result=run([cc,'-c',original,'-o',case/'qbe-original.o'],True)
            assert result.returncode!=0 and '$tlv$init' in result.stderr,result.stderr
            print(f'{target}: reproduced pinned QBE quoted-TLS suffix assembly failure; original Lean input remains mandatory',flush=True)
        qsource=case/'qbe-input.ssa' 
        qtext=text.replace('$"_thread with spaces"','$qbe_thread_reference') if target.endswith('-macos') else text
        qsource.write_text(qtext)
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,qsource],True);assert result.returncode==0,result.stderr
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label;result=run([cc,caller,asm,*(['-Wl,-export_dynamic'] if target.endswith('-macos') else ['-rdynamic','-ldl']),*(['-no-pie'] if qtarget=='rv64' and label=='qbe' else []),'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode==0,(label,result.returncode,result.stderr)
    print(f'{target}: quoted code/data/TLS/relocations and direct/indirect calls passed; execution={execute}',flush=True)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--require-native',action='store_true');args=ap.parse_args()
    if args.require_native:assert native_host()
    def run(cmd,inside=False):return subprocess.run(list(map(str,cmd)),text=True,capture_output=True,timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-quoted-') as directory:
        work=Path(directory);cc=os.environ.get('LCB_CC','cc');qbe=work/'oracle/qbe'
        if native_host():
            shutil.copytree(ROOT/'third_party/qbe',qbe.parent)
            r=run(['make','-C',qbe.parent,'-j2',f'CC={cc}']);assert r.returncode==0,r.stderr
        exercise(LCB,work,run,cc,qbe,'aarch64-macos','arm64_apple',native_host())

if __name__=='__main__':main()
