struct Pair { long x; double y; };
static struct Pair mix(struct Pair p) { p.x += 7; p.y *= 2.0; return p; }
extern int printf(const char *, ...);
int main(void) {
  struct Pair p = { 35, 1.25 };
  p = mix(p);
  if (p.x != 42 || p.y != 2.5) return 1;
  printf("pipeline %ld %.1f\n", p.x, p.y);
  return 0;
}
