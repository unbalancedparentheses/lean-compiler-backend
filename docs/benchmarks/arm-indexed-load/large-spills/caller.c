#include <stdint.h>
#include <stdio.h>
#include <string.h>
extern uint64_t large_spills(void*,uint64_t,uint64_t*);
int main(void){uint64_t v[4200],seed=UINT64_C(0x876543210fdecba9);unsigned char b[64];for(unsigned run=0;run<4;run++){uint64_t sum=0;for(unsigned i=0;i<4200;i++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;v[i]=seed;sum+=seed;}for(unsigned i=0;i<64;i++)b[i]=(unsigned char)(i*73+run);for(int o=-15;o<=15;o+=5){uint64_t x;memcpy(&x,b+24+o,8);if(large_spills(b+24,(uint64_t)o,v)!=((sum*3+x)^(uintptr_t)(b+24)^(uint64_t)o))return 1;}}puts("28 large spill checks passed");}
