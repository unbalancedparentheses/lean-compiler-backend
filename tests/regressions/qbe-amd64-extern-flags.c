#include <stdint.h>
unsigned char external[256];
extern unsigned char empty[];
extern uintptr_t choose(uint32_t);
int main(void) {
    if (choose(34) != (uintptr_t)empty) return 1;
    if (choose(0) != (uintptr_t)(external + 140)) return 2;
    if (choose(35) != (uintptr_t)(external + 140)) return 3;
    return 0;
}
