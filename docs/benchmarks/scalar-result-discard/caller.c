#include <stdint.h>
uint32_t external_w(uint64_t *p){*p+=1;return (uint32_t)-1;}
extern void probe_w(uint64_t*,uint32_t(*)(uint64_t*));
uint64_t external_l(uint64_t *p){*p+=2;return (uint64_t)-1;}
extern void probe_l(uint64_t*,uint64_t(*)(uint64_t*));
float external_s(uint64_t *p){*p+=3;return (float)-1;}
extern void probe_s(uint64_t*,float(*)(uint64_t*));
double external_d(uint64_t *p){*p+=4;return (double)-1;}
extern void probe_d(uint64_t*,double(*)(uint64_t*));
int8_t external_sb(uint64_t *p){*p+=5;return (int8_t)-1;}
extern void probe_sb(uint64_t*,int8_t(*)(uint64_t*));
uint8_t external_ub(uint64_t *p){*p+=6;return (uint8_t)-1;}
extern void probe_ub(uint64_t*,uint8_t(*)(uint64_t*));
int16_t external_sh(uint64_t *p){*p+=7;return (int16_t)-1;}
extern void probe_sh(uint64_t*,int16_t(*)(uint64_t*));
uint16_t external_uh(uint64_t *p){*p+=8;return (uint16_t)-1;}
extern void probe_uh(uint64_t*,uint16_t(*)(uint64_t*));
extern void dead_void(uint64_t*),discard_variadic(uint64_t*);
int main(void){uint64_t seed=UINT64_C(0xfedcba9876543210);for(unsigned t=0;t<32;t++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;{uint64_t value=seed;probe_w(&value,external_w);if(value!=seed+UINT64_C(4))return 1;}{uint64_t value=seed;probe_l(&value,external_l);if(value!=seed+UINT64_C(8))return 1;}{uint64_t value=seed;probe_s(&value,external_s);if(value!=seed+UINT64_C(12))return 1;}{uint64_t value=seed;probe_d(&value,external_d);if(value!=seed+UINT64_C(16))return 1;}{uint64_t value=seed;probe_sb(&value,external_sb);if(value!=seed+UINT64_C(20))return 1;}{uint64_t value=seed;probe_ub(&value,external_ub);if(value!=seed+UINT64_C(24))return 1;}{uint64_t value=seed;probe_sh(&value,external_sh);if(value!=seed+UINT64_C(28))return 1;}{uint64_t value=seed;probe_uh(&value,external_uh);if(value!=seed+UINT64_C(32))return 1;}{uint64_t v=seed;dead_void(&v);if(v!=seed+9)return 2;discard_variadic(&v);if(v!=seed+19)return 3;}}return 0;}
