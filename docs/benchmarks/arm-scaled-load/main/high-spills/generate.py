from pathlib import Path
p=Path(__file__).parent;n=4200
lines=['export function l $large_spills(l %p,l %index,l %values) {','@entry']
for i in range(n):lines += [f' %ptr{i} =l add %values,{i*8}',f' %v{i} =l loadl %ptr{i}']
lines += [' %scaled =l shl %index,3',' %address =l add %p,%scaled',' %chosen =l loadl %address',' jmp @loop','@loop',' %n =w phi @entry 0,@loop %next',' %acc =l phi @entry 0,@loop %s4199']
for i in range(n):lines += [f' %s{i} =l add '+('%acc' if i==0 else f'%s{i-1}')+f',%v{i}']
lines += [' %next =w add %n,1',' %again =w cultw %next,3',' jnz %again,@loop,@done','@done',' %result =l add %s4199,%chosen',' %r1 =l xor %result,%p',' %r2 =l xor %r1,%index',' ret %r2','}']
(p/'input.ssa').write_text('\n'.join(lines)+'\n')
(p/'caller.c').write_text('''#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern uint64_t large_spills(void*,uint64_t,uint64_t*);
int main(void){uint64_t v[4200],seed=UINT64_C(0x876543210fdecba9);unsigned char b[64];for(unsigned run=0;run<4;run++){uint64_t sum=0;for(unsigned i=0;i<4200;i++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;v[i]=seed;sum+=seed;}for(unsigned i=0;i<64;i++)b[i]=(unsigned char)(i*73+run);for(int o=-15;o<=15;o+=5){uint64_t x;memcpy(&x,b+24+o,8);if(large_spills((void*)((uintptr_t)(b+24)-7*(uint64_t)o),(uint64_t)o,v)!=((sum*3+x)^((uintptr_t)(b+24)-7*(uint64_t)o)^(uint64_t)o))return 1;}}puts("28 large spill checks passed");}
''')
