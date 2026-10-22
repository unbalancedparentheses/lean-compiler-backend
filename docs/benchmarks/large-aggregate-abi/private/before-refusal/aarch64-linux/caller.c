#include <stdint.h>
struct big { unsigned char bytes[4097]; };
extern uint64_t inspect(struct big);
extern struct big make(uint64_t);
int main(void) { struct big b; for(unsigned i=0;i<4097;i++) b.bytes[i]=(i*17+31)%251;
uint64_t want=(uint64_t)b.bytes[0]+b.bytes[2048]+b.bytes[4096];
if(inspect(b)!=want) return 1; for(unsigned i=0;i<4097;i++)if(b.bytes[i]!=(i*17+31)%251)return 3;
struct big r=make(0x1234);for(unsigned i=0;i<4097;i++)if(r.bytes[i]!=(i==0?0x34:i==4096?173:0))return 2;
return 0; }
