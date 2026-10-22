from pathlib import Path
import sys,subprocess,json
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');sys.path.insert(0,str(root/'scripts'));import section_names
work=root/'.build/section-main/apple-x86';work.mkdir(exist_ok=True)
cc=work/'cc';cc.write_text('#!/bin/sh\nexec cc -arch x86_64 "$@"\n');cc.chmod(0o755)
def run(cmd,inside=False):
 cmd=list(map(str,cmd))
 if inside and cmd[0].startswith(str(work)) and Path(cmd[0]).suffix=='' and cmd[0]!=str(cc):cmd=['arch','-x86_64',*cmd]
 return subprocess.run(cmd,text=True,capture_output=True,timeout=180)
r=section_names.exercise(root/'.build/section-main/lcb',work,run,cc,'x86_64-macos',True,Path('/Users/unbalancedparen/projects/lean-compiler-backend/.build/syntax-main-review/qbe-snapshot'))
print(r['status'],r['executed_c_checks'])
