#include <stdint.h>
uint32_t external_w(uint64_t *p){*p+=1;return (uint32_t)-1;}
extern void probe_w(uint64_t*,uint32_t(*)(uint64_t*));
extern uint32_t used_w(uint64_t*);
uint64_t external_l(uint64_t *p){*p+=2;return (uint64_t)-1;}
extern void probe_l(uint64_t*,uint64_t(*)(uint64_t*));
extern uint64_t used_l(uint64_t*);
float external_s(uint64_t *p){*p+=3;return (float)-1;}
extern void probe_s(uint64_t*,float(*)(uint64_t*));
extern float used_s(uint64_t*);
double external_d(uint64_t *p){*p+=4;return (double)-1;}
extern void probe_d(uint64_t*,double(*)(uint64_t*));
extern double used_d(uint64_t*);
int8_t external_sb(uint64_t *p){*p+=5;return (int8_t)-1;}
extern void probe_sb(uint64_t*,int8_t(*)(uint64_t*));
extern int8_t used_sb(uint64_t*);
uint8_t external_ub(uint64_t *p){*p+=6;return (uint8_t)-1;}
extern void probe_ub(uint64_t*,uint8_t(*)(uint64_t*));
extern uint8_t used_ub(uint64_t*);
int16_t external_sh(uint64_t *p){*p+=7;return (int16_t)-1;}
extern void probe_sh(uint64_t*,int16_t(*)(uint64_t*));
extern int16_t used_sh(uint64_t*);
uint16_t external_uh(uint64_t *p){*p+=8;return (uint16_t)-1;}
extern void probe_uh(uint64_t*,uint16_t(*)(uint64_t*));
extern uint16_t used_uh(uint64_t*);
typedef struct {uint64_t a,b,c,d;} Big;
Big external_aggregate(uint64_t*p){*p+=17;Big b={11,22,33,44};return b;}
extern void env_probe(uint64_t*,uint64_t*),computed_probe(uint64_t*,uint64_t(**)(uint64_t*),uint64_t),aggregate_probe(uint64_t*),dead_void(uint64_t*),discard_variadic(uint64_t*);
int main(void){uint64_t seed=UINT64_C(0xfedcba9876543210);for(unsigned t=0;t<32;t++){seed^=seed<<13;seed^=seed>>7;seed^=seed<<17;{uint64_t value=seed;probe_w(&value,external_w);if(value!=seed+UINT64_C(4))return 1;}{uint64_t value=seed;if(used_w(&value)!=(uint32_t)(UINT32_MAX)||value!=seed+1)return 4;}{uint64_t value=seed;probe_l(&value,external_l);if(value!=seed+UINT64_C(8))return 1;}{uint64_t value=seed;if(used_l(&value)!=(uint64_t)(UINT64_MAX)||value!=seed+2)return 4;}{uint64_t value=seed;probe_s(&value,external_s);if(value!=seed+UINT64_C(12))return 1;}{uint64_t value=seed;if(used_s(&value)!=(float)(1.5f)||value!=seed+3)return 4;}{uint64_t value=seed;probe_d(&value,external_d);if(value!=seed+UINT64_C(16))return 1;}{uint64_t value=seed;if(used_d(&value)!=(double)(-2.5)||value!=seed+4)return 4;}{uint64_t value=seed;probe_sb(&value,external_sb);if(value!=seed+UINT64_C(20))return 1;}{uint64_t value=seed;if(used_sb(&value)!=(int8_t)(-1)||value!=seed+5)return 4;}{uint64_t value=seed;probe_ub(&value,external_ub);if(value!=seed+UINT64_C(24))return 1;}{uint64_t value=seed;if(used_ub(&value)!=(uint8_t)(255)||value!=seed+6)return 4;}{uint64_t value=seed;probe_sh(&value,external_sh);if(value!=seed+UINT64_C(28))return 1;}{uint64_t value=seed;if(used_sh(&value)!=(int16_t)(-1)||value!=seed+7)return 4;}{uint64_t value=seed;probe_uh(&value,external_uh);if(value!=seed+UINT64_C(32))return 1;}{uint64_t value=seed;if(used_uh(&value)!=(uint16_t)(65535)||value!=seed+8)return 4;}{uint64_t v=seed;dead_void(&v);if(v!=seed+9)return 2;}{uint64_t v=seed;discard_variadic(&v);if(v!=seed+10)return 3;}{uint64_t v=seed,e=seed^UINT64_C(0xaabbccddffee9988);env_probe(&v,&e);if(v!=seed+e+78)return 5;}{uint64_t v=seed;uint64_t(*table[])(uint64_t*)={external_l,external_l};computed_probe(&v,table,8);if(v!=seed+2)return 6;}{uint64_t v=seed;aggregate_probe(&v);if(v!=seed+17)return 7;}}return 0;}
