from pathlib import Path
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
 result={'protocol':'compression-only-v1; uncompress/CRC loops fixed at1, raw durations diagnostic only','status':'running','clock':'CLOCK_MONOTONIC_RAW inside C API loops','cpu':cpu,'allowed_cpus':allowed,'environment':{'uname':platform.uname()._asdict(),'cpuinfo':read('/proc/cpuinfo'),'loadavg_before':read('/proc/loadavg'),'governor':read(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_governor'),'frequency_before':read(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_cur_freq')},'seed':20261022,'samples_requested':a.samples,'batch_ms':a.batch_ms,'warmups':a.warmups,'labels':labels,'calibration':{},'samples':[],'summary':{},'claims':'No automatic performance claim; inspect paired dispersion and repeat quiet windows.'}
 def save():(root/'timing.json').write_text(json.dumps(result,indent=2)+'\n')
 def bench(label,p,loops):return json.loads(run([root/label/'driver','bench',root/p['path'],6,*loops,cpu,a.warmups]))
 cases=[p for p in manifest['payloads'] if p['timed']]
 for p in cases:
  trial=bench('gcc',p,[1,1,1]);loops=[max(1,min(10000000,int(a.batch_ms*1000000/trial['compress_ns']))),1,1]
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
   for api in ['compress']:
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
