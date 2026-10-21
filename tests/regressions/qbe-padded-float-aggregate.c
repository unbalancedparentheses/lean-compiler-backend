typedef struct __attribute__((aligned(8))) { float value; } One;
extern double padded_float(One, double);
int main(void) {
  __asm__ volatile("fmov d2, xzr" ::: "v2");
  return padded_float((One){1}, 3.5) != 3.5;
}
