import concurrent.futures,hashlib,json,os,subprocess
from pathlib import Path
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend')
private=Path('/tmp/lcb-qbe-bootstrap-refresh')
compiler=root/'.build/lcb-elf-sections-main'
identity=subprocess.check_output([compiler,'--build-identity'],text=True).strip()
assert identity=='5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e'
script=private/'v3/qbe_bootstrap.py'
(private/'launch-v3.json').write_text(json.dumps({'identity':identity,'compiler_sha256':hashlib.sha256(compiler.read_bytes()).hexdigest(),'helper_sha256':hashlib.sha256(script.read_bytes()).hexdigest()},indent=2))
def run(target):
    work=root/'.build/linux-arm64'/('qbe-bootstrap-elf-main-v3-'+target)
    argv=['python3',str(script),'--compiler',str(compiler),'--work',str(work),'--target',target,'--repetitions','1']
    with (private/(target+'-v3.log')).open('w') as log:
        result=subprocess.run(argv,stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'PYTHONPATH':str(root/'scripts')})
    row={'target':target,'exit':result.returncode,'command':argv,'work':str(work)}
    (private/(target+'-v3-exit.json')).write_text(json.dumps(row,indent=2))
    print(json.dumps(row),flush=True)
for target in ['aarch64-linux','x86_64-linux','riscv64-linux']:
    run(target)
