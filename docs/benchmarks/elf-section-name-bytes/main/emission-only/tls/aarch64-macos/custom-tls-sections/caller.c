#include <pthread.h>
#include <stdint.h>
extern __thread uint64_t custom_init,custom_zero,ordinary;
extern uint64_t read_custom(int),read_local(void),read_ordinary(void);
extern void write_custom(uint64_t,uint64_t),write_local(uint64_t),write_ordinary(uint64_t);
static int failed;
static int initial(void){return read_custom(0)!=37||read_custom(1)!=0||read_local()!=73||read_ordinary()!=19||custom_init!=37||custom_zero!=0||ordinary!=19||((uintptr_t)&custom_init%16)||((uintptr_t)&custom_zero%32);}
static void* worker(void*p){
 if(initial())failed=1;
 for(uint64_t i=0;i<128;i++){
  uint64_t a=UINT64_C(0x8123456789abcdef)^i,z=UINT64_C(0xfedcba9876543210)+i;
  write_custom(a,z);write_local(a+1);write_ordinary(z+1);
  if(read_custom(0)!=a||read_custom(1)!=z||read_local()!=a+1||read_ordinary()!=z+1||custom_init!=a||custom_zero!=z||ordinary!=z+1)failed=2;
 }
 return 0;
}
int main(void){if(initial())return 1;write_custom(51,52);write_local(53);write_ordinary(54);
 for(int i=0;i<4;i++){pthread_t t;if(pthread_create(&t,0,worker,0)||pthread_join(t,0))return 3;if(failed)return 4;if(read_custom(0)!=51||read_custom(1)!=52||read_local()!=53||read_ordinary()!=54)return 5;}
 return 0;}
