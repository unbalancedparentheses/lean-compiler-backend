#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

extern uint32_t storew_overlap(uint64_t, uint64_t);

static uint32_t reference(uint64_t value) {
  unsigned char bytes[8] = {0};
  uint32_t narrowed = (uint32_t)value, result;
  memcpy(bytes, &narrowed, sizeof narrowed);
  memcpy(&result, bytes + 1, sizeof result);
  return result;
}

int main(void) {
  uint64_t value = UINT64_C(0x123456789abcdef0);
  printf("%" PRIu32 "\n", storew_overlap(value, 0));
  printf("%" PRIu32 "\n", reference(value));
  return 0;
}
