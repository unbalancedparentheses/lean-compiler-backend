#include <stdarg.h>
#include <stdint.h>
typedef struct { uint64_t value; } Small;
extern uint64_t aggregate_variadic(void);
uint64_t read_first(int ignored, ...) {
  va_list ap;
  va_start(ap, ignored);
  Small value = va_arg(ap, Small);
  va_end(ap);
  return value.value;
}
int main(void) { return aggregate_variadic() != 123; }
