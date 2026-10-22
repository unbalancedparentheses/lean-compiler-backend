from pathlib import Path
import hashlib,json,subprocess,shutil,sys
root=Path('/Users/unbalancedparen/projects/lean-compiler-backend');base=root/'.build/linux-arm64';work=base/'lua-mixed-review';work.mkdir(exist_ok=False);sys.path.insert(0,str(root/'scripts'));from docker_sync import host_file
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def guest(p):return str(p).replace(str(base),'/work')
def run(cmd,inside=False,check=True,cwd=None,timeout=180):
 c=list(map(str,cmd));c=(['docker','exec']+(['-w',guest(cwd)] if cwd else [])+['lcb-parity-linux']+c) if inside else c
 p=subprocess.run(c,capture_output=True,text=True,timeout=timeout)
 if check and p.returncode:
  (work/'failure.json').write_text(json.dumps({'cmd':c,'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr},indent=2));raise RuntimeError(p.stderr)
 return p
prepath=root/'docs/benchmarks/lua-preflight/report.json';pre=json.loads(prepath.read_text());source=work/'source';source.mkdir();bound={str(prepath):sha(prepath)}
for name,h in pre['source_sha256'].items():
 p=base/'lua-preflight-source'/name;assert sha(p)==h,p;shutil.copy2(p,source/name);bound[str(p)]=h;host_file(source/name,base,'lcb-parity-linux')
tests=work/'tests-original';shutil.copytree(base/'lua-5.4.7-tests',tests)
for p in tests.rglob('*'):
 if p.is_file():host_file(p,base,'lcb-parity-linux')
front=work/'frontend';front.mkdir()
for n in ['cproc','cproc-qbe']:
 p=base/'cjson-benchmark/cproc'/n;shutil.copy2(p,front/n);host_file(front/n,base,'lcb-parity-linux');bound[str(p)]=sha(p)
compiler=work/'compiler';shutil.copy2(root/'.build/lcb-arm-indexed',compiler)
units=[r['unit'] for r in pre['units']];excluded=['ldebug','ldo','lstate'];assert len(units)==33 and len(set(units)-set(excluded))==30
report={'scope':'Mixed Lua build: exactly three unchanged volatile-containing units built by GCC identically for all mixed labels; remaining30 original units compiled through pinned cproc IR. Not full frontend/backend Lua qualification. Internal ltests.c and onelua.c not part of production build.','source_commit':pre['source_commit'],'source_hashes':pre['source_sha256'],'target':'aarch64-linux','frontend_hashes':{n:sha(front/n) for n in ['cproc','cproc-qbe']},'compiler_identity':run([compiler,'--build-identity']).stdout.strip(),'compiler_sha256':sha(compiler),'units':units,'excluded_frontend_units':excluded,'frontend_defines':['-D__CHAR_BIT__=8','-D__SCHAR_MAX__=127','-D__SHRT_MAX__=32767','-D__LONG_MAX__=9223372036854775807L','-D__DBL_MANT_DIG__=53','-D__DBL_MAX_EXP__=1024','-D__FLT_RADIX__=2','-D__DBL_MAX_10_EXP__=308'],'configuration':'Unchanged Lua defaults (no LUA_USE_LINUX/READLINE/internal-test defines); all GCC builds use -std=c99.','frontend':{},'backends':{},'test_hashes':{str(p.relative_to(tests)):sha(p) for p in tests.rglob('*') if p.is_file()},'bound_inputs':bound}
def save():(work/'report.json').write_text(json.dumps(report,indent=2)+'\n')
save();ir=work/'ir';ir.mkdir()
for unit in units:
 p=run([guest(front/'cproc'),*report['frontend_defines'],'-emit-qbe',guest(source/(unit+'.c')),'-o',guest(ir/(unit+'.ssa'))],True,False)
 report['frontend'][unit]={'exit':p.returncode,'stderr':p.stderr}
 if unit in excluded:assert p.returncode and 'volatile store is not yet supported' in p.stderr
 else:
  assert p.returncode==0,(unit,p.stderr);report['frontend'][unit]['ir_sha256']=sha(ir/(unit+'.ssa'))
 save();print('frontend',unit,p.returncode,flush=True)
for label,opt in [('gcc-O0','-O0'),('gcc-O2','-O2')]:
 case=work/label;case.mkdir();objects=[]
 for unit in units:
  obj=case/(unit+'.o');run(['gcc','-std=c99',opt,'-c',guest(source/(unit+'.c')),'-o',guest(obj)],True);objects.append(obj)
 exe=case/'lua';run(['gcc',*map(guest,objects),'-lm','-ldl','-o',guest(exe)],True)
 report['backends'][label]={'objects':{p.stem:sha(p) for p in objects},'executable_sha256':sha(exe),'version':run([guest(exe),'-v'],True).stdout,'build_status':'passed'};save();print('built',label,flush=True)
 for name,h in pre['source_sha256'].items():assert sha(source/name)==h
print('frontend/reference builds complete',flush=True)
