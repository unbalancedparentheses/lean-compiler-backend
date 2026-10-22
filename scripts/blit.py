#!/usr/bin/env python3
"""QBE blit qualification: independent byte arrays, Lean, C and original QBE.

Only defined spans are executed natively. Interpreter refusal of partial overlap,
unknown reads or external spans is not a promise of corresponding native checks.
Failures retain input, emitted code, seeds and tool/source hashes.
"""
import argparse
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
FIXED_SIZES = (0, 1, 2, 3, 4, 7, 8, 9, 15, 16, 17, 31, 32, 63, 64, 65,
               127, 128, 255, 256, 511, 512, 1023, 1024, 2047, 2048, 4095, 4096)
BUFFER = 8256


def hash_bytes(values):
    result = 14695981039346656037
    for value in values:
        result = ((result ^ value) * 1099511628211) & MASK
    return result


def external_source(sizes):
    return ''.join(f'''export function w $blit_{size}(l %source,l %destination) {{
@entry
 blit %source,%destination,{size}
 ret 0
}}
''' for size in sizes)


def external_cases(sizes):
    """Separated arrays, same-object disjoint spans, then identical spans."""
    cases = []
    for size in sizes:
        for variant in range(3):
            for source, destination in [(0, 0), (1, 3), (7, 9), (15, 1)]:
                cases.append((size, 0, source + 16, destination + 16, variant))
            for offset, gap in [(0, 0), (1, 3), (7, 17)]:
                source = 16 + offset
                cases.append((size, 1, source, source + size + gap, variant))
            for offset in (1, 7):
                cases.append((size, 2, 16 + offset, 16 + offset, variant))
    return cases


def external_expected(cases):
    result = []
    for size, kind, source, destination, variant in cases:
        left = bytearray((i * 37 + variant * 101) & 255 for i in range(BUFFER))
        right = bytearray((i * 19 + variant * 53 + 165) & 255 for i in range(BUFFER))
        copied = left[source:source + size]
        target = right if kind == 0 else left
        target[destination:destination + size] = copied
        result.append(hash_bytes(left + right))
    return result


def external_driver(sizes, cases):
    declarations = '\n'.join(f'extern uint32_t blit_{size}(uint64_t,uint64_t);' for size in sizes)
    calls = '\n'.join(f' if(one(blit_{size},{size},{kind},{source},{destination},{variant})) return 2;'
                      for size,kind,source,destination,variant in cases)
    return f'''#include <stdint.h>
#include <stdio.h>
#include <inttypes.h>
#include <string.h>
{declarations}
static int one(uint32_t (*copy)(uint64_t,uint64_t), unsigned n, unsigned kind,
               unsigned source, unsigned destination, unsigned variant) {{
 unsigned char a[{BUFFER}],b[{BUFFER}],wanted_a[{BUFFER}],wanted_b[{BUFFER}];
 for(unsigned i=0;i<{BUFFER};++i) {{
  a[i]=wanted_a[i]=(unsigned char)(i*37+variant*101);
  b[i]=wanted_b[i]=(unsigned char)(i*19+variant*53+165);
 }}
 unsigned char *d=kind ? a : b;
 unsigned char *wanted=kind ? wanted_a : wanted_b;
 /* Snapshot source bytes independently of destination updates. */
 unsigned char saved[4096];
 for(unsigned i=0;i<n;++i) saved[i]=wanted_a[source+i];
 for(unsigned i=0;i<n;++i) wanted[destination+i]=saved[i];
 if(copy((uint64_t)(uintptr_t)(a+source),(uint64_t)(uintptr_t)(d+destination))) return 1;
 for(unsigned i=0;i<{BUFFER};++i)
  if(a[i]!=wanted_a[i] || b[i]!=wanted_b[i]) return 1;
 uint64_t checksum=UINT64_C(14695981039346656037);
 for(unsigned i=0;i<{BUFFER};++i) checksum=(checksum^a[i])*UINT64_C(1099511628211);
 for(unsigned i=0;i<{BUFFER};++i) checksum=(checksum^b[i])*UINT64_C(1099511628211);
 printf("%" PRIu64 "\\n",checksum);
 return 0;
}}
int main(void) {{
{calls}
 /* Zero length must not dereference even null or non-object addresses. */
 if(blit_0(0,UINT64_MAX)) return 3;
 return 0;
}}
'''


def external_reference(sizes):
    return '#include <stdint.h>\n' + ''.join(f'''
uint32_t blit_{size}(uint64_t source,uint64_t destination) {{
 const unsigned char *s=(const unsigned char *)(uintptr_t)source;
 unsigned char *d=(unsigned char *)(uintptr_t)destination;
 if(s!=d) for(unsigned i=0;i<{size};++i) d[i]=s[i];
 return 0;
}}
''' for size in sizes)


def internal_source(size):
    """Loop-based initialization keeps the SSA small for large copied spans."""
    length = size + 16
    return f'''export function l $internal_{size}(l %a,l %b) {{
@entry
 %source =l alloc16 {length}
 %destination =l alloc16 {length}
 jmp @fill
@fill
 %i =l phi @entry 0,@put %next
 %again =w cultl %i,{length}
 jnz %again,@put,@copystart
@put
 %sp =l add %source,%i
 %dp =l add %destination,%i
 %scaled =l mul %i,37
 %sv =l add %scaled,%a
 %dv =l xor %i,%b
 storeb %sv,%sp
 storeb %dv,%dp
 %next =l add %i,1
 jmp @fill
@copystart
 %s =l add %source,1
 %d =l add %destination,3
 blit %s,%d,{size}
 jmp @read
@read
 %j =l phi @copystart 0,@get %jnext
 %acc =l phi @copystart 0,@get %updated
 %more =w cultl %j,{length}
 jnz %more,@get,@end
@get
 %rs =l add %source,%j
 %rd =l add %destination,%j
 %sb =l loadub %rs
 %db =l loadub %rd
 %scaledacc =l mul %acc,257
 %withsource =l add %scaledacc,%sb
 %scaledsource =l mul %withsource,257
 %updated =l add %scaledsource,%db
 %jnext =l add %j,1
 jmp @read
@end
 ret %acc
}}
'''


def internal_expected(size, a, b):
    source = bytearray((37 * i + a) & 255 for i in range(size + 16))
    destination = bytearray((i ^ b) & 255 for i in range(size + 16))
    destination[3:3 + size] = source[1:1 + size]
    result = 0
    for left,right in zip(source,destination):
        result = (((result * 257 + left) * 257) + right) & MASK
    return result


def internal_driver(sizes, arguments):
    lines = ['#include <stdint.h>', '#include <stdio.h>', '#include <inttypes.h>']
    lines += [f'extern uint64_t internal_{size}(uint64_t,uint64_t);' for size in sizes]
    lines += ['int main(void) {']
    for size in sizes:
        for a,b in arguments:
            lines.append(f'printf("%" PRIu64 "\\n",internal_{size}(UINT64_C({a}),UINT64_C({b})));')
    return '\n'.join(lines + ['return 0;', '}']) + '\n'


def internal_reference(sizes):
    return '#include <stdint.h>\n' + ''.join(f'''
uint64_t internal_{size}(uint64_t a,uint64_t b) {{
 unsigned char source[{size+16}],destination[{size+16}];
 for(unsigned i=0;i<{size+16};++i) {{ source[i]=(unsigned char)(37*i+a); destination[i]=(unsigned char)(i^b); }}
 for(unsigned i=0;i<{size};++i) destination[3+i]=source[1+i];
 uint64_t result=0;
 for(unsigned i=0;i<{size+16};++i) result=(result*257+source[i])*257+destination[i];
 return result;
}}
''' for size in sizes)


def controls(work):
    source, output = work/'control.ssa',work/'control.s'
    static = [
        ('function w $f(l %p) { @entry blit %p,%p,-1 ret 0 }', 'must be nonnegative'),
        ('function w $f(l %p,l %n) { @entry blit %p,%p,%n ret 0 }', 'numeric constant'),
        ('function w $f(l %p) { @entry blit %p,%p,1048577 ret 0 }', '1 MiB resource limit'),
        ('function w $f(w %p) { @entry blit %p,0,1 ret 0 }', 'w-to-l'),
        ('function w $f(w %p) { @entry blit 0,%p,1 ret 0 }', 'w-to-l'),
        ('function w $f() { @entry blit %missing,0,1 ret 0 }', 'undefined temporary'),
        ('function w $f() { @entry %r =l blit 0,0,1 ret 0 }', 'unsupported operation'),
        ('function w $f() { @entry blit 0 0,1 ret 0 }', "expected ','"),
    ]
    for text,message in static:
        source.write_text(text)
        result = subprocess.run([str(LCB), '--target', 'aarch64-macos',str(source),'-o',str(output)],text=True,capture_output=True,timeout=30)
        assert result.returncode and message in result.stderr and not output.exists(), (message,result.stderr)
    undefined = [
        ('%p =l alloc16 16 %q =l add %p,1 blit %p,%q,8', 'partially overlapping'),
        ('%p =l alloc16 16 %q =l add %p,1 blit %q,%p,8', 'partially overlapping'),
        ('%p =l alloc16 8 %q =l alloc16 8 blit %p,%q,9', 'outside an allocated object'),
        ('%p =l alloc16 16 %q =l alloc16 8 blit %p,%q,9', 'outside an allocated object'),
        ('%p =l alloc16 8 blit 0,%p,1', 'outside an allocated object'),
        ('blit 0,0,1', 'outside an allocated object'),
        ('%p =l alloc16 8 %q =l alloc16 8 storel 0,%q blit %p,%q,8 %r =w loadub %q', 'uninitialized'),
        ('%p =l alloc16 8 %q =l alloc16 8 storeb 42,%p blit %p,%q,8 %r =l load %q', 'uninitialized'),
    ]
    for body,message in undefined:
        source.write_text(f'function w $f() {{ @entry {body} ret 0 }}')
        result = subprocess.run([str(LCB),'--eval',str(source),'f'],text=True,capture_output=True,timeout=30)
        assert result.returncode and message in result.stderr, (message,result.stderr)
    defined = [
        ('blit 0,-1,0', '0', 0),
        ('%p =l alloc16 8 %q =l alloc16 8 blit %p,%q,8', '7', 7),
        ('%p =l alloc16 8 blit %p,%p,8', '7', 7),
        ('%p =l alloc16 8 %q =l alloc16 8 storeb 42,%p blit %p,%q,8 %r =w loadub %q', '%r', 42),
        ('%p =l alloc16 16 %q =l add %p,8 storel 123,%p storel 0,%q blit %p,%q,8 %r =w loaduw %q', '%r', 123),
        ('%p =l alloc16 8 storel 123,%p blit %p,%p,8 %r =w loaduw %p', '%r', 123),
    ]
    for body,returned,wanted in defined:
        source.write_text(f'function w $f() {{ @entry {body} ret {returned} }}')
        assert int(run([LCB,'--eval',source,'f'])) == wanted
    return len(static),len(undefined),len(defined)


def native(work, source, caller, expected, qbe, label, reference):
    assembly,cfile,qasm = work/f'{label}-lean.s',work/f'{label}-caller.c',work/f'{label}-qbe.s'
    cfile.write_text(caller)
    run([LCB, '--target', 'aarch64-macos',source,'-o',assembly])
    run([qbe,'-t','arm64_apple','-o',qasm,source])
    for backend,asm in [('lean',assembly),('qbe',qasm)]:
        actual = compile_and_run(os.environ['LCB_CC'],asm,cfile,work/f'{label}-{backend}')
        (work/f'{label}-{backend}-output.json').write_text(json.dumps(actual))
        assert actual == expected, (label,backend,next((i for i,pair in enumerate(zip(actual,expected)) if pair[0]!=pair[1]),None))
    ref = work/f'{label}-reference.c'
    ref.write_text(reference + '\n' + caller)
    executable = work/f'{label}-reference'
    run([os.environ['LCB_CC'],'-std=c11','-O2',ref,'-o',executable])
    actual = [int(line) for line in run([executable]).splitlines()]
    (work/f'{label}-c-output.json').write_text(json.dumps(actual))
    assert actual == expected, (label,'C reference')
    return assembly,cfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native',action='store_true')
    parser.add_argument('--seed',type=int,default=20261019)
    options = parser.parse_args()
    if options.require_native: assert native_host(), 'required native host unavailable'
    rng = random.Random(options.seed)
    sizes = sorted(set(FIXED_SIZES) | {rng.randrange(4097) for _ in range(12)})
    internal_sizes = [size for size in sizes if size<=1024]
    arguments = inputs(options.seed,3)
    external = external_cases(sizes)
    interpreted = 0
    with tempfile.TemporaryDirectory(prefix='lcb-blit-') as directory:
        work,qbe = Path(directory),None
        try:
            manifest = {'seed':options.seed,'sizes':sizes,'arguments':arguments,
                'external_cases':external,'target':'aarch64-macos',
                'compiler_sha256':hashlib.sha256(LCB.read_bytes()).hexdigest(),
                'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'upstream_lock_sha256':hashlib.sha256((ROOT/'upstream-lock.json').read_bytes()).hexdigest(),
                'flake_lock_sha256':hashlib.sha256((ROOT/'flake.lock').read_bytes()).hexdigest()}
            (work/'case.json').write_text(json.dumps(manifest,indent=2))
            if native_host():
                oracle=work/'oracle'
                shutil.copytree(ROOT/'third_party/qbe',oracle)
                run(['make','-j2',f'CC={os.environ["LCB_CC"]}'],cwd=oracle)
                qbe=oracle/'qbe'
            rejected,undefined,defined = controls(work)
            source = work/'internal.ssa'
            source.write_text(''.join(internal_source(size) for size in internal_sizes))
            run([LCB,'--check',source])
            expected=[internal_expected(size,a,b) for size in internal_sizes for a,b in arguments]
            (work/'internal-expected.json').write_text(json.dumps(expected))
            for size in internal_sizes:
                for a,b in arguments[:3]:
                    assert int(run([LCB,'--eval',source,f'internal_{size}',a,b])) == internal_expected(size,a,b),(size,a,b)
                    interpreted += 1
            print(f'blit allocated-memory interpretation: {interpreted} cases passed',flush=True)
            if qbe:
                native(work,source,internal_driver(internal_sizes,arguments),expected,qbe,'internal',internal_reference(internal_sizes))
                source=work/'external.ssa'
                source.write_text(external_source(sizes))
                expected_external=external_expected(external)
                (work/'external-expected.json').write_text(json.dumps(expected_external))
                assembly,cfile=native(work,source,external_driver(sizes,external),expected_external,qbe,'external',external_reference(sizes))
                # Missing byte-tail stores must trip exact-byte/guard comparisons.
                text=assembly.read_text()
                changed=text.replace('\tstrb w11, [x10, #0]','\t// deliberately removed byte tail')
                assert changed!=text,'blit corruption control did not apply'
                mutant=work/'external-corrupt.s'
                mutant.write_text(changed)
                executable=work/'external-corrupt'
                run([os.environ['LCB_CC'],'-std=c11','-O2',cfile,mutant,'-o',executable])
                result=subprocess.run([executable],text=True,capture_output=True,timeout=120)
                assert result.returncode==2,'byte-tail corruption escaped guard-byte checks'
        except Exception:
            target=ROOT/'.build/blit-failures'/f'run-{time.time_ns()}'
            target.mkdir(parents=True,exist_ok=True)
            for path in work.iterdir():
                if path.suffix in ('.ssa','.s','.c','.json'): shutil.copy2(path,target/path.name)
            (target/'failure.txt').write_text(traceback.format_exc())
            print(f'BLIT FAILURE: retained {target}',flush=True)
            raise
    print(f'blit: {len(sizes)} copy sizes (0..4096; 12 seeded draws), {interpreted} allocated-memory interpreter cases; '
          f'{rejected} static rejections, {undefined} undefined-domain refusals, {defined} defined-state controls; '+
          (f'{len(expected)} allocated-memory native cases and {len(external)} C-owned-memory guard-byte cases per Lean/QBE/C backend; '
           'zero-length external pointers and byte-tail corruption detected'
           if qbe else 'native not measured'))


if __name__=='__main__': main()
