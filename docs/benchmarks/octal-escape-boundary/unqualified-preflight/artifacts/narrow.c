#include <stdio.h>
extern unsigned char octets[];static const unsigned char expected[]={88,0,89,255,90,31,56,81,32,48,82};int main(void){int fail=0;for(unsigned i=0;i<sizeof expected;i++){printf("%02x",octets[i]);fail|=octets[i]!=expected[i];}puts("");return fail;}
