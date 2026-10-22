from pathlib import Path
import sys,subprocess,hashlib,json
sys.path.insert(0,'scripts');import large_aggregate_abi as h
w=Path('.build/aggregate-copy/size-4096');w.mkdir(exist_ok=True);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();rows=[]
for target in h.QBE_TARGET:
 src=w/(target+'.ssa');src.write_text(h.fixture([4096],target)[0])
 for mode,flags in [('baseline',[]),('allocated',['--allocate']),('optimized',['--optimize'])]:
  row=dict(target=target,mode=mode,source_sha256=sha(src),outputs={})
  for label in ['before','numeric-copy-only']:
   compiler=Path('.build/aggregate-copy')/label;asm=w/(target+'-'+mode+'-'+label+'.s');cmd=[str(compiler),str(src),'--target',target,*flags,'-o',str(asm)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=120);assert r.returncode==0,r.stderr
   row['outputs'][label]=dict(compiler_sha256=sha(compiler),assembly_sha256=sha(asm),assembly_text_bytes=asm.stat().st_size,assembly_lines=len(asm.read_text().splitlines()),command=cmd)
  rows.append(row)
(w/'report.json').write_text(json.dumps(dict(scope='Assembly source lines and UTF-8 bytes only; no object size or runtime claim. Same valid4096-byte mixed-ABI fixture before/copy-only after, no cap change.',helper_sha256=sha(Path(h.__file__)),rows=rows),indent=2)+'\n')
print(json.dumps(rows[0]))
