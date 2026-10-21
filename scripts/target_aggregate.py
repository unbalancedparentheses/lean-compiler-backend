"""Cross-target aggregate C ABI and exact-tail qualification."""
from pathlib import Path
import re
from aggregate_abi import TYPES, fixture

EDGES='''type :a16 = align 16 { s }
type :inner = { w, s }
type :outer = { w, :inner }
type :pair = { l, l }
type :dd = { d, d }
export function :a16 $aligned_echo(:a16 %p) {
@s
 ret %p
}
export function :outer $nested_echo(:outer %p) {
@s
 ret %p
}
export function d $nested_tail(:outer %p, d %tail) {
@s
 ret %tail
}
export function l $rollback_gp(l %a,l %b,l %c,l %d,l %e,:pair %p,l %tail) {
@s
 %x =l loadl %p
 %q =l add %p, 8
 %y =l loadl %q
 %s =l add %x, %y
 %r =l add %s, %tail
 ret %r
}
export function d $rollback_fp(d %a,d %b,d %c,d %d,d %e,d %f,d %g,:dd %p,d %tail) {
@s
 %x =d load %p
 %q =l add %p, 8
 %y =d load %q
 %s =d add %x, %y
 %r =d add %s, %tail
 ret %r
}
'''
EDGE_C='''#include <stdint.h>
typedef struct __attribute__((aligned(16))) {float x;} A16;
typedef struct {uint32_t i;float f;} Inner;
typedef struct {uint32_t i;Inner nested;} Outer;
typedef struct {uint64_t x,y;} Pair;
typedef struct {double x,y;} DD;
extern A16 aligned_echo(A16);
extern Outer nested_echo(Outer);
extern double nested_tail(Outer,double);
extern uint64_t rollback_gp(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,Pair,uint64_t);
extern double rollback_fp(double,double,double,double,double,double,double,DD,double);
int main(void) {
 A16 a=aligned_echo((A16){1.25f});if(a.x!=1.25f)return 1;
 Outer b=nested_echo((Outer){17,{23,3.5f}});if(b.i!=17||b.nested.i!=23||b.nested.f!=3.5f)return 2;
 if(nested_tail(b,7.5)!=7.5)return 3;
 if(rollback_gp(1,2,3,4,5,(Pair){17,23},31)!=71)return 4;
 if(rollback_fp(1,2,3,4,5,6,7,(DD){1.25,2.5},3.75)!=7.5)return 5;
 return 0;
}
'''


def exercise(compiler,work,run,cc,qbe,target,qtarget):
    for batch,start in enumerate(range(0,len(TYPES),4)):
        source_text,caller_text=fixture(TYPES[start:start+4])
        case=Path(work)/f'aggregate-{batch}';case.mkdir(exist_ok=True)
        source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
        source.write_text(source_text);caller.write_text(caller_text)
        result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
        qasm=case/'qbe.s';result=run([qbe,'-t',qtarget,'-o',qasm,source],True);assert result.returncode==0,result.stderr
        for label,asm in [('lean',assembly),('qbe',qasm)]:
            exe=case/label
            result=run([cc,'-O0',*(['-no-pie'] if target=='riscv64-linux' and label=='qbe' else []),*(['-DLCB_TEST_GUARDS'] if label=='lean' else []),caller,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True)
            if target=='riscv64-linux' and label=='qbe' and result.returncode:
                # Pinned rv64/abi.c uses >= instead of > at exact GP/FP capacity.
                # Preserve the full C pressure checks for Lean; isolate this known
                # oracle discrepancy and continue checking every other QBE case.
                lines=caller_text.splitlines()
                affected=[i+1 for i,line in enumerate(lines) if re.search(r'if\(pressure_(s1|d1|mixed)\(',line)]
                assert result.returncode in [i%256 for i in affected],(batch,label,result.returncode,result.stderr)
                reduced=case/'qbe-capacity-reference.c'
                reduced.write_text('\n'.join(line for i,line in enumerate(lines) if i+1 not in affected)+'\n')
                result=run([cc,'-O0','-no-pie',reduced,asm,'-o',exe],True);assert result.returncode==0,result.stderr
                result=run([exe],True)
                print(f'{target}: isolated pinned QBE exact-capacity aggregate discrepancy in batch {batch}; full Lean/C checks passed',flush=True)
            assert result.returncode==0,(batch,label,result.returncode,result.stderr)
        if batch==0:
            damaged=case/'damaged.s';original=assembly.read_text()
            changed=(original.replace('movzbq 0(%r10), %r11','movq 0(%r10), %r11') if target=='x86_64-linux' else original.replace('lbu t1, 0(t2)','ld t1, 0(t2)'));assert changed!=original
            damaged.write_text(changed);exe=case/'damaged'
            result=run([cc,'-O0','-DLCB_TEST_GUARDS',caller,damaged,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True);assert result.returncode!=0,'aggregate overread corruption escaped guard pages'
    case=Path(work)/'aggregate-edges';case.mkdir(exist_ok=True)
    source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
    source.write_text(EDGES);caller.write_text(EDGE_C)
    result=run([compiler,source,'--target',target,'-o',assembly]);assert result.returncode==0,result.stderr
    result=run([cc,caller,assembly,'-o',case/'lean'],True);assert result.returncode==0,result.stderr
    result=run([case/'lean'],True);assert result.returncode==0,(result.returncode,result.stderr)
    print(f'{target}: 22 aggregate layouts, protected tails/corruption, by-value copies, callbacks and GP/FP pressure passed; C-only padding/nested/rollback edges passed',flush=True)
