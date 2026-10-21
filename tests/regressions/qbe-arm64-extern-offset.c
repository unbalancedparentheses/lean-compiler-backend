#include <stdint.h>
unsigned char external_bytes[64];
extern uintptr_t external_offset(void);
int main(void) {
    return external_offset() == (uintptr_t)(external_bytes + 32) ? 0 : 1;
}
