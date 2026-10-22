from pathlib import Path
import sys,subprocess,json
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');private=root;base=root/'.build/linux-arm64';sys.path.insert(0,str(private/'scripts'));import section_names,docker_sync,elf_sections
reports={}
for target,cc,runner in [('aarch64-linux','gcc',[]),('x86_64-linux','x86_64-linux-gnu-gcc',['qemu-x86_64','-L','/usr/x86_64-linux-gnu']),('riscv64-linux','riscv64-linux-gnu-gcc',['qemu-riscv64','-L','/usr/riscv64-linux-gnu'])]:
 work=base/('section-main-'+target)
 def run(cmd,inside=False):
  cmd=list(map(str,cmd))
  if inside:
   docker_sync.sources(cmd,base,'lcb-parity-linux')
   for x in cmd:
    if Path(x).suffix=='.s' and Path(x).is_file():docker_sync.host_file(x,base,'lcb-parity-linux')
   prefix=runner if cmd[0].startswith(str(work)) and Path(cmd[0]).suffix=='' else []
   cmd=['docker','exec','lcb-parity-linux',*prefix,*[('/work/'+str(Path(x).relative_to(base))) if x.startswith(str(base)+'/') else x for x in cmd]]
  return subprocess.run(cmd,text=True,capture_output=True,timeout=180)
 reports[target]=section_names.exercise(private/'.build/section-main/lcb',work,run,cc,target,True,'/tmp/qbe/qbe');print(target,'passed',flush=True)
 if target=='aarch64-linux':elf_sections.exercise(private/'.build/section-main/lcb',work,run,cc,'/tmp/qbe/qbe',True)
(private/'.build/section-main/linux-reports.json').write_text(json.dumps(reports,indent=2)+'\n')
