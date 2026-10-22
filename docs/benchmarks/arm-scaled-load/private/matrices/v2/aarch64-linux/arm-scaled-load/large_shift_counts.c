#define _GNU_SOURCE
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
extern uint32_t ub_w_high(uint64_t,uint64_t);
extern uint32_t ub_w_negative(uint64_t,uint64_t);
extern uint32_t ub_w_huge(uint64_t,uint64_t);
extern uint64_t ub_l_high(uint64_t,uint64_t);
extern uint64_t ub_l_negative(uint64_t,uint64_t);
extern uint64_t ub_l_huge(uint64_t,uint64_t);
extern uint32_t sb_w_high(uint64_t,uint64_t);
extern uint32_t sb_w_negative(uint64_t,uint64_t);
extern uint32_t sb_w_huge(uint64_t,uint64_t);
extern uint64_t sb_l_high(uint64_t,uint64_t);
extern uint64_t sb_l_negative(uint64_t,uint64_t);
extern uint64_t sb_l_huge(uint64_t,uint64_t);
extern uint32_t uh_w_high(uint64_t,uint64_t);
extern uint32_t uh_w_negative(uint64_t,uint64_t);
extern uint32_t uh_w_huge(uint64_t,uint64_t);
extern uint64_t uh_l_high(uint64_t,uint64_t);
extern uint64_t uh_l_negative(uint64_t,uint64_t);
extern uint64_t uh_l_huge(uint64_t,uint64_t);
extern uint32_t sh_w_high(uint64_t,uint64_t);
extern uint32_t sh_w_negative(uint64_t,uint64_t);
extern uint32_t sh_w_huge(uint64_t,uint64_t);
extern uint64_t sh_l_high(uint64_t,uint64_t);
extern uint64_t sh_l_negative(uint64_t,uint64_t);
extern uint64_t sh_l_huge(uint64_t,uint64_t);
extern uint32_t uw_w_high(uint64_t,uint64_t);
extern uint32_t uw_w_negative(uint64_t,uint64_t);
extern uint32_t uw_w_huge(uint64_t,uint64_t);
extern uint64_t uw_l_high(uint64_t,uint64_t);
extern uint64_t uw_l_negative(uint64_t,uint64_t);
extern uint64_t uw_l_huge(uint64_t,uint64_t);
extern uint32_t sw_w_high(uint64_t,uint64_t);
extern uint32_t sw_w_negative(uint64_t,uint64_t);
extern uint32_t sw_w_huge(uint64_t,uint64_t);
extern uint64_t sw_l_high(uint64_t,uint64_t);
extern uint64_t sw_l_negative(uint64_t,uint64_t);
extern uint64_t sw_l_huge(uint64_t,uint64_t);
extern uint64_t l_l_high(uint64_t,uint64_t);
extern uint64_t l_l_negative(uint64_t,uint64_t);
extern uint64_t l_l_huge(uint64_t,uint64_t);
extern uint32_t s_w_high(uint64_t,uint64_t);
extern uint32_t s_w_negative(uint64_t,uint64_t);
extern uint32_t s_w_huge(uint64_t,uint64_t);
extern uint64_t d_l_high(uint64_t,uint64_t);
extern uint64_t d_l_negative(uint64_t,uint64_t);
extern uint64_t d_l_huge(uint64_t,uint64_t);
int main(int argc,char**argv){(void)argv;uint64_t patterns[]={0,UINT64_MAX,0x8000000000000000ULL,0x7ff0000000000001ULL,0x7ff8000012345678ULL,0x80000000,0x7f800001,0x123456789abcdefULL};
uint64_t indices[]={0,1,7,UINT64_MAX,0x8000000000000000ULL,0x80000001,0x100000003ULL};
unsigned char bytes[96];long page=sysconf(_SC_PAGESIZE);unsigned char*map=mmap(0,page*3,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);if(map==MAP_FAILED||mprotect(map+page,page,PROT_READ|PROT_WRITE))return 2;
for(unsigned p=0;p<8;p++)for(unsigned j=0;j<7;j++){uint64_t index=indices[j];for(unsigned b=0;b<96;b++)bytes[b]=(unsigned char)(patterns[p]>>(8*(b%8)));
if(argc==1)for(unsigned off=0;off<8;off++){unsigned char*q=bytes+32+off;
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_huge(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_high(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_negative(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_huge(base,index)!=want)return 1;}
}

}munmap(map,page*3);return 0;}
