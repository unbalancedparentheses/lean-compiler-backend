#include <stdint.h>
#include <stdio.h>
extern uint64_t target(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,...);
int main(void){uint64_t r=target(1,2,3,4,5,6,UINT64_C(0x123456789abcdef0),UINT64_C(0));printf("%llx\n",(unsigned long long)r);return r!=UINT64_C(0x123456789abcdef0);}
