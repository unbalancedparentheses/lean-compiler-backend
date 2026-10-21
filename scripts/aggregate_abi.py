#!/usr/bin/env python3
"""Apple ARM64 aggregates: exact tails, HFAs, copies, callbacks and mixed banks."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from fuzz import ROOT, LCB, run, native_host
from symbols import reject

TYPES = [(f'b{n}', f'b {n}', f'unsigned char v[{n}];', n) for n in [1,3,5,7,9,12,15,16,17,24,33]]
TYPES += [(f'{k}{n}', f'{k} {n}', f'{ct} v[{n}];', size*n)
          for k,ct,size in [('s','float',4),('d','double',8)] for n in range(1,5)]
TYPES += [('mixed','s, w','float f; unsigned int i;',8),
          ('nested',':inner 2','inner v[2];',16),
          ('unions','{ s 2 } { s }','float a[2]; float b;',8)]


def fixture(batch):
    il=['type :inner = { s 2 }']
    c=['typedef struct {float v[2];} inner;']
    checks=[]
    for name,fields,cf,size in batch:
        il.append(f'type :{name} = {{ {fields} }}')
        tag='union' if name=='unions' else 'struct'
        c += [f'typedef {tag} {{ {cf} }} {name};',
              f'extern {name} echo_{name}({name});',
              f'extern {name} relay_{name}({name});',
              f'extern {name} indirect_{name}({name} (*)({name}), {name});',
              f'{name} c_echo_{name}({name} p) {{ return p; }}',
              f'extern int model_{name}(void);', f'extern {name} read_{name}(void*);']
        il += [f'''export function :{name} $read_{name}(l %p) {{ @s
 %r =:{name} call $echo_{name}(:{name} %p)
 ret %r
}}
export function :{name} $echo_{name}(:{name} %p) {{ @s ret %p }}
export function :{name} $relay_{name}(:{name} %p) {{ @s
 %size =l copy 32
 %dynamic =l alloc16 %size
 %r =:{name} call $c_echo_{name}(:{name} %p)
 ret %r
}}
export function :{name} $indirect_{name}(l %fn, :{name} %p) {{ @s
 %r =:{name} call %fn(:{name} %p)
 ret %r
}}
function :{name} $mutate_{name}(:{name} %p) {{ @s
 storeb 99, %p
 ret %p
}}
export function w $model_{name}() {{ @s
 %p =l alloc8 {size}
''']
        for i in range(size):
            il += [f' %a{i} =l add %p, {i}\n storeb {i+1}, %a{i}']
        il += [f''' %r =:{name} call $mutate_{name}(:{name} %p)
 %old =w loadub %p
 %new =w loadub %r
 %sum =w add %old, %new
 ret %sum
}}''']
        # Pressure independently exhausts GP and FP banks, with an aggregate at
        # each boundary and a final scalar after them. All scalar values matter.
        kinds=['l']*7+['d']*7+[f':{name}','l','d',f':{name}','l','d']
        params=[]; ctypes=[]; cargs=[]; h=[]
        for j,k in enumerate(kinds):
            params.append(f'{k} %p{j}')
            if k.startswith(':'):
                ctypes.append(name);cargs.append('value')
                h += [f' %v{j} =w loadub %p{j}', f' %x{j} =l extuw %v{j}']
            elif k=='d':
                ctypes.append('double');cargs.append(f'{j+1}.0')
                h += [f' %x{j} =l dtoui %p{j}']
            else:
                ctypes.append('unsigned long long');cargs.append(str(j+1))
                h += [f' %x{j} =l copy %p{j}']
            h += [f' %h{j+1} =l add %h{j}, %x{j}']
        il += [f'export function l $pressure_{name}('+','.join(params)+') { @s\n %h0 =l copy 0\n'+'\n'.join(h)+f'\n ret %h{len(kinds)}\n}}']
        c += [f'extern unsigned long long pressure_{name}('+','.join(ctypes)+');']
        wanted=sum(j+1 for j,k in enumerate(kinds) if not k.startswith(':'))
        checks += [f'''{{
 {name} value, result;
 for (unsigned j=0;j<sizeof(value);j++) ((unsigned char*)&value)[j]=(unsigned char)(j+1);
 result=echo_{name}(value); if(memcmp(&result,&value,sizeof(value))) return __LINE__;
 result=relay_{name}(value); if(memcmp(&result,&value,sizeof(value))) return __LINE__;
 result=indirect_{name}(c_echo_{name},value); if(memcmp(&result,&value,sizeof(value))) return __LINE__;
 result=indirect_{name}(echo_{name},value); if(memcmp(&result,&value,sizeof(value))) return __LINE__;
#ifdef LCB_TEST_GUARDS
 long page=sysconf(_SC_PAGESIZE);
 unsigned char *mapping=mmap(0,(size_t)page*2,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 if(mapping==MAP_FAILED || mprotect(mapping+page,(size_t)page,PROT_NONE)) return __LINE__;
 unsigned char *short_object=mapping+page-sizeof(value);
 memcpy(short_object,&value,sizeof(value));
 result=read_{name}(short_object); if(memcmp(&result,&value,sizeof(value))) return __LINE__;
 if(munmap(mapping,(size_t)page*2)) return __LINE__;
#endif
 if(model_{name}()!=100) return __LINE__;
 if(pressure_{name}({','.join(cargs)}) != {wanted+2}) return __LINE__;
}}''']
    c='#include <string.h>\n#include <sys/mman.h>\n#include <unistd.h>\n'+'\n'.join(c)+'\nint main(void) {\n'+'\n'.join(checks)+'\nreturn 0;\n}\n'
    return '\n'.join(il).replace(' { @s', ' {\n@s\n').replace('ret %p }', 'ret %p\n}'),c


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--require-native',action='store_true')
    args=ap.parse_args()
    if args.require_native: assert native_host()
    cc=os.environ.get('LCB_CC','cc')
    with tempfile.TemporaryDirectory(prefix='lcb-aggregate-') as directory:
        work=Path(directory)
        qbe=None
        if native_host():
            oracle=work/'oracle';shutil.copytree(ROOT/'third_party/qbe',oracle)
            run(['make','-j2',f'CC={cc}'],cwd=oracle);qbe=oracle/'qbe'
        for batchnum,start in enumerate(range(0,len(TYPES),4)):
            batch=TYPES[start:start+4]
            source,c=fixture(batch)
            src=work/f'input{batchnum}.ssa';src.write_text(source)
            caller=work/f'caller{batchnum}.c';caller.write_text(c)
            assembly=work/f'lean{batchnum}.s'
            run([LCB,src,'-o',assembly])
            for name,_,_,_ in batch:
                assert run([LCB,'--eval',src,f'model_{name}']).strip()=='100'
            if qbe:
                qasm=work/f'qbe{batchnum}.s';run([qbe,'-t','arm64_apple','-o',qasm,src])
                for label,asm in [('lean',assembly),('qbe',qasm)]:
                    exe=work/f'{label}{batchnum}'
                    run([cc,'-O0',*(['-DLCB_TEST_GUARDS'] if label=='lean' else []),caller,asm,'-o',exe]);run([exe])
                if batchnum == 0:
                    broken=work/'overread.s'
                    original=assembly.read_text()
                    changed=original.replace('ldrb w13, [x12, #0]', 'ldr x13, [x12, #0]')
                    assert changed != original, 'missing short-fragment negative control'
                    broken.write_text(changed)
                    exe=work/'overread'
                    run([cc,'-O0','-DLCB_TEST_GUARDS',caller,broken,'-o',exe])
                    result=subprocess.run([exe],capture_output=True,timeout=120)
                    assert result.returncode != 0, 'guarded tail overread was not detected'
        for text in [
            'type :t = { w } function :t $f() { @s ret 0 } function l $g() { @s %p =l call $f() ret %p }',
            'type :t = { w } function $f(:t %p) { @s ret } function $g(l %p) { @s call $f(l %p) ret }',
            'type :t = { w } function l $f() { @s %p =:t copy 0 ret %p }',
            'type :t = align 16 { w } function :t $f(:t %p) { @s ret %p }',
        ]:
            src=work/'bad.ssa';src.write_text(text);reject([LCB,src],'')
    print(f'aggregate ABI: {len(TYPES)} layouts, by-value isolation and result lifetimes; '+
          ('native Lean/QBE/C returns, callbacks, mixed GP/FP exhaustion and dynamic frames passed' if qbe else 'native execution unmeasured'))


if __name__=='__main__':main()
