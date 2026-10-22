#include <stdint.h>
#include <stdio.h>
extern _Thread_local uint64_t slot;
extern uint64_t tls_sub(void);
int main(void) {
 uint64_t expected=(uint32_t)((uintptr_t)&slot-UINT64_C(1));
 uint64_t actual=tls_sub();
 printf("actual=%llu expected=%llu\n",(unsigned long long)actual,(unsigned long long)expected);
 return actual!=expected;
}
