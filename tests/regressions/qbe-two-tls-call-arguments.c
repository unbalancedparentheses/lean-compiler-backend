#include <stdint.h>
extern uint64_t f(void);
uint64_t g(const uint64_t *a, const uint64_t *b) {
    return a == b && *a == 7 ? 0 : 1;
}
int main(void) { return (int)f(); }
