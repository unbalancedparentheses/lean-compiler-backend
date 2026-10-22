from pathlib import Path
import hashlib,json,subprocess,time
root=Path('/work/qbe-bootstrap-elf-main-v3-riscv64-linux');out=root/'outputs';out.mkdir(exist_ok=True)
backends={'reference': '/work/qbe-bootstrap-elf-main-v3-riscv64-linux/source/qbe', 'baseline': '/work/qbe-bootstrap-elf-main-v3-riscv64-linux/run-baseline', 'optimized': '/work/qbe-bootstrap-elf-main-v3-riscv64-linux/run-optimized', 'qbe-corrected': '/work/qbe-bootstrap-elf-main-v3-riscv64-linux/run-qbe-corrected'}
result={'matches':{},'self_ir_matches':{},'rejections':[],'samples':{},'failures':{}}
def assert_same(expected, actual):
    assert expected == actual, 'assembly differs'
sensitivity_checked=False
def compare(target,p,kind):
    global sensitivity_checked
    reference=None
    for label,exe in backends.items():
        if label in result['failures']:continue
        asm=out/f'{kind}-{target}-{p.stem}-{label}.s'
        r=subprocess.run([str(exe),'-t',target,'-o',str(asm),str(p)],capture_output=True,text=True)
        if label=='reference':
            reference=(r.returncode,asm.read_bytes() if asm.exists() else b'')
            if r.returncode:result['rejections'].append({'target':target,'input':p.name,'exit':r.returncode,'stderr':r.stderr})
        else:
            if label=='qbe' and (r.returncode!=reference[0] or (r.returncode==0 and asm.read_bytes()!=reference[1])):
                result['failures'][label]={'target':target,'input':p.name,'exit':r.returncode,'reference_exit':reference[0],'stderr':r.stderr,'phase':'assembly reproduction','assembly_sha256':hashlib.sha256(asm.read_bytes()).hexdigest() if r.returncode==0 else None,'reference_assembly_sha256':hashlib.sha256(reference[1]).hexdigest() if reference[0]==0 else None}
                continue
            assert r.returncode==reference[0],(target,p.name,label,r.returncode,reference[0],r.stderr)
            if r.returncode==0:
                assert_same(reference[1],asm.read_bytes())
                if not sensitivity_checked:
                    corrupted=asm.read_bytes()+b'\n# comparator mutation\n'
                    try: assert_same(reference[1],corrupted)
                    except AssertionError: result['comparator_control']={'status':'detected','target':target,'input':p.name,'label':label,'original_sha256':hashlib.sha256(reference[1]).hexdigest(),'mutated_sha256':hashlib.sha256(corrupted).hexdigest()}
                    else: raise AssertionError('comparator accepted changed assembly')
                    sensitivity_checked=True
                table=result['matches'].setdefault(target,{}) if kind=='fixture' else result['self_ir_matches']
                table[label]=table.get(label,0)+1
for target in ['arm64', 'arm64_apple', 'amd64_sysv', 'amd64_apple', 'amd64_win', 'rv64']:
    for p in sorted((root/'source/test').glob('*.ssa')):compare(target,p,'fixture')
for p in sorted((root/'ir').glob('*.ssa')):compare('arm64',p,'self')
for label,exe in backends.items():
    if label in result['failures']:continue
    samples=[]
    for _ in range(1):
        start=time.monotonic()
        for p in sorted((root/'ir').glob('*.ssa')):
            subprocess.run([str(exe),'-t','arm64','-o','/dev/null',str(p)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        samples.append(time.monotonic()-start)
    result['samples'][label]=samples
(root/'probe.json').write_text(json.dumps(result,indent=2)+'\n')
