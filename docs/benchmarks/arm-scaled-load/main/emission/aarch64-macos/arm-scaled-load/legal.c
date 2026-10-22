#define _GNU_SOURCE
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
extern uint32_t ub_w_plain(uint64_t,uint64_t);
extern uint32_t ub_w_commuted(uint64_t,uint64_t);
extern uint32_t ub_w_zero(uint64_t,uint64_t);
extern uint32_t ub_w_debug_shift(uint64_t,uint64_t);
extern uint32_t ub_w_debug_add(uint64_t,uint64_t);
extern uint32_t ub_w_shared_shift(uint64_t,uint64_t);
extern uint32_t ub_w_shared_address(uint64_t,uint64_t);
extern uint32_t ub_w_separated(uint64_t,uint64_t);
extern uint32_t ub_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t ub_w_word_shift(uint64_t,uint64_t);
extern uint32_t ub_w_barrier_call(uint64_t,uint64_t);
extern uint32_t ub_w_live(uint64_t,uint64_t);
extern uint32_t ub_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t ub_w_extension(uint64_t,uint64_t);
extern uint64_t ub_l_plain(uint64_t,uint64_t);
extern uint64_t ub_l_commuted(uint64_t,uint64_t);
extern uint64_t ub_l_zero(uint64_t,uint64_t);
extern uint64_t ub_l_debug_shift(uint64_t,uint64_t);
extern uint64_t ub_l_debug_add(uint64_t,uint64_t);
extern uint64_t ub_l_shared_shift(uint64_t,uint64_t);
extern uint64_t ub_l_shared_address(uint64_t,uint64_t);
extern uint64_t ub_l_separated(uint64_t,uint64_t);
extern uint64_t ub_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t ub_l_word_shift(uint64_t,uint64_t);
extern uint64_t ub_l_barrier_call(uint64_t,uint64_t);
extern uint64_t ub_l_live(uint64_t,uint64_t);
extern uint64_t ub_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t ub_l_extension(uint64_t,uint64_t);
extern uint32_t sb_w_plain(uint64_t,uint64_t);
extern uint32_t sb_w_commuted(uint64_t,uint64_t);
extern uint32_t sb_w_zero(uint64_t,uint64_t);
extern uint32_t sb_w_debug_shift(uint64_t,uint64_t);
extern uint32_t sb_w_debug_add(uint64_t,uint64_t);
extern uint32_t sb_w_shared_shift(uint64_t,uint64_t);
extern uint32_t sb_w_shared_address(uint64_t,uint64_t);
extern uint32_t sb_w_separated(uint64_t,uint64_t);
extern uint32_t sb_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t sb_w_word_shift(uint64_t,uint64_t);
extern uint32_t sb_w_barrier_call(uint64_t,uint64_t);
extern uint32_t sb_w_live(uint64_t,uint64_t);
extern uint32_t sb_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t sb_l_plain(uint64_t,uint64_t);
extern uint64_t sb_l_commuted(uint64_t,uint64_t);
extern uint64_t sb_l_zero(uint64_t,uint64_t);
extern uint64_t sb_l_debug_shift(uint64_t,uint64_t);
extern uint64_t sb_l_debug_add(uint64_t,uint64_t);
extern uint64_t sb_l_shared_shift(uint64_t,uint64_t);
extern uint64_t sb_l_shared_address(uint64_t,uint64_t);
extern uint64_t sb_l_separated(uint64_t,uint64_t);
extern uint64_t sb_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t sb_l_word_shift(uint64_t,uint64_t);
extern uint64_t sb_l_barrier_call(uint64_t,uint64_t);
extern uint64_t sb_l_live(uint64_t,uint64_t);
extern uint64_t sb_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint32_t uh_w_plain(uint64_t,uint64_t);
extern uint32_t uh_w_commuted(uint64_t,uint64_t);
extern uint32_t uh_w_zero(uint64_t,uint64_t);
extern uint32_t uh_w_debug_shift(uint64_t,uint64_t);
extern uint32_t uh_w_debug_add(uint64_t,uint64_t);
extern uint32_t uh_w_shared_shift(uint64_t,uint64_t);
extern uint32_t uh_w_shared_address(uint64_t,uint64_t);
extern uint32_t uh_w_separated(uint64_t,uint64_t);
extern uint32_t uh_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t uh_w_word_shift(uint64_t,uint64_t);
extern uint32_t uh_w_barrier_call(uint64_t,uint64_t);
extern uint32_t uh_w_live(uint64_t,uint64_t);
extern uint32_t uh_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t uh_w_extension(uint64_t,uint64_t);
extern uint64_t uh_l_plain(uint64_t,uint64_t);
extern uint64_t uh_l_commuted(uint64_t,uint64_t);
extern uint64_t uh_l_zero(uint64_t,uint64_t);
extern uint64_t uh_l_debug_shift(uint64_t,uint64_t);
extern uint64_t uh_l_debug_add(uint64_t,uint64_t);
extern uint64_t uh_l_shared_shift(uint64_t,uint64_t);
extern uint64_t uh_l_shared_address(uint64_t,uint64_t);
extern uint64_t uh_l_separated(uint64_t,uint64_t);
extern uint64_t uh_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t uh_l_word_shift(uint64_t,uint64_t);
extern uint64_t uh_l_barrier_call(uint64_t,uint64_t);
extern uint64_t uh_l_live(uint64_t,uint64_t);
extern uint64_t uh_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t uh_l_extension(uint64_t,uint64_t);
extern uint32_t sh_w_plain(uint64_t,uint64_t);
extern uint32_t sh_w_commuted(uint64_t,uint64_t);
extern uint32_t sh_w_zero(uint64_t,uint64_t);
extern uint32_t sh_w_debug_shift(uint64_t,uint64_t);
extern uint32_t sh_w_debug_add(uint64_t,uint64_t);
extern uint32_t sh_w_shared_shift(uint64_t,uint64_t);
extern uint32_t sh_w_shared_address(uint64_t,uint64_t);
extern uint32_t sh_w_separated(uint64_t,uint64_t);
extern uint32_t sh_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t sh_w_word_shift(uint64_t,uint64_t);
extern uint32_t sh_w_barrier_call(uint64_t,uint64_t);
extern uint32_t sh_w_live(uint64_t,uint64_t);
extern uint32_t sh_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t sh_l_plain(uint64_t,uint64_t);
extern uint64_t sh_l_commuted(uint64_t,uint64_t);
extern uint64_t sh_l_zero(uint64_t,uint64_t);
extern uint64_t sh_l_debug_shift(uint64_t,uint64_t);
extern uint64_t sh_l_debug_add(uint64_t,uint64_t);
extern uint64_t sh_l_shared_shift(uint64_t,uint64_t);
extern uint64_t sh_l_shared_address(uint64_t,uint64_t);
extern uint64_t sh_l_separated(uint64_t,uint64_t);
extern uint64_t sh_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t sh_l_word_shift(uint64_t,uint64_t);
extern uint64_t sh_l_barrier_call(uint64_t,uint64_t);
extern uint64_t sh_l_live(uint64_t,uint64_t);
extern uint64_t sh_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint32_t uw_w_plain(uint64_t,uint64_t);
extern uint32_t uw_w_commuted(uint64_t,uint64_t);
extern uint32_t uw_w_zero(uint64_t,uint64_t);
extern uint32_t uw_w_debug_shift(uint64_t,uint64_t);
extern uint32_t uw_w_debug_add(uint64_t,uint64_t);
extern uint32_t uw_w_shared_shift(uint64_t,uint64_t);
extern uint32_t uw_w_shared_address(uint64_t,uint64_t);
extern uint32_t uw_w_separated(uint64_t,uint64_t);
extern uint32_t uw_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t uw_w_word_shift(uint64_t,uint64_t);
extern uint32_t uw_w_barrier_call(uint64_t,uint64_t);
extern uint32_t uw_w_live(uint64_t,uint64_t);
extern uint32_t uw_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t uw_w_extension(uint64_t,uint64_t);
extern uint64_t uw_l_plain(uint64_t,uint64_t);
extern uint64_t uw_l_commuted(uint64_t,uint64_t);
extern uint64_t uw_l_zero(uint64_t,uint64_t);
extern uint64_t uw_l_debug_shift(uint64_t,uint64_t);
extern uint64_t uw_l_debug_add(uint64_t,uint64_t);
extern uint64_t uw_l_shared_shift(uint64_t,uint64_t);
extern uint64_t uw_l_shared_address(uint64_t,uint64_t);
extern uint64_t uw_l_separated(uint64_t,uint64_t);
extern uint64_t uw_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t uw_l_word_shift(uint64_t,uint64_t);
extern uint64_t uw_l_barrier_call(uint64_t,uint64_t);
extern uint64_t uw_l_live(uint64_t,uint64_t);
extern uint64_t uw_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t uw_l_extension(uint64_t,uint64_t);
extern uint32_t sw_w_plain(uint64_t,uint64_t);
extern uint32_t sw_w_commuted(uint64_t,uint64_t);
extern uint32_t sw_w_zero(uint64_t,uint64_t);
extern uint32_t sw_w_debug_shift(uint64_t,uint64_t);
extern uint32_t sw_w_debug_add(uint64_t,uint64_t);
extern uint32_t sw_w_shared_shift(uint64_t,uint64_t);
extern uint32_t sw_w_shared_address(uint64_t,uint64_t);
extern uint32_t sw_w_separated(uint64_t,uint64_t);
extern uint32_t sw_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t sw_w_word_shift(uint64_t,uint64_t);
extern uint32_t sw_w_barrier_call(uint64_t,uint64_t);
extern uint32_t sw_w_live(uint64_t,uint64_t);
extern uint32_t sw_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t sw_l_plain(uint64_t,uint64_t);
extern uint64_t sw_l_commuted(uint64_t,uint64_t);
extern uint64_t sw_l_zero(uint64_t,uint64_t);
extern uint64_t sw_l_debug_shift(uint64_t,uint64_t);
extern uint64_t sw_l_debug_add(uint64_t,uint64_t);
extern uint64_t sw_l_shared_shift(uint64_t,uint64_t);
extern uint64_t sw_l_shared_address(uint64_t,uint64_t);
extern uint64_t sw_l_separated(uint64_t,uint64_t);
extern uint64_t sw_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t sw_l_word_shift(uint64_t,uint64_t);
extern uint64_t sw_l_barrier_call(uint64_t,uint64_t);
extern uint64_t sw_l_live(uint64_t,uint64_t);
extern uint64_t sw_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t l_l_plain(uint64_t,uint64_t);
extern uint64_t l_l_commuted(uint64_t,uint64_t);
extern uint64_t l_l_zero(uint64_t,uint64_t);
extern uint64_t l_l_debug_shift(uint64_t,uint64_t);
extern uint64_t l_l_debug_add(uint64_t,uint64_t);
extern uint64_t l_l_shared_shift(uint64_t,uint64_t);
extern uint64_t l_l_shared_address(uint64_t,uint64_t);
extern uint64_t l_l_separated(uint64_t,uint64_t);
extern uint64_t l_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t l_l_word_shift(uint64_t,uint64_t);
extern uint64_t l_l_barrier_call(uint64_t,uint64_t);
extern uint64_t l_l_live(uint64_t,uint64_t);
extern uint64_t l_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint32_t s_w_plain(uint64_t,uint64_t);
extern uint32_t s_w_commuted(uint64_t,uint64_t);
extern uint32_t s_w_zero(uint64_t,uint64_t);
extern uint32_t s_w_debug_shift(uint64_t,uint64_t);
extern uint32_t s_w_debug_add(uint64_t,uint64_t);
extern uint32_t s_w_shared_shift(uint64_t,uint64_t);
extern uint32_t s_w_shared_address(uint64_t,uint64_t);
extern uint32_t s_w_separated(uint64_t,uint64_t);
extern uint32_t s_w_wrong_scale(uint64_t,uint64_t);
extern uint32_t s_w_word_shift(uint64_t,uint64_t);
extern uint32_t s_w_barrier_call(uint64_t,uint64_t);
extern uint32_t s_w_live(uint64_t,uint64_t);
extern uint32_t s_w_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t d_l_plain(uint64_t,uint64_t);
extern uint64_t d_l_commuted(uint64_t,uint64_t);
extern uint64_t d_l_zero(uint64_t,uint64_t);
extern uint64_t d_l_debug_shift(uint64_t,uint64_t);
extern uint64_t d_l_debug_add(uint64_t,uint64_t);
extern uint64_t d_l_shared_shift(uint64_t,uint64_t);
extern uint64_t d_l_shared_address(uint64_t,uint64_t);
extern uint64_t d_l_separated(uint64_t,uint64_t);
extern uint64_t d_l_wrong_scale(uint64_t,uint64_t);
extern uint64_t d_l_word_shift(uint64_t,uint64_t);
extern uint64_t d_l_barrier_call(uint64_t,uint64_t);
extern uint64_t d_l_live(uint64_t,uint64_t);
extern uint64_t d_l_pressure(uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t same_base_index(uint64_t);
__attribute__((noinline)) void scaled_barrier(void){__asm__ volatile("" ::: "memory");}
int main(int argc,char**argv){(void)argv;uint64_t patterns[]={0,UINT64_MAX,0x8000000000000000ULL,0x7ff0000000000001ULL,0x7ff8000012345678ULL,0x80000000,0x7f800001,0x123456789abcdefULL};
uint64_t indices[]={0,1,7,UINT64_MAX,0x8000000000000000ULL,0x80000001,0x100000003ULL};
unsigned char bytes[96];long page=sysconf(_SC_PAGESIZE);unsigned char*map=mmap(0,page*3,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);if(map==MAP_FAILED||mprotect(map+page,page,PROT_READ|PROT_WRITE))return 2;
for(unsigned p=0;p<8;p++)for(unsigned j=0;j<7;j++){uint64_t index=indices[j];for(unsigned b=0;b<96;b++)bytes[b]=(unsigned char)(patterns[p]>>(8*(b%8)));
if(argc==1)for(unsigned off=0;off<8;off++){unsigned char*q=bytes+32+off;
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw^(uint32_t)scaled);if(ub_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw^(uint32_t)(uintptr_t)q);if(ub_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw^(uint32_t)(index^991));if(ub_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(uint32_t)(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw^(uint32_t)index);if(ub_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(ub_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_w_extension(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw^(uint64_t)scaled);if(ub_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw^(uint64_t)(uintptr_t)q);if(ub_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw^(uint64_t)(index^991));if(ub_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(uint32_t)(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw^(uint64_t)index);if(ub_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(ub_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_extension(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw^(uint32_t)scaled);if(sb_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw^(uint32_t)(uintptr_t)q);if(sb_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw^(uint32_t)(index^991));if(sb_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(uint32_t)(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw^(uint32_t)index);if(sb_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(sb_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw^(uint64_t)scaled);if(sb_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw^(uint64_t)(uintptr_t)q);if(sb_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw^(uint64_t)(index^991));if(sb_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(uint32_t)(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw^(uint64_t)index);if(sb_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(sb_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw^(uint32_t)scaled);if(uh_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw^(uint32_t)(uintptr_t)q);if(uh_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw^(uint32_t)(index^991));if(uh_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(uint32_t)(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw^(uint32_t)index);if(uh_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(uh_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_w_extension(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw^(uint64_t)scaled);if(uh_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw^(uint64_t)(uintptr_t)q);if(uh_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw^(uint64_t)(index^991));if(uh_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(uint32_t)(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw^(uint64_t)index);if(uh_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(uh_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_extension(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw^(uint32_t)scaled);if(sh_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw^(uint32_t)(uintptr_t)q);if(sh_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw^(uint32_t)(index^991));if(sh_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(uint32_t)(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw^(uint32_t)index);if(sh_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(sh_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw^(uint64_t)scaled);if(sh_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw^(uint64_t)(uintptr_t)q);if(sh_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw^(uint64_t)(index^991));if(sh_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(uint32_t)(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw^(uint64_t)index);if(sh_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(sh_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)scaled);if(uw_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)(uintptr_t)q);if(uw_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)(index^991));if(uw_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(uint32_t)(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)index);if(uw_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(uw_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_w_extension(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw^(uint64_t)scaled);if(uw_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw^(uint64_t)(uintptr_t)q);if(uw_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw^(uint64_t)(index^991));if(uw_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(uint32_t)(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw^(uint64_t)index);if(uw_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(uw_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_extension(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw^(uint32_t)scaled);if(sw_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw^(uint32_t)(uintptr_t)q);if(sw_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw^(uint32_t)(index^991));if(sw_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(uint32_t)(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw^(uint32_t)index);if(sw_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(sw_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw^(uint64_t)scaled);if(sw_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw^(uint64_t)(uintptr_t)q);if(sw_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw^(uint64_t)(index^991));if(sw_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(uint32_t)(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw^(uint64_t)index);if(sw_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(sw_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)scaled);if(l_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)(uintptr_t)q);if(l_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)(index^991));if(l_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(uint32_t)(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)index);if(l_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(l_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)scaled);if(s_w_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)(uintptr_t)q);if(s_w_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)(index^991));if(s_w_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(uint32_t)(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw^(uint32_t)index);if(s_w_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(s_w_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_plain(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_commuted(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_zero(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_debug_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_debug_add(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)scaled);if(d_l_shared_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)(uintptr_t)q);if(d_l_shared_address(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)(index^991));if(d_l_separated(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_wrong_scale(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(uint32_t)(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_word_shift(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_barrier_call(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw^(uint64_t)index);if(d_l_live(base,index)!=want)return 1;}
{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);for(unsigned j=0;j<24;j++)want+=index+j;if(d_l_pressure(base,index,index+0,index+1,index+2,index+3,index+4,index+5,index+6,index+7,index+8,index+9,index+10,index+11,index+12,index+13,index+14,index+15,index+16,index+17,index+18,index+19,index+20,index+21,index+22,index+23)!=want)return 1;}
{uint64_t raw;memcpy(&raw,q,8);if(same_base_index((uint64_t)(uintptr_t)q*UINT64_C(10248191152060862009))!=raw)return 1;}
}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint8_t)raw);if(ub_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint8_t)raw);if(ub_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int8_t)raw);if(sb_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-1;memcpy(q,&patterns[p],1);{uint64_t raw=0;memcpy(&raw,q,1);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int8_t)raw);if(sb_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint16_t)raw);if(uh_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint16_t)raw);if(uh_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int16_t)raw);if(sh_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<1);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-2;memcpy(q,&patterns[p],2);{uint64_t raw=0;memcpy(&raw,q,2);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int16_t)raw);if(sh_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(uw_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint32_t)raw);if(uw_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(int32_t)raw);if(sw_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(int32_t)raw);if(sw_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-8;memcpy(q,&patterns[p],8);{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-8;memcpy(q,&patterns[p],8);{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(l_l_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<2);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-4;memcpy(q,&patterns[p],4);{uint64_t raw=0;memcpy(&raw,q,4);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint32_t want=((uint32_t)(uint32_t)raw);if(s_w_zero(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-8;memcpy(q,&patterns[p],8);{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<3);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_plain(base,index)!=want)return 1;}}}
{for(unsigned side=0;side<2;side++){unsigned char*q=side?map+page:map+2*page-8;memcpy(q,&patterns[p],8);{uint64_t raw=0;memcpy(&raw,q,8);uint64_t scaled=(index<<0);uint64_t base=(uintptr_t)q-scaled;uint64_t want=((uint64_t)(uint64_t)raw);if(d_l_zero(base,index)!=want)return 1;}}}
}munmap(map,page*3);return 0;}
