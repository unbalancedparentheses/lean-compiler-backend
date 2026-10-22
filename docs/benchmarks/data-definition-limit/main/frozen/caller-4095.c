#include <stdio.h>
#include <string.h>
extern const char*lookup(unsigned long);int main(void){char want[32];for(unsigned i=0;i<4095;i++){snprintf(want,sizeof want,"message-%04u",i);if(strcmp(lookup(i),want))return 1;}return 0;}
