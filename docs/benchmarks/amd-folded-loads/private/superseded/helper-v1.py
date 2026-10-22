#!/usr/bin/env python3
"""Independent byte oracle for AMD folded-load word normalization."""
from pathlib import Path
import hashlib,json,subprocess,re

def fixture():
 ir=[];decl=[];checks=[];cases=[];guards=[]
 kinds=[('loadsb',1,True),('loadub',1,False),('loadsh',2,True),('loaduh',2,False),('loadsw',4,True),('loaduw',4,False),('loadw',4,False),('loads',4,False),('loadl',8,False),('loadd',8,False)]
 for op,size,signed in kinds:
  for width in (['w','l'] if op not in ['loadw','loads','loadl','loadd'] else ['w' if size==4 else 'l']):
   for variant,offset in [('fold',17),('negative',-17),('max',2147483647),('min',-2147483648),('fallback',2147483648),('shared',17),('debug',17),('pressure',17)]:
    name=f'{op}_{width}_{variant}';floating=op in ['loads','loadd'];result='s' if op=='loads' else 'd' if op=='loadd' else width
    params='l %p'+(''+''.join(f', l %x{i}' for i in range(24)) if variant=='pressure' else '')
    body=[f'%a =l add %p, {offset}']
    if variant=='debug':body+=['dbgloc 23']
    body += [f'%v ={result} {op} %a']
    if variant=='shared':body+=['%other =l copy %a','storel %other, $saved_address']
    if floating:body += [f'%bits ={width} cast %v'];v='%bits'
    else:v='%v'
    body += [f'%wide =l extuw {v}' if width=='w' else f'%wide =l copy {v}']
    if variant=='pressure':
     previous='%wide'
     for i in range(24):body += [f'%sum{i} =l add {previous}, %x{i}'];previous=f'%sum{i}'
     body += [f'ret {previous}']
    else:body += ['ret %wide']
    ir += [f'export function l ${name}({params}) {{\n@s\n '+'\n '.join(body)+'\n}\n']
    decl += [f'extern uint64_t {name}(uintptr_t'+',uint64_t'* (24 if variant=='pressure' else 0)+');']
    args=''+''.join(f',UINT64_C({i+1})' for i in range(24)) if variant=='pressure' else ''
    expr=f'expected(p,{size},{int(signed)},{32 if width=="w" else 64})'+('+300' if variant=='pressure' else '')
    checks += [f'if({name}((uintptr_t)p-(uint64_t)(INT64_C({offset})){args})!=({expr}))return {len(cases)%200+1};']
    guards.append('{unsigned char*p=m+2*page-'+str(size)+';'+checks[-1]+'}')
    if variant=='shared':checks+=['if(saved_address!=(uintptr_t)p)return 220;']
    cases.append({'name':name,'width':width,'op':op,'variant':variant,'offset':offset})
 ir=['dbgfile "folded-loads.c"\nexport data $saved_address = { l 0 }\n']+ir
 c='''#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
extern uintptr_t saved_address;
'''+ '\n'.join(decl)+'''
static uint64_t expected(const unsigned char*p,unsigned n,int sign,unsigned width){uint64_t v=0;for(unsigned i=0;i<n;i++)v|=(uint64_t)p[i]<<(8*i);if(sign&&n<8&&(v>>(8*n-1)))v|=~((UINT64_C(1)<<(8*n))-1);return width==32?(uint32_t)v:v;}
static int check(unsigned char*p){'''+''.join(checks)+'''return 0;}
int main(void){uint64_t seeds[]={0,1,127,128,255,32767,32768,65535,0x7fffffff,0x80000000,0xffffffff,UINT64_C(0x7fc012347f800001),UINT64_C(0xfff81234deadbeef),UINT64_MAX};unsigned char bytes[24];for(unsigned i=0;i<sizeof(seeds)/8;i++){memcpy(bytes+1,&seeds[i],8);int r=check(bytes+1);if(r)return r;}long page=sysconf(_SC_PAGESIZE);unsigned char*m=mmap(0,page*3,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);if(m==MAP_FAILED)return 230;if(mprotect(m+page,page,PROT_READ|PROT_WRITE))return 231;memset(m+page,255,page);int r=check(m+2*page-8);if(r)return r;'''+''.join(guards)+'''munmap(m,page*3);return 0;}
'''
 return ''.join(ir),c,cases

def exercise(compiler,work,run,cc,target,execute=True,before=None,qbe=None):
 w=Path(work)/'amd-folded-loads';w.mkdir(parents=True);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();ir,c,cases=fixture();src=w/'input.ssa';src.write_text(ir);caller=w/'caller.c';caller.write_text(c);cc=list(cc) if isinstance(cc,(list,tuple)) else [cc];commands=[]
 def call(cmd,inside=False,ok=True):
  r=run(list(map(str,cmd)),inside);commands.append({'command':list(map(str,cmd)),'inside':inside,'exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
  if ok:assert r.returncode==0,commands[-1]
  return r
 report={'identity':call([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'helper_sha256':sha(__file__),'source_sha256':sha(src),'caller_sha256':sha(caller),'target':target,'functions':len(cases),'checks_per_execution':len(cases)*16,'rows':[],'commands':commands}
 for label,path,flags in [('before-'+m,before,f) for m,f in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])] if before]+[(m,compiler,f) for m,f in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]]+([('qbe',qbe,None)] if execute and qbe else []):
  asm=w/(label+'.s');exe=w/label
  call([path,'-t','amd64_apple' if target.endswith('macos') else 'amd64_sysv','-o',asm,src],True) if flags is None else call([path,src,'--target',target,*flags,'-o',asm])
  row={'label':label,'assembly_sha256':sha(asm),'execution':'not-run'}
  if label in ['baseline','allocated','optimized'] and before:
   old=(w/('before-'+label+'.s')).read_text();new=asm.read_text();expected=re.sub(r'(\tmov(?:sbl|swl|zbl|zwl|l) [-0-9]+\(%rax\), %eax\n)\tmovl %eax, %eax\n',r'\1',old);assert expected==new,(label,'unexplained delta');row['removed_normalizations']=old.count('\tmovl %eax, %eax\n')-new.count('\tmovl %eax, %eax\n');assert label!='baseline' or old==new
  if execute:call([*cc,caller,asm,'-o',exe],True);call([exe],True);row['execution']='passed'
  report['rows'].append(row)
 if execute:
  text=(w/'allocated.s').read_text();wrong=text.replace('movzbl 17(%rax), %eax','movsbl 17(%rax), %eax',1);assert wrong!=text;bad=w/'wrong-sign.s';bad.write_text(wrong);exe=w/'wrong-sign';call([*cc,caller,bad,'-o',exe],True);r=call([exe],True,False);assert r.returncode!=0;report['wrong_signedness_detected']=True
  if qbe:report['qbe_sha256']=call(['python3','-c','import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())',qbe],True).stdout.strip()
 (w/'report.json').write_text(json.dumps(report,indent=2));return report
