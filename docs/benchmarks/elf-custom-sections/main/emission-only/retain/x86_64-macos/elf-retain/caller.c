#include <stdint.h>
#include <stdlib.h>
extern uint64_t anchor(void),ref_data;
int main(int argc,char**argv){if(argc!=4||anchor()!=17||ref_data!=19)return 1;
 uintptr_t base=(uintptr_t)&anchor;
 volatile uint64_t *a=(volatile uint64_t*)(base+(uintptr_t)strtoll(argv[1],0,10));
 volatile uint64_t *b=(volatile uint64_t*)(base+(uintptr_t)strtoll(argv[2],0,10));
 uint64_t(*f)(void)=(uint64_t(*)(void))(base+(uintptr_t)strtoll(argv[3],0,10));
 return *a!=37||*b!=83||f()!=71;}
