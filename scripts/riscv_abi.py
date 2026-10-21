"""Independent C checks for RV64-specific register boundaries and variadics."""
from pathlib import Path
from fuzz import ROOT

SOURCE='''type :pair = align 16 { l, l }
type :single = { s }
export function s $capacity(d %a,d %b,d %c,d %d,d %e,d %f,d %g,:single %p) {
@s
 %r =s load %p
 ret %r
}
export function l $odd_pair() {
@s
 %p =l alloc16 16
 storel 17, %p
 %q =l add %p, 8
 storel 23, %q
 %r =l call $c_odd(w 1,...,:pair %p,l 31)
 ret %r
}
export function l $stack_pair() {
@s
 %p =l alloc16 16
 storel 17, %p
 %q =l add %p, 8
 storel 23, %q
 %r =l call $c_stack(w 1,...,l 1,l 2,l 3,l 4,l 5,l 6,:pair %p,l 31)
 ret %r
}
export function l $split_pair(l %a,l %b,l %c,l %d,l %e,l %f,l %g,:pair %p,l %tail) {
@s
 %x =l load %p
 %q =l add %p, 8
 %y =l load %q
 %s =l add %x, %y
 %r =l add %s, %tail
 ret %r
}
'''
CALLER='''#include <stdint.h>
#include <stdarg.h>
typedef struct __attribute__((aligned(16))) {uint64_t x,y;} Pair;
typedef struct {float x;} Single;
extern float capacity(double,double,double,double,double,double,double,Single);
extern uint64_t odd_pair(void),stack_pair(void);
extern uint64_t split_pair(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,Pair,uint64_t);
uint64_t c_odd(int tag,...) {va_list ap;va_start(ap,tag);Pair p=va_arg(ap,Pair);uint64_t t=va_arg(ap,uint64_t);va_end(ap);return p.x+p.y+t;}
uint64_t c_stack(int tag,...) {va_list ap;va_start(ap,tag);for(int i=1;i<=6;i++)if(va_arg(ap,uint64_t)!=(uint64_t)i)return 0;Pair p=va_arg(ap,Pair);uint64_t t=va_arg(ap,uint64_t);va_end(ap);return p.x+p.y+t;}
int main(void) {
 if(capacity(1,2,3,4,5,6,7,(Single){3.25f})!=3.25f)return 1;
 if(odd_pair()!=71)return 2;
 if(stack_pair()!=71)return 3;
 if(split_pair(1,2,3,4,5,6,7,(Pair){17,23},31)!=71)return 4;
 return 0;
}
'''

def exercise(compiler,work,run,cc,qbe=None):
    case=Path(work)/'rv64-abi-boundaries';case.mkdir(exist_ok=True)
    source,assembly,caller=case/'input.ssa',case/'lean.s',case/'caller.c'
    source.write_text(SOURCE);caller.write_text(CALLER)
    result=run([compiler,source,'--target','riscv64-linux','-o',assembly]);assert result.returncode==0,result.stderr
    result=run([cc,'-O2',caller,assembly,'-o',case/'lean'],True);assert result.returncode==0,result.stderr
    result=run([case/'lean'],True);assert result.returncode==0,(result.returncode,result.stderr)
    if qbe:
        reduced=case/'exact-capacity.ssa';driver=case/'exact-capacity.c'
        reduced.write_text((ROOT/'tests/regressions/qbe-rv64-exact-fp-capacity.ssa').read_text())
        driver.write_text((ROOT/'tests/regressions/qbe-rv64-exact-fp-capacity.c').read_text())
        for label in ['lean','qbe']:
            asm=case/(label+'-exact.s');exe=case/(label+'-exact')
            cmd=[compiler,reduced,'--target','riscv64-linux','-o',asm] if label=='lean' else [qbe,'-t','rv64','-o',asm,reduced]
            result=run(cmd,label=='qbe');assert result.returncode==0,result.stderr
            result=run([cc,'-O2',driver,asm,'-o',exe],True);assert result.returncode==0,result.stderr
            result=run([exe],True)
            assert result.returncode==(0 if label=='lean' else 1),(label,result.returncode,result.stderr)
        print('riscv64-linux: reduced exact-FP-capacity fixture passes Lean/C and reproduces pinned QBE failure',flush=True)
    print('riscv64-linux: exact FP capacity, split GP/stack aggregates and aligned variadic pairs passed independent C checks',flush=True)
