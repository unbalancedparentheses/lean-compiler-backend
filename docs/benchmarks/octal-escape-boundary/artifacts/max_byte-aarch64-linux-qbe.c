extern unsigned char octets[];static const unsigned char expected[]={88,255,89};int main(void){for(unsigned i=0;i<sizeof expected;i++)if(octets[i]!=expected[i])return 1;return 0;}
