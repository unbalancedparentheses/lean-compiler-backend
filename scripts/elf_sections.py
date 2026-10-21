"""ELF section/constructor/common-linkage cases for Linux target qualification."""
from pathlib import Path

SOURCE = '''common export data $counter = align 64 { z 64 }
section ".lcb_data" "aw"
data $value = { l 40 }
section ".lcb_code" "ax"
export function l $section_entry() {
@start
 %v =l loadl $value
 %r =l add %v, 2
 ret %r
}
function $initialize() {
@start
 storel 37, $counter
 ret
}
section ".init_array"
data $initializer = { l $initialize }
'''
CALLER = '''#include <stdint.h>
extern uint64_t counter[8], section_entry(void);
int main(void) { return counter[0]!=37 || section_entry()!=42 || (uintptr_t)counter%64; }
'''


def exercise(compiler, work, run, cc, qbe, native):
    case = Path(work)/'elf-sections'; case.mkdir(exist_ok=True)
    source, assembly, caller = case/'input.ssa', case/'lean.s', case/'caller.c'
    source.write_text(SOURCE); caller.write_text(CALLER)
    result = run([compiler, source, '--target', 'aarch64-linux', '-o', assembly])
    assert result.returncode == 0, result.stderr
    text = assembly.read_text()
    assert '.section .lcb_data,"aw"' in text and '.section .lcb_code,"ax"' in text
    assert '.comm counter,64,64' in text
    result = run([compiler, '--target', 'aarch64-macos', source, '-o', case/'wrong.s'])
    assert result.returncode != 0 and 'selected object format' in result.stderr
    for content, reason in [
        (SOURCE.replace('.lcb_data', r'.bad\n.globl injected'), 'ASCII'),
        (SOURCE.replace('"aw"', '"aT"'), 'ELF section flags'),
        (SOURCE.replace('"aw"', '"aw,extra"'), 'optional awx flags'),
        (SOURCE.replace('.lcb_data', '.'+'x'*128), 'ASCII'),
    ]:
        bad = case/'bad.ssa'; bad.write_text(content)
        result = run([compiler, bad, '--target', 'aarch64-linux', '-o', case/'bad.s'])
        assert result.returncode != 0 and reason in result.stderr, result.stderr
    profile = case/'profile.ssa'
    profile.write_text('section "__TEXT" "__custom" function w $f() { @entry ret 0 }')
    result = run([compiler, '--first-path', profile])
    assert result.returncode != 0 and 'custom sections' in result.stderr, result.stderr
    if native:
        qasm = case/'qbe.s'; result = run([qbe, '-t', 'arm64', '-o', qasm, source], True)
        assert result.returncode == 0, result.stderr
        for label, asm in [('lean', assembly), ('qbe', qasm)]:
            obj, exe = case/f'{label}.o', case/label
            result = run([cc, '-c', asm, '-o', obj], True); assert result.returncode == 0, result.stderr
            tool = run(['sh', '-c', 'command -v llvm-readelf || command -v readelf'], True).stdout.strip()
            result = run([tool, '-SW', obj], True); assert result.returncode == 0, result.stderr
            for name in ['.lcb_data', '.lcb_code', '.init_array', '.text']:
                assert name in result.stdout, result.stdout
            result = run([cc, caller, obj, '-o', exe], True); assert result.returncode == 0, result.stderr
            result = run([exe], True); assert result.returncode == 0, (label, result.returncode, result.stderr)
    print('ELF sections: target-specific syntax, named code/data, init-array constructors and common alignment passed; native='+str(native), flush=True)
