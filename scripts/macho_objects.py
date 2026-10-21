"""Mach-O sections, common coalescing/alignment and DWARF target checks."""
from pathlib import Path
import shutil
from linkage import SOURCE as LINKAGE
from debug_locations import SOURCE as DEBUG


def exercise(compiler, work, run, cc, qbe, target, qtarget):
    case = Path(work)/'macho-objects'
    case.mkdir(exist_ok=True)
    other = case/'other.s'
    other.write_text('.comm _shared,32,3\n')
    inputs = [
        ('linkage', LINKAGE, '#include <stdint.h>\nextern uint64_t shared[4],custom_value,ordinary_entry(void);\nint main(void){shared[3]=99;return ordinary_entry()!=42 || shared[0]!=42 || shared[3]!=99 || custom_value!=40;}\n'),
        ('debug', DEBUG, 'extern int debug_entry(int); int main(void){return debug_entry(40)!=42;}\n'),
        ('aligned', 'common data $aligned = align 64 { z 64 }', '#include <stdint.h>\nextern char aligned[64];int main(void){return (uintptr_t)aligned%64;}\n'),
    ]
    for name, text, c in inputs:
        source, caller = case/(name+'.ssa'), case/(name+'.c')
        source.write_text(text)
        caller.write_text(c)
        for label in ['lean', 'qbe']:
            assembly, obj, exe = [case/(name+'-'+label+suffix) for suffix in ['.s', '.o', '']]
            command = [compiler, source, '--target', target, '-o', assembly] if label == 'lean' else [qbe, '-t', qtarget, '-o', assembly, source]
            result = run(command)
            assert result.returncode == 0, result.stderr
            result = run([cc, '-c', assembly, '-o', obj])
            assert result.returncode == 0, result.stderr
            if name == 'linkage':
                objdump = shutil.which('llvm-objdump')
                result = run([objdump, '--section-headers', obj] if objdump else ['otool', '-l', obj])
                assert result.returncode == 0, result.stderr
                for section in ['__custom_data', '__custom_code', '__text']:
                    assert section in result.stdout, result.stdout
            if name == 'debug':
                dwarf = shutil.which('llvm-dwarfdump') or shutil.which('dwarfdump')
                assert dwarf, 'dwarfdump required for target qualification'
                result = run([dwarf, '--debug-line', obj])
                assert result.returncode == 0, result.stderr
                for filename in ['first source.c', 'second.c']:
                    assert filename in result.stdout, result.stdout
                for line in [10, 11, 12, 20, 30]:
                    assert any(row.startswith('0x') and row.split()[1] == str(line) for row in result.stdout.splitlines()), result.stdout
            result = run([cc, caller, obj, *([other] if name == 'linkage' else []), '-o', exe])
            assert result.returncode == 0, result.stderr
            result = run([exe])
            assert result.returncode == 0, (name, label, result.returncode, result.stderr)
    print(f'{target}: Mach-O code/data sections, common coalescing/alignment and DWARF line tables passed', flush=True)
