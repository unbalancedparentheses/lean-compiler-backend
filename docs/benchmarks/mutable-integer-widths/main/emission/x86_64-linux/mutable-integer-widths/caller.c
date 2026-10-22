#include <stdint.h>
extern uint32_t long_then_word(uint64_t,uint32_t);
extern uint32_t word_then_long(uint64_t,uint32_t);
extern uint32_t parameter_long(uint64_t,uint32_t);
extern uint32_t parameter_word(uint64_t,uint32_t);
extern uint32_t branch(uint64_t,uint32_t);
extern uint32_t loop(uint64_t,uint32_t);
extern uint32_t shift(uint64_t,uint32_t);
extern uint32_t call_word(uint64_t,uint32_t);
extern uint32_t word_roles(uint64_t,uint32_t);
extern uint32_t void_call_word(uint64_t,uint32_t);
int main(void){uint64_t x=0xfedcba9876543210ULL;for(unsigned seed=0;seed<128;seed++){x=x*6364136223846793005ULL+1;for(unsigned n=0;n<9;n++){if(long_then_word(x,n)!=(uint32_t)(x+1))return 1;if(word_then_long(x,n)!=(uint32_t)(x+3))return 1;if(parameter_long(x,n)!=(uint32_t)(x+17))return 1;if(parameter_word(x,n)!=(uint32_t)(x+23))return 1;if(branch(x,n)!=((uint32_t)(x+((n&1)?7:13))^305419896u))return 1;if(loop(x,n)!=(uint32_t)(x+10*n))return 1;if(shift(x,n)!=(uint32_t)(x<<((x+n)&63)))return 1;if(call_word(x,n)!=(uint32_t)((x+n)*7))return 1;if(word_roles(x,n)!=((uint32_t)x^n))return 1;if(void_call_word(x,n)!=(uint32_t)(x+n))return 1;}}return 0;}
