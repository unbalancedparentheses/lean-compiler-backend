#!/usr/bin/env python3
"""Check exact blit extents against inaccessible POSIX guard pages."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from fuzz import LCB, native_host

# Put 129 first so the ARM64 corruption control widens its one-byte loop tail.
SIZES = [129, 0, 1, 7, 8, 9, 127, 128, 130, 131, 132, 133, 134, 135, 136,
         4095, 4096, 4097, 16383, 16384, 16385, 65535, 65536, 65537,
         1048569, 1048575, 1048576]


def inputs():
    ir = '\n'.join(f'''export function $guard_copy_{size}(l %src,l %dst) {{
@s
 blit %src,%dst,{size}
 ret
}}
''' for size in SIZES)
    declarations = '\n'.join(f'extern void guard_copy_{n}(void *,void *);' for n in SIZES)
    entries = ','.join('{'+str(n)+',guard_copy_'+str(n)+'}' for n in SIZES)
    caller = r'''#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <unistd.h>
#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif
''' + declarations + r'''
typedef void (*copy_fn)(void *,void *);
static const struct {size_t size;copy_fn copy;} cases[]={''' + entries + r'''};
int main(void) {
 struct rlimit no_core={0,0};setrlimit(RLIMIT_CORE,&no_core);
 long page_value=sysconf(_SC_PAGESIZE);if(page_value<=0)return 90;
 size_t page=(size_t)page_value;
 size_t capacity=((1048576+page-1)/page)*page,total=capacity+2*page;
 unsigned char *am=mmap(0,total,PROT_NONE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
 unsigned char *bm=mmap(0,total,PROT_NONE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
 if(am==MAP_FAILED||bm==MAP_FAILED)return 91;
 unsigned char *a=am+page,*b=bm+page;
 if(mprotect(a,capacity,PROT_READ|PROT_WRITE)||mprotect(b,capacity,PROT_READ|PROT_WRITE))return 92;
 unsigned char *before=malloc(capacity),*expected=malloc(capacity);
 if(!before||!expected)return 93;
 /* Zero bytes must not dereference even wholly inaccessible operands. */
 guard_copy_0(am,bm);guard_copy_0(am,am);
 for(size_t c=0;c<sizeof(cases)/sizeof(cases[0]);c++) {
  size_t n=cases[c].size;
  /* Independently put each extent against its start or end guard. End guards
     detect overreads as well as overwrites, including unaligned short tails. */
  for(unsigned source_end=0;source_end<2;source_end++) {
   for(unsigned destination_end=0;destination_end<2;destination_end++) {
    for(size_t i=0;i<capacity;i++) {
     a[i]=(unsigned char)((i*131u+(i>>8)+c*17u)^source_end);
     b[i]=(unsigned char)(i*37u+c+99u);
    }
    size_t from=source_end?capacity-n:0,to=destination_end?capacity-n:0;
    memcpy(before,a,capacity);memcpy(expected,b,capacity);
    memcpy(expected+to,a+from,n);
    cases[c].copy(a+from,b+to);
    if(memcmp(a,before,capacity)||memcmp(b,expected,capacity))return 1;
   }
  }
  /* Identical ranges are valid; partial overlap is intentionally excluded. */
  for(unsigned end=0;end<2;end++) {
   size_t offset=end?capacity-n:0;
   memcpy(before,a,capacity);cases[c].copy(a+offset,a+offset);
   if(memcmp(a,before,capacity))return 2;
  }
 }
 free(before);free(expected);
 if(munmap(am,total)||munmap(bm,total))return 94;
 return 0;
}
'''
    return ir, caller


def exercise(compiler, work, run, cc, target, execute=True):
    case = Path(work) / 'blit-guard-pages'
    case.mkdir(exist_ok=True)
    source, caller = case / 'input.ssa', case / 'caller.c'
    ir, c = inputs()
    source.write_text(ir)
    caller.write_text(c)
    caller_object = case / 'caller.o'
    if execute:
        result = run([cc, '-O2', '-c', caller, '-o', caller_object], True)
        assert result.returncode == 0, result.stderr
    for label, flags in [('baseline', []), ('allocated', ['--allocate']), ('optimized', ['--optimize'])]:
        asm, exe = case / (label + '.s'), case / label
        result = run([compiler, source, '--target', target, *flags, '-o', asm])
        assert result.returncode == 0, (target, label, result.stderr)
        if not execute:
            continue
        result = run([cc, caller_object, asm, '-o', exe], True)
        assert result.returncode == 0, result.stderr
        result = run([exe], True)
        assert result.returncode == 0, (target, label, result.returncode, result.stderr)
        if target.startswith('aarch64') and label == 'allocated':
            original = asm.read_text()
            tail = '\tldrb w11, [x9, #0]'
            assert tail in original, 'expected one-byte ARM64 blit tail'
            # Widen only the read, retaining the following byte store. The low
            # byte remains correct, so ordinary byte comparisons cannot detect
            # this defect. The source end guard must fault on the extra bytes.
            damaged = original.replace(tail, '\tldr x11, [x9, #0]', 1)
            bad, badexe = case / 'tail-overread.s', case / 'tail-overread'
            bad.write_text(damaged)
            result = run([cc, caller_object, bad, '-o', badexe], True)
            assert result.returncode == 0, result.stderr
            result = run([badexe], True)
            assert result.returncode in (-11, -10, -7, 139, 138, 135), (
                'tail overread must fault against a guard page', result.returncode, result.stderr)
    print(f'{target}: blit guard pages: {len(SIZES)} sizes, {len(SIZES)*6} start/end '
          f'disjoint/identical cases per mode plus protected zero copies; execution={execute}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-native', action='store_true')
    args = parser.parse_args()
    if args.require_native:
        assert native_host()
    def run(cmd, inside=False):
        return subprocess.run(list(map(str, cmd)), capture_output=True, text=True, timeout=120)
    with tempfile.TemporaryDirectory(prefix='lcb-blit-guards-') as directory:
        exercise(LCB, Path(directory), run, os.environ.get('LCB_CC', 'cc'),
                 'aarch64-macos', native_host())


if __name__ == '__main__':
    main()
