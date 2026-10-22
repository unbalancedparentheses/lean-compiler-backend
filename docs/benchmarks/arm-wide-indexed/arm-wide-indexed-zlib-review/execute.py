from pathlib import Path
import subprocess,hashlib,json,gzip
root=Path('/work/arm-wide-indexed-zlib-review');reference=Path('/work/zlib-benchmark/gcc');result={}
def run(exe,args=(),data=None):
 p=subprocess.run([str(exe),*args],input=data,capture_output=True,timeout=120)
 if p.returncode:
  (root/'execution-error.json').write_text(json.dumps({'executable':str(exe),'args':args,'exit':p.returncode,'stderr':p.stderr.decode(errors='replace')},indent=2));raise RuntimeError(str(exe))
 return p.stdout
def sha(b):return hashlib.sha256(b).hexdigest()
paths=[p for p in root.rglob('*') if p.is_file() and (p.suffix in ['.s','.o','.ssa'] or p.name in ['example','minigzip'])]+[reference/'example',reference/'minigzip']
initial={str(p):sha(p.read_bytes()) for p in paths};binding=json.loads((root/'report.json').read_text())
for n in ['example','minigzip']:assert initial[str(reference/n)]==binding['reference_executable_hashes'][n]
payloads=[b'',bytes(range(256))*32,bytes((i*73+(i>>8))%256 for i in range(65536)),b'compiler backend extuw\n'*40000]
for mode in ['baseline','allocated','optimized']:
 result[mode]={}
 for label in ['before','after']:
  case=root/'aarch64-linux'/mode/label;rows=[];example=run(case/'example');assert example==run(reference/'example')
  for i,data in enumerate(payloads):
   for level in [1,6,9]:
    packed=run(case/'minigzip',[f'-{level}'],data);expected=run(reference/'minigzip',[f'-{level}'],data)
    assert packed==expected and gzip.decompress(packed)==data and run(case/'minigzip',['-d'],packed)==data
    rows.append({'payload':i,'level':level,'input_sha256':sha(data),'compressed_sha256':sha(packed)})
  result[mode][label]={'example_stdout_sha256':sha(example),'streams':rows,'status':'passed','executable_hashes':{n:initial[str(case/n)] for n in ['example','minigzip']}}
 assert result[mode]['before']['streams']==result[mode]['after']['streams']
for p,h in initial.items():assert sha(Path(p).read_bytes())==h,p
report={'execution':result,'input_postvalidation':'passed','initial_files':initial,'bound_files':len(initial),'scope':'Native ARM Linux VM execution only; Apple ARM objects assembled, not workload-executed. Exact GCC stream bytes, Python decompression and own-backend roundtrip.'}
(root/'execution.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':'passed','examples':6,'streams':72,'bound_files':len(initial),'report_sha256':sha((root/'execution.json').read_bytes())}))
