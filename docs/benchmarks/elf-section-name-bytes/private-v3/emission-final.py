from pathlib import Path
import sys,subprocess,json
sys.path.insert(0,'scripts');import elf_section_names as new;import section_names as old
w=Path('.build/section-names').resolve();rows=[]
def run(cmd,inside=False):
 assert not inside,cmd
 return subprocess.run(list(map(str,cmd)),capture_output=True,text=True)
for target in ['aarch64-linux','x86_64-linux','riscv64-linux','aarch64-macos','x86_64-macos']:
 for before in [None,w/'before']:
  r=new.exercise(w/'after',w/'emission-v3'/('before' if before else 'no-before')/target,run,Path('/missing/cc'),target,False,Path('/missing/qbe'),before);assert r['executed_modes']==0 and r['qbe_sha256'] is None;rows.append(dict(helper='new',target=target,before=bool(before)))
 r=old.exercise(w/'after',w/'emission-old-v3'/target,run,Path('/missing/cc'),target,False,Path('/missing/qbe'));assert r['executed_c_checks']==0 and r['original_qbe']=='not-run';rows.append(dict(helper='old',target=target))
(w/'emission-final.json').write_text(json.dumps(dict(passed=rows),indent=2));print('15 emission profiles passed')
