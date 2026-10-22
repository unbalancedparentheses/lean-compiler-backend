"""PRIVATE diagnostic protocol: mixed compression only; other API loops=1."""
from pathlib import Path
import argparse,hashlib,json,os,platform,random,statistics,subprocess,time
p=argparse.ArgumentParser();p.add_argument('work');p.add_argument('--samples',type=int,default=9);p.add_argument('--batch-ms',type=float,default=500);p.add_argument('--warmups',type=int,default=2);a=p.parse_args();w=Path(a.work)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
m=json.loads((w/'manifest.json').read_text());qualification=json.loads((w/'correctness.json').read_text());protocol=json.loads((w/'mixed-protocol.json').read_text());assert sha(__file__)==protocol['probe_sha256'];assert sha(w/'manifest.json')==protocol['manifest_sha256'];assert platform.machine()=='aarch64'
labels=m['successful_builds'];assert all(qualification['backends'][l]['status']=='passed' for l in labels)
for l in labels:assert sha(w/l/'driver')==m['backends'][l]['executable_sha256']
assert sha(w/'mixed.bin')==m['payload_hashes']['mixed.bin'];assert sha(w/'caller.c')==m['caller_sha256'];assert a.samples>=3 and a.batch_ms>0 and a.warmups>=1
cpu=min(os.sched_getaffinity(0));rng=random.Random(20261023)
def read(p):
 try:return Path(p).read_text()
 except OSError:return None
r={'status':'running','protocol':protocol,'samples_requested':a.samples,'batch_ms':a.batch_ms,'warmups':a.warmups,'seed':20261023,'cpu':cpu,'labels':labels,'payload':'mixed.bin','level':6,'samples':[],'environment':{'uname':platform.uname()._asdict(),'loadavg_before':read('/proc/loadavg'),'cpuinfo':read('/proc/cpuinfo')},'notes':['New private diagnostic protocol, not unchanged generic PROBE.','Compression loops GCC-calibrated once and fixed across all labels/rounds. Decompression/CRC each1 loop; their timings retained but excluded from summaries.','Unchanged caller performs initial compression and2 warmup iterations including all APIs. Measured compression occurs before the single decompression/CRC loops.','Function mixtures can change linked layout and cache preconditioning; measurements do not prove individual instruction latency.','Same immutable library/caller bindings as correctness qualification; hybrids are mixed objects, not new compiler identities.']}
def save():(w/'mixed-timing.json').write_text(json.dumps(r,indent=2)+'\n')
def bench(label,loops):
 cmd=[str(w/label/'driver'),'bench',str(w/'mixed.bin'),'6',str(loops),'1','1',str(cpu),str(a.warmups)];p=subprocess.run(cmd,text=True,capture_output=True,timeout=300);assert p.returncode==0,(cmd,p.returncode,p.stdout,p.stderr);v=json.loads(p.stdout);assert v['loops']==[loops,1,1] and v['cpu']==cpu;return v
try:
 first=bench('gcc',1);loops=max(1,min(10000000,int(a.batch_ms*1000000/first['compress_ns'])));second=bench('gcc',loops);r['calibration']={'first':first,'loops':[loops,1,1],'second':second}
 for label in labels:bench(label,loops)
 save()
 for round_index in range(a.samples):
  order=labels[:];rng.shuffle(order)
  for pos,label in enumerate(order):r['samples'].append({'round':round_index,'label':label,'position':pos,'order':order,'utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'measurement':bench(label,loops)});save()
 assert len({x['measurement']['sink'] for x in r['samples']})==1
 def stats(xs):
  med=statistics.median(xs);return {'n':len(xs),'median':med,'min':min(xs),'max':max(xs),'mad':statistics.median(abs(x-med) for x in xs),'cv':statistics.stdev(xs)/statistics.mean(xs)}
 r['summary']={};bootstrap=random.Random(20261024)
 for label in labels:
  rows=[x for x in r['samples'] if x['label']==label];entry={'compress_ns':stats([x['measurement']['compress_ns'] for x in rows]),'ns_per_call':stats([x['measurement']['compress_ns']/loops for x in rows]),'paired_ratios':{}};r['summary'][label]=entry
  for ref in labels:
   refs={x['round']:x['measurement']['compress_ns'] for x in r['samples'] if x['label']==ref};ratios=[x['measurement']['compress_ns']/refs[x['round']] for x in rows];s=stats(ratios);bs=sorted(statistics.median(bootstrap.choices(ratios,k=len(ratios))) for _ in range(2000));s['median_bootstrap95']=[bs[50],bs[1949]];entry['paired_ratios'][ref]=s
 r.update(status='completed',sink_agreement='all labels/rounds');r['environment']['loadavg_after']=read('/proc/loadavg');save()
except BaseException as e:r.update(status='failed',error=repr(e));save();raise
