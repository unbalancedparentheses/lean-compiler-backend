/* Retained QBE fixture initializes counter=10 and subtracts10: one double-round. */
#include <stdint.h>
#include <string.h>
#include <stdio.h>
extern void chacha20_rounds_qbe(uint32_t *, const uint32_t *);
static uint32_t rot(uint32_t x,unsigned n){return (x<<n)|(x>>(32-n));}
static void q(uint32_t *x,unsigned a,unsigned b,unsigned c,unsigned d){
 x[a]+=x[b];x[d]=rot(x[d]^x[a],16);x[c]+=x[d];x[b]=rot(x[b]^x[c],12);
 x[a]+=x[b];x[d]=rot(x[d]^x[a],8);x[c]+=x[d];x[b]=rot(x[b]^x[c],7);
}
static void reference(uint32_t *x){for(unsigned i=0;i<1;i++){
 q(x,0,4,8,12);q(x,1,5,9,13);q(x,2,6,10,14);q(x,3,7,11,15);
 q(x,0,5,10,15);q(x,1,6,11,12);q(x,2,7,8,13);q(x,3,4,9,14);
}}
int main(void){uint64_t rng=UINT64_C(0x123456789abcdef);uint32_t input[16];
 for(unsigned n=0;n<512;n++){
  for(unsigned i=0;i<16;i++){rng^=rng<<13;rng^=rng>>7;rng^=rng<<17;input[i]=n==0?0:n==1?UINT32_MAX:n==2?UINT32_C(0x80000000):n==3?i:(uint32_t)rng;}
  for(unsigned alias=0;alias<3;alias++){
   uint32_t arena[64],expected[64],result[16];unsigned out=alias==0?0:alias==1?16:17;
   for(unsigned i=0;i<64;i++)arena[i]=UINT32_C(0xa5a50000)+i;
   memcpy(arena+16,input,sizeof input);memcpy(expected,arena,sizeof arena);memcpy(result,input,sizeof input);reference(result);memcpy(expected+out,result,sizeof result);
   chacha20_rounds_qbe(arena+out,arena+16);if(memcmp(arena,expected,sizeof arena))return 1;
  }
 }
 puts("1536 independent round/alias/canary cases passed");return 0;
}
