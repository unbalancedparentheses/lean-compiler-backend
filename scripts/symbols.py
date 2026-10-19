#!/usr/bin/env python3
"""Ordinary Mach-O symbol operands: Python memory, original QBE and native C.

C supplies strong global objects and function definitions. Pointer results are
checked relationally; no ASLR address is treated as a numerical oracle. This
qualifies ordinary symbol references, not top-level data, TLS, GOT or relocation
addends. Symbol evaluation deliberately has no abstract interpreter model.
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import time
import traceback
from fuzz import ROOT, LCB, run, native_host, compile_and_run, inputs

MASK = (1 << 64) - 1
GLOBALS = ('symbol_data','symbol_other','symbol_out')
SIZE = 96


@dataclass
class Case:
    name: str
    body: str
    expected: object
    reference: str
    pointer: int = 0
    offset: object = lambda a,b: 0

    def source(self):
        return f'export function l ${self.name}(l %a,l %b) {{\n{self.body}\n}}\n'


def read(memory, offset, size):
    return int.from_bytes(memory[offset:offset+size],'little')


def write(memory, offset, size, value):
    memory[offset:offset+size] = (value & ((1 << (size*8))-1)).to_bytes(size,'little')


def initial(variant):
    return [bytearray((i*37+variant*101)&255 for i in range(SIZE)),
            bytearray((i*19+variant*17+93)&255 for i in range(SIZE)),
            bytearray((i*7+variant*53+165)&255 for i in range(SIZE))]


def fixed_cases():
    cases = [
        Case('symbol_copy','@entry\n %p =l copy $symbol_data\n %same =l ceql %p,$symbol_data\n ret %same',
             lambda a,b,m:1,'return (uintptr_t)symbol_data==(uintptr_t)symbol_data;'),
        Case('symbol_distinct','@entry\n %r =l cnel $symbol_data,$symbol_other\n ret %r',
             lambda a,b,m:1,'return (uintptr_t)symbol_data!=(uintptr_t)symbol_other;'),
        Case('symbol_return','@entry\n ret $symbol_data',lambda a,b,m:1,
             'return (uintptr_t)symbol_data;',1),
        Case('symbol_offset_return','''@entry
 %offset =l and %a,63
 %p =l add $symbol_data,%offset
 ret %p''',lambda a,b,m:1,'return (uintptr_t)(symbol_data+(a&63));',1,lambda a,b:a&63),
        Case('symbol_c_function','@entry\n ret $c_symbol_anchor',lambda a,b,m:1,
             'return (uintptr_t)&c_symbol_anchor;',4),
        Case('symbol_local_function','@entry\n ret $symbol_local_anchor',lambda a,b,m:1,
             'return (uintptr_t)&symbol_local_anchor;',5),
        Case('symbol_known_call','''@entry
 %same =l call $c_is_local(l $symbol_local_anchor)
 %called =l call $symbol_local_anchor(l %a)
 %r =l xor %same,%called
 ret %r''',lambda a,b,m:((a*3+7)&MASK)^1,
             'return (symbol_local_anchor(a))^c_is_local((uintptr_t)&symbol_local_anchor);'),
        Case('symbol_address_call','''@entry
 %r =l call $c_is_data(l $symbol_data,l 0)
 ret %r''',lambda a,b,m:1,'return c_is_data((uintptr_t)symbol_data,0);'),
        Case('symbol_offset_call','''@entry
 %offset =l and %a,63
 %p =l add $symbol_data,%offset
 %r =l call $c_is_data(l %p,l %offset)
 ret %r''',lambda a,b,m:1,'return c_is_data((uintptr_t)(symbol_data+(a&63)),a&63);'),
        Case('symbol_word_load','''@entry
 %v =w loaduw $symbol_data
 %r =l extuw %v
 ret %r''',lambda a,b,m:read(m[0],0,4),'return read_bytes(symbol_data,4);'),
        Case('symbol_long_load','''@entry
 %offset =l and %a,63
 %p =l add $symbol_data,%offset
 %r =l load %p
 ret %r''',lambda a,b,m:read(m[0],a&63,8),'return read_bytes(symbol_data+(a&63),8);'),
        Case('symbol_pointer_store','''@entry
 %slot =l alloc8 8
 storel $symbol_data,%slot
 %p =l load %slot
 %r =l ceql %p,$symbol_data
 ret %r''',lambda a,b,m:1,
             'uintptr_t pointer=(uintptr_t)symbol_data; return pointer==(uintptr_t)symbol_data;'),
        Case('symbol_phi','''@entry
 %c =w and %a,1
 jnz %c,@yes,@no
@yes
 jmp @join
@no
 jmp @join
@join
 %base =l phi @yes $symbol_data,@no $symbol_other
 %offset =l and %b,63
 %p =l add %base,%offset
 %r =l load %p
 ret %r''',lambda a,b,m:read(m[0 if a&1 else 1],b&63,8),
             'return read_bytes(((a&1)?symbol_data:symbol_other)+(b&63),8);'),
        Case('symbol_loop','''@entry
 %limit =l and %a,15
 jmp @loop
@loop
 %i =l phi @entry 0,@body %next
 %p =l phi @entry $symbol_data,@body %nextpointer
 %sum =l phi @entry 0,@body %updated
 %more =w cultl %i,%limit
 jnz %more,@body,@end
@body
 %byte =l loadub %p
 %updated =l add %sum,%byte
 %nextpointer =l add %p,1
 %next =l add %i,1
 jmp @loop
@end
 ret %sum''',lambda a,b,m:sum(m[0][:a&15]),
             'uint64_t r=0; for(unsigned i=0;i<(a&15);++i) r+=symbol_data[i]; return r;'),
        Case('symbol_loop_call','''@entry
 %limit =l and %a,15
 jmp @loop
@loop
 %i =l phi @entry 0,@body %next
 %sum =l phi @entry 0,@body %updated
 %more =w cultl %i,%limit
 jnz %more,@body,@end
@body
 %byte =l call $c_read_byte(l $symbol_data,l %i)
 %updated =l add %sum,%byte
 %next =l add %i,1
 jmp @loop
@end
 ret %sum''',lambda a,b,m:sum(m[0][:a&15]),
             'uint64_t r=0; for(unsigned i=0;i<(a&15);++i) r+=c_read_byte((uintptr_t)symbol_data,i); return r;'),
    ]
    for size,op in [(1,'storeb'),(2,'storeh'),(4,'storew'),(8,'storel')]:
        def expected(a,b,m,size=size):
            write(m[0],a&63,size,b)
            return read(m[0],a&63,8)
        cases.append(Case(f'symbol_{op}',f'''@entry
 %offset =l and %a,63
 %p =l add $symbol_data,%offset
 {op} %b,%p
 %r =l load %p
 ret %r''',expected,f'write_bytes(symbol_data+(a&63),{size},b); return read_bytes(symbol_data+(a&63),8);'))
    def copy(a,b,m):
        m[2][:16]=m[0][:16]
        return read(m[2],0,8)
    cases.append(Case('symbol_blit','''@entry
 blit $symbol_data,$symbol_out,16
 %r =l load $symbol_out
 ret %r''',copy,'memcpy(symbol_out,symbol_data,16); return read_bytes(symbol_out,8);'))
    return cases


def generated_case(seed,index):
    rng=random.Random(seed*65537+index)
    lines,actions,reference=['@entry'],[],['uint64_t r=0;']
    for step in range(6):
        source,target=rng.randrange(3),rng.randrange(3)
        size,bias=rng.choice((1,2,4,8)),rng.getrandbits(64)
        offset_bias=rng.getrandbits(6)
        lines += [f' %offsetraw{step} =l xor %a,{offset_bias}',
                  f' %offset{step} =l and %offsetraw{step},63',
                  f' %target{step} =l add ${GLOBALS[target]},%offset{step}',
                  f' %value{step} =l xor %b,{bias}',
                  f' store{ {1:"b",2:"h",4:"w",8:"l"}[size]} %value{step},%target{step}',
                  f' %source{step} =l add ${GLOBALS[source]},%offset{step}',
                  f' %loaded{step} =l load %source{step}',
                  f' %acc{step} =l xor {"0" if step==0 else "%acc"+str(step-1)},%loaded{step}']
        actions.append((source,target,size,bias,offset_bias))
        reference += [f'write_bytes({GLOBALS[target]}+((a^{offset_bias})&63),{size},b^UINT64_C({bias}));',
                      f'r^=read_bytes({GLOBALS[source]}+((a^{offset_bias})&63),8);']
    lines.append(' ret %acc5')
    reference.append('return r;')
    def expected(a,b,m):
        result=0
        for source,target,size,bias,offset_bias in actions:
            offset=(a^offset_bias)&63
            write(m[target],offset,size,b^bias)
            result^=read(m[source],offset,8)
        return result
    return Case(f'symbol_generated_{seed}_{index}','\n'.join(lines),expected,'\n'.join(reference))


COMMON = '''#include <stdint.h>
#include <string.h>
unsigned char symbol_data[96],symbol_other[96],symbol_out[96];
uint64_t symbol_local_anchor(uint64_t);
uint64_t c_symbol_anchor(uint64_t value) { return value*5+11; }
uint64_t c_is_data(uint64_t pointer,uint64_t offset) {
 return pointer==(uintptr_t)(symbol_data+offset);
}
uint64_t c_is_local(uint64_t pointer) { return pointer==(uintptr_t)&symbol_local_anchor; }
uint64_t c_read_byte(uint64_t pointer,uint64_t offset) {
 return ((const unsigned char *)(uintptr_t)pointer)[offset];
}
static uint64_t read_bytes(const unsigned char *p,unsigned size) {
 uint64_t result=0; for(unsigned i=0;i<size;++i) result|=(uint64_t)p[i]<<(8*i); return result;
}
static void write_bytes(unsigned char *p,unsigned size,uint64_t value) {
 for(unsigned i=0;i<size;++i) p[i]=(unsigned char)(value>>(8*i));
}
'''
LOCAL = '''export function l $symbol_local_anchor(l %value) {
@entry
 %m =l mul %value,3
 %r =l add %m,7
 ret %r
}
'''


def driver(cases,arguments):
    declarations='\n'.join(f'extern uint64_t {case.name}(uint64_t,uint64_t);' for case in cases)
    records,expected,manifest=[],[],[]
    for case in cases:
        for index,(a,b) in enumerate(arguments):
            variant=index%4
            memory=initial(variant)
            result=case.expected(a,b,memory)
            expected.append(result)
            buffers=','.join('{'+','.join(map(str,buffer))+'}' for buffer in memory)
            records.append(f'{{{case.name},UINT64_C({a}),UINT64_C({b}),{variant},{case.pointer},{case.offset(a,b)},'
                           + '{'+buffers+'}}')
            manifest.append({'function':case.name,'arguments':[a,b],'variant':variant,
                             'result':result,'pointer_kind':case.pointer,'memory':[list(buffer) for buffer in memory]})
    caller=f'''#include <stdio.h>
#include <inttypes.h>
{declarations}
struct entry {{
 uint64_t (*run)(uint64_t,uint64_t);
 uint64_t a,b;
 unsigned variant,pointer,offset;
 unsigned char wanted[3][96];
}};
static const struct entry cases[]={{
'''+',\n'.join(records)+'''
};
int main(void) {
 for(unsigned n=0;n<sizeof cases/sizeof cases[0];++n) {
  const struct entry *e=&cases[n];
  for(unsigned i=0;i<96;++i) {
   symbol_data[i]=(unsigned char)(i*37+e->variant*101);
   symbol_other[i]=(unsigned char)(i*19+e->variant*17+93);
   symbol_out[i]=(unsigned char)(i*7+e->variant*53+165);
  }
  uint64_t result=e->run(e->a,e->b);
  if(e->pointer) {
   uintptr_t pointer;
   switch(e->pointer) {
    case 1:pointer=(uintptr_t)(symbol_data+e->offset);break;
    case 2:pointer=(uintptr_t)(symbol_other+e->offset);break;
    case 3:pointer=(uintptr_t)(symbol_out+e->offset);break;
    case 4:pointer=(uintptr_t)&c_symbol_anchor;break;
    default:pointer=(uintptr_t)&symbol_local_anchor;break;
   }
   result=result==pointer;
  }
  if(memcmp(symbol_data,e->wanted[0],96) || memcmp(symbol_other,e->wanted[1],96) ||
     memcmp(symbol_out,e->wanted[2],96)) return 2;
  printf("%" PRIu64 "\\n",result);
 }
 return 0;
}
'''
    return caller,expected,manifest


def controls(work):
    source,output=work/'control.ssa',work/'control.s'
    word = [
        'function w $f() { @s %r =w copy $symbol_data ret %r }',
        'function w $f() { @s %r =w add $symbol_data,0 ret %r }',
        'function w $f() { @s %r =w ceqw $symbol_data,0 ret %r }',
        'function w $f(l %p) { @s storew $symbol_data,%p ret 0 }',
        'function w $f() { @s %r =w call $external(w $symbol_data) ret %r }',
        'function w $f() { @s ret $symbol_data }',
    ]
    syntax = [
        'data $symbol_data = { b 1 }',
        'function l $f() { @s %p =l copy $symbol_data+4 ret %p }',
        'function l $f() { @s %p =l copy extern $symbol_data ret %p }',
        'function l $f() { @s %p =l copy thread $symbol_data ret %p }',
        'function l $f() { @s %p =l copy $"quoted" ret %p }',
        'function l $f() { @s %p =l copy $symbol_data %r =l call %p() ret %r }',
    ]
    for text in word+syntax:
        source.write_text(text)
        result=subprocess.run([LCB,source,'-o',output],text=True,capture_output=True,timeout=30)
        assert result.returncode and not output.exists(),(text,result.stderr)
        if text in word: assert 'require a long context' in result.stderr,result.stderr
    models = [
        'function l $f() { @s ret $symbol_data }',
        'function l $f() { @s %p =l copy $symbol_data ret %p }',
        'function l $f() { @s %r =l load $symbol_data ret %r }',
        'function l $f() { @s %p =l alloc8 8 storel $symbol_data,%p ret 0 }',
        'function l $f() { @s storel 0,$symbol_data ret 0 }',
        'function l $f() { @s %r =l call $external(l $symbol_data) ret %r }',
        'function l $f() { @s jmp @join @join %p =l phi @s $symbol_data ret %p }',
        'function l $anchor() { @s ret 3 } function l $f() { @s ret $anchor }',
        'function l $f() { @s blit $symbol_data,0,0 ret 0 }',
    ]
    for text in models:
        source.write_text(text)
        run([LCB,'--check',source])
        result=subprocess.run([LCB,'--eval',source,'f'],text=True,capture_output=True,timeout=30)
        assert result.returncode and 'symbol operand $' in result.stderr and 'no interpreter model' in result.stderr,result.stderr
    return len(word)+len(syntax),len(models)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    parser.add_argument('--seed',type=int,action='append')
    options=parser.parse_args()
    if options.require_native: assert native_host(),'required native host unavailable'
    seeds=options.seed or [20261019,20261020]
    cases=fixed_cases()+[generated_case(seed,index) for seed in seeds for index in range(8)]
    arguments=inputs(20261019,8)
    with tempfile.TemporaryDirectory(prefix='lcb-symbols-') as directory:
        work=Path(directory)
        try:
            rejected,no_model=controls(work)
            source=work/'input.ssa'
            source.write_text(LOCAL+''.join(case.source() for case in cases))
            run([LCB,'--check',source])
            caller,expected,manifest=driver(cases,arguments)
            (work/'case.json').write_text(json.dumps({'seeds':seeds,'cases':manifest,
                'compiler_sha256':hashlib.sha256(LCB.read_bytes()).hexdigest(),
                'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'upstream_lock_sha256':hashlib.sha256((ROOT/'upstream-lock.json').read_bytes()).hexdigest(),
                'flake_lock_sha256':hashlib.sha256((ROOT/'flake.lock').read_bytes()).hexdigest(),
                'target':'aarch64-macos'},indent=2))
            if native_host():
                oracle=work/'oracle'
                shutil.copytree(ROOT/'third_party/qbe',oracle)
                run(['make','-j2',f'CC={os.environ["LCB_CC"]}'],cwd=oracle)
                assembly,qasm,cfile=work/'lean.s',work/'qbe.s',work/'caller.c'
                cfile.write_text(COMMON+caller)
                run([LCB,source,'-o',assembly])
                run([oracle/'qbe','-t','arm64_apple','-o',qasm,source])
                for label,asm in [('lean',assembly),('qbe',qasm)]:
                    actual=compile_and_run(os.environ['LCB_CC'],asm,cfile,work/label)
                    (work/f'{label}-output.json').write_text(json.dumps(actual))
                    assert actual==expected,(label,next((i for i,pair in enumerate(zip(actual,expected)) if pair[0]!=pair[1]),None))
                reference=work/'reference.c'
                reference.write_text(COMMON+'uint64_t symbol_local_anchor(uint64_t value) { return value*3+7; }\n'
                    +'\n'.join(f'uint64_t {case.name}(uint64_t a,uint64_t b) {{ {case.reference} }}' for case in cases)+'\n'+caller)
                run([os.environ['LCB_CC'],'-std=c11','-O2',reference,'-o',work/'reference'])
                actual=[int(line) for line in run([work/'reference']).splitlines()]
                (work/'c-output.json').write_text(json.dumps(actual))
                assert actual==expected,('C reference',next((i for i,pair in enumerate(zip(actual,expected)) if pair[0]!=pair[1]),None))
                # Redirect both halves of data-address relocations to another real
                # object, so wrong addressing must trip exact-byte state checks.
                text=assembly.read_text()
                assert '_symbol_data@PAGE' in text and '_symbol_data@PAGEOFF' in text
                changed=text.replace('_symbol_data@PAGE','_symbol_other@PAGE')
                mutant=work/'relocation-corrupt.s'
                mutant.write_text(changed)
                executable=work/'relocation-corrupt'
                run([os.environ['LCB_CC'],'-std=c11','-O2',cfile,mutant,'-o',executable])
                result=subprocess.run([executable],text=True,capture_output=True,timeout=120)
                assert result.returncode==2,'address-relocation corruption escaped exact-byte checks'
        except Exception:
            target=ROOT/'.build/symbol-failures'/f'run-{time.time_ns()}'
            target.mkdir(parents=True,exist_ok=True)
            for path in work.iterdir():
                if path.suffix in ('.ssa','.s','.c','.json'): shutil.copy2(path,target/path.name)
            (target/'failure.txt').write_text(traceback.format_exc())
            print(f'SYMBOL FAILURE: retained {target}',flush=True)
            raise
    print(f'symbol operands: {len(cases)} entry functions ({len(seeds)*8} generated), '
          f'{rejected} static rejection controls, {no_model} explicit no-interpreter-model controls; '+
          (f'{len(expected)} native cases per Lean/original-QBE/C backend; all 288 global bytes checked per case; '
           'pointer identities checked relationally; address-relocation corruption detected'
           if native_host() else 'native not measured'))


if __name__=='__main__': main()
