#include <stdio.h>
long c_target(signed char x) {return x;} extern long f(void); int main(void){long r=f();printf("%ld\n",r);return r!=-116;}
