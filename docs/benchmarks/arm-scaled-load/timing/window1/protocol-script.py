#!/usr/bin/env python3
"""Pinned native Linux ARM zlib API correctness and in-process paired timing.

Build and timing are separate phases so a quiet timing window can be arranged.
All libraries are rebuilt; only pinned, hash-checked frontend IR is reused.
"""
import argparse,hashlib,json,os,platform,re,shlex,shutil,subprocess,sys,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
UNITS='adler32 crc32 deflate infback inffast inflate inftrees trees zutil compress uncompr gzclose gzlib gzread gzwrite'.split()
CALLER=r'''#define _GNU_SOURCE
#include <zlib.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sched.h>
#include <errno.h>
static volatile unsigned long sink;
static void die(const char *s){perror(s);exit(2);}
static unsigned char *readfile(const char *p,size_t *n){FILE*f=fopen(p,"rb");if(!f)die("open");if(fseek(f,0,SEEK_END))die("seek");long z=ftell(f);if(z<0||z>16777216)die("size");*n=(size_t)z;rewind(f);unsigned char*b=malloc(*n+1);if(!b)die("malloc");if(fread(b,1,*n,f)!=*n)die("read");fclose(f);return b;}
static uint64_t now(void){struct timespec t;if(clock_gettime(CLOCK_MONOTONIC_RAW,&t))die("clock");return (uint64_t)t.tv_sec*1000000000+t.tv_nsec;}
static unsigned long number(const char*s){char*e;errno=0;unsigned long n=strtoul(s,&e,10);if(errno||*e)die("number");return n;}
int main(int argc,char**argv){
 if(argc<4)return 2;size_t n;unsigned char*input=readfile(argv[2],&n);int level=(int)number(argv[3]);
 uLongf capacity=compressBound(n),packedsize=capacity,outsize=n;unsigned char*packed=malloc(capacity),*out=malloc(n+1);if(!packed||!out)die("malloc");
 if(compress2(packed,&packedsize,input,n,level)!=Z_OK)return 3;
 if(!strcmp(argv[1],"check")){
  if(argc!=5)return 2;outsize=n;if(uncompress(out,&outsize,packed,packedsize)!=Z_OK||outsize!=n||memcmp(out,input,n))return 4;
  FILE*f=fopen(argv[4],"wb");if(!f)die("output");if(fwrite(packed,1,packedsize,f)!=packedsize||fclose(f))die("write");
  unsigned long crc=crc32(0,input,n);
#ifdef CORRUPT_CRC
  crc^=1;
#endif
  printf("{\"crc32\":%lu,\"input_bytes\":%zu,\"compressed_bytes\":%lu}\n",crc,n,(unsigned long)packedsize);return 0;
 }
 if(!strcmp(argv[1],"verify")){
  if(argc!=5)return 2;size_t pn;unsigned char*p=readfile(argv[4],&pn);outsize=n;if(uncompress(out,&outsize,p,pn)!=Z_OK||outsize!=n||memcmp(out,input,n))return 5;return 0;
 }
 if(strcmp(argv[1],"bench")||argc!=9)return 2;
 unsigned long loops[3]={number(argv[4]),number(argv[5]),number(argv[6])};int cpu=(int)number(argv[7]);unsigned long warm=number(argv[8]);
 if(cpu<0||cpu>=CPU_SETSIZE)return 6;cpu_set_t affinity;CPU_ZERO(&affinity);CPU_SET(cpu,&affinity);if(sched_setaffinity(0,sizeof affinity,&affinity))die("affinity");if(sched_getcpu()!=cpu)return 6;
 for(int k=0;k<3;k++)if(!loops[k]||loops[k]>100000000)return 2;
 for(unsigned long i=0;i<warm;i++){uLongf z=capacity,o=n;if(compress2(packed,&z,input,n,level)!=Z_OK||uncompress(out,&o,packed,z)!=Z_OK)return 7;sink^=crc32(0,input,n);}
 uint64_t start=now();for(unsigned long i=0;i<loops[0];i++){uLongf z=capacity;if(compress2(packed,&z,input,n,level)!=Z_OK)return 7;sink^=z;}uint64_t c=now()-start;
 start=now();for(unsigned long i=0;i<loops[1];i++){uLongf z=n;if(uncompress(out,&z,packed,packedsize)!=Z_OK)return 8;sink^=z;}uint64_t d=now()-start;
 start=now();for(unsigned long i=0;i<loops[2];i++){sink^=crc32(0,input,n);}uint64_t crc=now()-start;
 if(sched_getcpu()!=cpu||memcmp(out,input,n))return 9;
 printf("{\"compress_ns\":%llu,\"uncompress_ns\":%llu,\"crc32_ns\":%llu,\"loops\":[%lu,%lu,%lu],\"cpu\":%d,\"sink\":%lu}\n",(unsigned long long)c,(unsigned long long)d,(unsigned long long)crc,loops[0],loops[1],loops[2],cpu,sink);return 0;
}
'''

# Executed inside the native ARM VM. Clock intervals are produced by the C caller;
# Python startup, payload I/O and docker transport are outside measured regions.
PROBE=r'''from pathlib import Path
import argparse,hashlib,json,os,platform,random,statistics,subprocess,time,zlib
ap=argparse.ArgumentParser();ap.add_argument('work');ap.add_argument('phase',choices=['check','time']);ap.add_argument('--samples',type=int,default=9);ap.add_argument('--batch-ms',type=float,default=100);ap.add_argument('--warmups',type=int,default=2);ap.add_argument('--cpu',type=int);a=ap.parse_args()
root=Path(a.work);manifest=json.loads((root/'manifest.json').read_text());labels=manifest['successful_builds'];rng=random.Random(20261022)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def run(cmd):
 p=subprocess.run(list(map(str,cmd)),capture_output=True,timeout=300)
 assert p.returncode==0,(cmd,p.returncode,p.stdout[-3000:],p.stderr[-3000:]);return p.stdout
assert platform.machine()=='aarch64','native ARM64 Linux required'
for label in labels:assert sha(root/label/'driver')==manifest['backends'][label]['executable_sha256'],label
for p,h in manifest['payload_hashes'].items():assert sha(root/p)==h,p
assert sha(root/'caller.c')==manifest['caller_sha256']
assert sha(root/'probe.py')==manifest['probe_sha256']
assert sha(root/'negative-driver')==manifest['negative_driver_sha256']
if a.phase=='check':
 result={'status':'running','backends':{},'negative_control':None};references={}
 def save():(root/'correctness.json').write_text(json.dumps(result,indent=2)+'\n')
 for label in labels:
  entry={'status':'running','checks':[]};result['backends'][label]=entry;save()
  try:
   for payload in manifest['payloads']:
    p=root/payload['path'];data=p.read_bytes()
    for level in [1,6,9]:
     packed=root/label/(p.stem+'-'+str(level)+'.zlib');answer=json.loads(run([root/label/'driver','check',p,level,packed]));actual=packed.read_bytes()
     assert answer['crc32']==zlib.crc32(data),(label,p.name,level,'crc')
     assert zlib.decompress(actual)==data,(label,p.name,level,'Python decompress')
     key=(p.name,level)
     if label=='gcc':references[key]=packed
     expected=references[key];assert actual==expected.read_bytes(),(label,p.name,level,'GCC compressed bytes')
     run([root/label/'driver','verify',p,level,expected])
     entry['checks'].append({'payload':p.name,'level':level,'crc32':answer['crc32'],'compressed_sha256':sha(packed),'compressed_bytes':len(actual)})
   entry['status']='passed'
  except BaseException as error:
   entry.update(status='failed',error=repr(error));save()
   if label!='qbe-original':raise
  save()
 p=root/manifest['payloads'][0]['path'];bad=root/'corrupted.zlib';answer=json.loads(run([root/'negative-driver','check',p,6,bad]));assert answer['crc32']!=zlib.crc32(p.read_bytes()),'corrupt CRC escaped independent oracle'
 result['negative_control']='wrong CRC detected';result['status']='passed_with_original_qbe_failure' if result['backends']['qbe-original']['status']=='failed' else 'passed';save()
else:
 correctness=json.loads((root/'correctness.json').read_text());assert correctness['status'] in ['passed','passed_with_original_qbe_failure']
 labels=[label for label in labels if correctness['backends'][label]['status']=='passed']
 allowed=sorted(os.sched_getaffinity(0));cpu=allowed[0] if a.cpu is None else a.cpu;assert cpu in allowed
 assert a.samples>=3 and a.batch_ms>0 and a.warmups>=1
 def read(p):
  try:return Path(p).read_text()
  except OSError:return None
 result={'status':'running','clock':'CLOCK_MONOTONIC_RAW inside C API loops','cpu':cpu,'allowed_cpus':allowed,'environment':{'uname':platform.uname()._asdict(),'cpuinfo':read('/proc/cpuinfo'),'loadavg_before':read('/proc/loadavg'),'governor':read(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_governor'),'frequency_before':read(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_cur_freq')},'seed':20261022,'samples_requested':a.samples,'batch_ms':a.batch_ms,'warmups':a.warmups,'labels':labels,'calibration':{},'samples':[],'summary':{},'claims':'No automatic performance claim; inspect paired dispersion and repeat quiet windows.'}
 def save():(root/'timing.json').write_text(json.dumps(result,indent=2)+'\n')
 def bench(label,p,loops):return json.loads(run([root/label/'driver','bench',root/p['path'],6,*loops,cpu,a.warmups]))
 cases=[p for p in manifest['payloads'] if p['timed']]
 for p in cases:
  trial=bench('gcc',p,[1,1,1]);loops=[max(1,min(10000000,int(a.batch_ms*1000000/trial[k]))) for k in ['compress_ns','uncompress_ns','crc32_ns']]
  trial2=bench('gcc',p,loops);result['calibration'][p['name']]={'first':trial,'loops':loops,'second':trial2}
  # Discarded full-batch warmup for every label before paired samples.
  for label in labels:bench(label,p,loops)
 save()
 for round_index in range(a.samples):
  order=cases[:];rng.shuffle(order)
  for p in order:
   label_order=labels[:];rng.shuffle(label_order);loops=result['calibration'][p['name']]['loops']
   for position,label in enumerate(label_order):
    row={'round':round_index,'case':p['name'],'label':label,'order':label_order,'position':position,'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'measurement':bench(label,p,loops)}
    result['samples'].append(row);save()
 def stats(xs):
  med=statistics.median(xs);return {'n':len(xs),'median':med,'min':min(xs),'max':max(xs),'mad':statistics.median(abs(x-med) for x in xs),'mean':statistics.mean(xs),'stdev':statistics.stdev(xs),'cv':statistics.stdev(xs)/statistics.mean(xs)}
 for p in cases:
  summary={};result['summary'][p['name']]=summary
  for label in labels:
   rows=[r for r in result['samples'] if r['case']==p['name'] and r['label']==label];summary[label]={}
   for api in ['compress','uncompress','crc32']:
    key=api+'_ns';summary[label][api]=stats([r['measurement'][key] for r in rows])
    index=['compress','uncompress','crc32'].index(api)
    summary[label][api]['ns_per_call']=stats([r['measurement'][key]/r['measurement']['loops'][index] for r in rows])
    comparisons={};summary[label][api]['paired_ratios']=comparisons
    for ref in dict.fromkeys(['gcc','qbe-original','qbe-corrected',manifest['lcb_labels'][0]]):
     if ref not in labels:continue
     refs={r['round']:r for r in result['samples'] if r['case']==p['name'] and r['label']==ref}
     ratios=[r['measurement'][key]/refs[r['round']]['measurement'][key] for r in rows];s=stats(ratios)
     boot=sorted(statistics.median([rng.choice(ratios) for _ in ratios]) for _ in range(2000));s['median_bootstrap95']=[boot[50],boot[1949]];s['low_dispersion']=s['cv']<=0.05;comparisons[ref]=s
 for p in cases:
  assert len(set(r['measurement']['sink'] for r in result['samples'] if r['case']==p['name']))==1,('timed sink disagreement',p['name'])
 result['sink_agreement']='all labels and rounds'
 result['environment'].update(loadavg_after=read('/proc/loadavg'),frequency_after=read(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_cur_freq'))
 result['status']='completed';save()
'''


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root',type=Path,default=ROOT)
    ap.add_argument('--work',type=Path,required=True)
    ap.add_argument('--binding-report',type=Path)
    ap.add_argument('--compiler',action='append',default=[],metavar='LABEL=PATH')
    ap.add_argument('--phase',choices=['build','time','all'],default='build')
    ap.add_argument('--docker-container',default='lcb-parity-linux')
    ap.add_argument('--samples',type=int,default=9);ap.add_argument('--batch-ms',type=float,default=100);ap.add_argument('--warmups',type=int,default=2);ap.add_argument('--cpu',type=int)
    args=ap.parse_args();root=args.root.resolve();base=root/'.build/linux-arm64';work=args.work.resolve()
    def guest(p):return '/work/'+str(Path(p).relative_to(base))
    guest(work)
    def run(cmd,cwd=None,check=True):
        p=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=600)
        if check:assert p.returncode==0,(cmd,p.stdout[-3000:],p.stderr[-3000:])
        return p
    def docker(cmd,check=True):return run(['docker','exec',args.docker_container,*map(str,cmd)],check=check)
    def sync(p):
        # The bind mount is eventually consistent on some host/guest setups.
        wanted=sha(p)
        for _ in range(100):
            found=docker(['sha256sum',guest(p)],False).stdout.split()
            if found and found[0]==wanted:return
            time.sleep(.05)
        raise AssertionError('host/guest digest mismatch: '+str(p))
    def report_barrier(name):
        path=work/name;wanted=docker(['sha256sum',guest(path)]).stdout.split()[0]
        for _ in range(100):
            if path.exists() and sha(path)==wanted:return wanted
            time.sleep(.05)
        raise AssertionError('guest report did not synchronize: '+name)
    def validate_provenance(manifest,stage,report_names=()):
        assert manifest['successful_builds']==['gcc',*manifest['lcb_labels'],'qbe-original','qbe-corrected']
        expected={}
        def add(path,wanted):expected[str(path)]=wanted
        for name,h in manifest['source_hashes'].items():add(work/'source'/name,h)
        for name,h in manifest['configuration_hashes'].items():add(work/'source'/name,h)
        for name,h in manifest['ir_hashes'].items():add(work/'ir'/(name+'.ssa'),h)
        for name,h in manifest['payload_hashes'].items():add(work/name,h)
        for name,key in [('caller.c','caller_sha256'),('caller.o','caller_object_sha256'),('probe.py','probe_sha256'),('negative-driver','negative_driver_sha256'),('binding-report.json','binding_report_sha256')]:add(work/name,manifest[key])
        for label,entry in manifest['backends'].items():
            for name,obj in entry['objects'].items():add(work/label/(name+'.o'),obj['sha256'])
            add(work/label/'driver',entry['executable_sha256'])
            if label in manifest['lcb_labels']:add(work/('compiler-'+label),entry['compiler_sha256'])
            if label.startswith('qbe-'):
                add(work/(label+'-source')/'qbe',entry['oracle_binary_sha256'])
                for name,h in entry['source_files'].items():add(work/(label+'-source')/name,h)
        assert sha(__file__)==manifest['script_sha256'],'script changed since build'
        for path,wanted in expected.items():assert sha(path)==wanted,('host provenance',stage,path)
        code='import sys,json,hashlib;from pathlib import Path;print(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in json.loads(sys.argv[1])}))'
        actual=json.loads(docker(['python3','-c',code,json.dumps([guest(path) for path in expected])]).stdout)
        for path,wanted in expected.items():assert actual[guest(path)]==wanted,('guest provenance',stage,path)
        reports={name:report_barrier(name) for name in ['manifest.json',*report_names]}
        record={'stage':stage,'status':'passed','utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'bound_files_checked_host_and_guest':len(expected),'bound_file_manifest_sha256':hashlib.sha256(json.dumps(expected,sort_keys=True).encode()).hexdigest(),'reports_guest_host_sha256':reports}
        log=work/'provenance.json';records=json.loads(log.read_text()) if log.exists() else []
        if records:
            assert records[0]['reports_guest_host_sha256']['manifest.json']==reports['manifest.json'],'manifest changed since initial validation'
            assert records[0]['bound_file_manifest_sha256']==record['bound_file_manifest_sha256'],'bound file set changed since initial validation'
        if stage=='before_timing':
            prior=[r for r in records if r['stage']=='after_correctness'];assert prior,'missing post-correctness validation'
            assert prior[-1]['reports_guest_host_sha256']['correctness.json']==reports['correctness.json'],'correctness report changed after validation'
        records.append(record);log.write_text(json.dumps(records,indent=2)+'\n');sync(log)
        return record
    assert docker(['uname','-m']).stdout.strip()=='aarch64','requires native ARM64 Linux container'
    if args.phase in ['build','all']:
        assert not work.exists(),'use a fresh work directory to retain prior evidence';work.mkdir(parents=True)
        binding=args.binding_report or root/'.build/zlib-cse-profit-arm.json';bound=json.loads(binding.read_text());assert bound['target']=='aarch64-linux' and bound['zlib_commit']=='51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf'
        shutil.copy2(binding,work/'binding-report.json')
        retained=base/'zlib-benchmark';source=work/'source';source.mkdir();ir=work/'ir';ir.mkdir()
        for name,wanted in bound['source_hashes'].items():
            original=retained/'zlib'/name;assert sha(original)==wanted,('source binding',name)
            dest=source/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,dest);sync(dest)
        for name,wanted in bound['configuration_hashes'].items():
            original=retained/'zlib'/name;assert sha(original)==wanted,('configuration binding',name);shutil.copy2(original,source/name);sync(source/name)
        for name in UNITS:
            original=retained/'ir'/(name+'.ssa');assert sha(original)==bound['translation_units'][name]['sha256'],('IR binding',name);shutil.copy2(original,ir/original.name)
        labels={}
        for item in args.compiler:
            label,path=item.split('=',1);assert re.fullmatch(r'[A-Za-z0-9_-]+',label) and label not in ['gcc','qbe-original','qbe-corrected'] and label not in labels
            snapshot=work/('compiler-'+label);shutil.copy2(Path(path).resolve(),snapshot);labels[label]=snapshot
        assert labels,'supply at least one --compiler LABEL=PATH'
        caller=work/'caller.c';caller.write_text(CALLER);sync(caller);probe=work/'probe.py';probe.write_text(PROBE);sync(probe)
        # Independent deterministic payload generation, retained as exact bytes.
        import random
        rng=random.Random(20261022);payloads=[('empty',b'',False),('byte-range',bytes(range(256))*16,False),('repeated',b'compiler backend zlib in-process\x00'*8192,True),('random',rng.randbytes(262144),True),('mixed',(b'aaaaabbbbbcccccc\x00'*2048+rng.randbytes(8192))*4,True)]
        records=[]
        for name,data,timed in payloads:
            p=work/(name+'.bin');p.write_bytes(data);sync(p);records.append({'name':name,'path':p.name,'bytes':len(data),'sha256':sha(p),'timed':timed})
        manifest={'schema':1,'target':'aarch64-linux','binding_report_sha256':sha(binding),'zlib_commit':bound['zlib_commit'],'cproc_commit':bound['cproc_commit'],'source_hashes':bound['source_hashes'],'configuration_hashes':bound['configuration_hashes'],'ir_hashes':{n:bound['translation_units'][n]['sha256'] for n in UNITS},'caller_sha256':sha(caller),'probe_sha256':sha(probe),'script_sha256':sha(__file__),'payloads':records,'payload_hashes':{p['path']:p['sha256'] for p in records},'lcb_labels':list(labels),'successful_builds':[],'backends':{},'gcc_version':docker(['gcc','--version']).stdout,'gcc_flags':shlex.split(bound['gcc_reference_flags']),'notes':['Fresh 15-library-object builds; immutable LCB snapshots consume pinned original cproc IR.','GCC compiles original C; generated C caller always GCC -O2, no LTO.','Original QBE source unchanged; corrected oracle patch separately recorded, never substituted.','Measured C intervals exclude process startup, file/pipe I/O, allocation of caller buffers and initial correctness checks; API-internal allocation remains included.','VM CPU affinity constrains guest scheduling; host scheduling/frequency still affect timings.']}
        lock=json.loads((root/'upstream-lock.json').read_text());patchpath=root/'tests/upstream/qbe-1.3-arm64-extern-offset.json';patch=json.loads(patchpath.read_text());manifest['oracle_patch_sha256']=sha(patchpath);assert manifest['oracle_patch_sha256']==bound['oracle_patch_sha256'],'corrected oracle patch differs from retained binding'
        oracles={}
        for label in ['qbe-original','qbe-corrected']:
            oracle=work/(label+'-source');shutil.copytree(root/'third_party/qbe',oracle)
            files={k:v for k,v in lock['vendored_files'].items() if k.startswith('third_party/qbe/')}
            for path,wanted in files.items():assert sha(root/path)==wanted,('vendored QBE',path)
            if label=='qbe-corrected':
                path=oracle/patch['source'];text=path.read_text();assert text.count(patch['before'])==1;path.write_text(text.replace(patch['before'],patch['after']))
            # Force a genuinely fresh host oracle build even if vendored binaries exist.
            run(['make','clean'],cwd=oracle);run(['make','-j2',f'CC={os.environ.get("LCB_CC","cc")}','CFLAGS=-std=c99 -O2'],cwd=oracle)
            oracles[label]=oracle/'qbe';manifest['backends'][label]={'oracle_binary_sha256':sha(oracles[label]),'source_files':{str(Path(p).relative_to('third_party/qbe')):sha(oracle/Path(p).relative_to('third_party/qbe')) for p in files},'oracle_correction':patch if label=='qbe-corrected' else None}
        callerobj=work/'caller.o';docker(['gcc','-O2','-I'+guest(source),'-c',guest(caller),'-o',guest(callerobj)])
        manifest['caller_object_sha256']=docker(['sha256sum',guest(callerobj)]).stdout.split()[0]
        for label in ['gcc',*labels,*oracles]:
            dest=work/label;dest.mkdir();entry=manifest['backends'].setdefault(label,{});entry.update(status='building',objects={})
            if label in labels:entry.update(compiler_identity=run([labels[label],'--build-identity']).stdout.strip(),compiler_sha256=sha(labels[label]),mode='optimized')
            for unit in UNITS:
                obj=dest/(unit+'.o')
                if label=='gcc':docker(['gcc',*manifest['gcc_flags'],'-I'+guest(source),'-c',guest(source/(unit+'.c')),'-o',guest(obj)])
                else:
                    asm=dest/(unit+'.s')
                    command=[labels[label],ir/(unit+'.ssa'),'--target','aarch64-linux','--optimize','-o',asm] if label in labels else [oracles[label],'-t','arm64','-o',asm,ir/(unit+'.ssa')]
                    run(command);sync(asm);docker(['gcc','-c',guest(asm),'-o',guest(obj)])
                entry['objects'][unit]={'sha256':docker(['sha256sum',guest(obj)]).stdout.split()[0]}
            exe=dest/'driver';docker(['gcc',guest(callerobj),*[guest(dest/(n+'.o')) for n in UNITS],'-o',guest(exe)])
            if label in labels:assert sha(labels[label])==entry['compiler_sha256'],'compiler snapshot changed during build'
            entry.update(status='built',executable_sha256=docker(['sha256sum',guest(exe)]).stdout.split()[0]);manifest['successful_builds'].append(label)
            print('built',label,flush=True)
        docker(['gcc','-O2','-DCORRUPT_CRC','-I'+guest(source),guest(caller),*[guest(work/'gcc'/(n+'.o')) for n in UNITS],'-o',guest(work/'negative-driver')])
        manifest['negative_driver_sha256']=docker(['sha256sum',guest(work/'negative-driver')]).stdout.split()[0]
        (work/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');sync(work/'manifest.json')
        validate_provenance(manifest,'before_correctness')
        checked=docker(['python3',guest(probe),guest(work),'check'],False);(work/'correctness.log').write_text(checked.stdout+checked.stderr);assert checked.returncode==0,checked.stderr
        validate_provenance(manifest,'after_correctness',['correctness.json'])
        print('correctness passed; no timings collected' if args.phase=='build' else 'correctness passed',flush=True)
    if args.phase in ['time','all']:
        manifest=json.loads((work/'manifest.json').read_text());assert sha(__file__)==manifest['script_sha256'],'script changed since build; retain old evidence and rebuild'
        validate_provenance(manifest,'before_timing',['correctness.json'])
        cmd=['python3',guest(work/'probe.py'),guest(work),'time','--samples',args.samples,'--batch-ms',args.batch_ms,'--warmups',args.warmups]
        if args.cpu is not None:cmd+=['--cpu',args.cpu]
        timed=docker(cmd,False);(work/'timing.log').write_text(timed.stdout+timed.stderr);assert timed.returncode==0,timed.stderr
        validate_provenance(manifest,'after_timing',['correctness.json','timing.json'])
        print('raw paired API samples retained in',work/'timing.json',flush=True)
if __name__=='__main__':main()
