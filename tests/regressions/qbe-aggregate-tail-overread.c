#include <sys/mman.h>
#include <unistd.h>
typedef struct { unsigned char value; } Byte;
extern Byte read_byte(void *);
int main(void) {
  long page = sysconf(_SC_PAGESIZE);
  unsigned char *mapping = mmap(0, (size_t)page * 2, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANON, -1, 0);
  if (mapping == MAP_FAILED || mprotect(mapping + page, (size_t)page, PROT_NONE)) return 2;
  mapping[page - 1] = 42;
  Byte result = read_byte(mapping + page - 1);
  int failed = result.value != 42;
  if (munmap(mapping, (size_t)page * 2)) return 3;
  return failed;
}
