#include <stdint.h>
extern uint64_t v0, f0(uint64_t);
extern uint64_t v1, f1(uint64_t);
extern uint64_t v2, f2(uint64_t);
extern uint64_t v3, f3(uint64_t);
extern uint64_t v4, f4(uint64_t);
extern uint64_t v5, f5(uint64_t);
extern uint64_t v6, f6(uint64_t);
int main(void){if(v0!=100)return 3;if(v1!=101)return 3;if(v2!=102)return 3;if(v3!=103)return 3;if(v4!=104)return 3;if(v5!=105)return 3;if(v6!=106)return 3;uint64_t values[]={0,1,UINT64_C(0x8000000000000000),UINT64_MAX};for(unsigned j=0;j<4;j++){uint64_t x=values[j];if(f0(x)!=v0+x)return 1;v0^=x;if(f0(x)!=v0+x)return 2;if(f1(x)!=v1+x)return 1;v1^=x;if(f1(x)!=v1+x)return 2;if(f2(x)!=v2+x)return 1;v2^=x;if(f2(x)!=v2+x)return 2;if(f3(x)!=v3+x)return 1;v3^=x;if(f3(x)!=v3+x)return 2;if(f4(x)!=v4+x)return 1;v4^=x;if(f4(x)!=v4+x)return 2;if(f5(x)!=v5+x)return 1;v5^=x;if(f5(x)!=v5+x)return 2;if(f6(x)!=v6+x)return 1;v6^=x;if(f6(x)!=v6+x)return 2;}return 0;}
