#include <stdint.h>
#include <stdio.h>
extern uint64_t sparse(uint64_t,uint64_t);
int main(void){uint64_t actual=sparse(3,7);printf("%llu\n",(unsigned long long)actual);return actual!=110;}
