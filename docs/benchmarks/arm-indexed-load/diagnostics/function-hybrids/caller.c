#define _GNU_SOURCE
#include <zlib.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sched.h>
#include <errno.h>
static volatile unsigned long sink;
static void die(const char *s){perror(s);exit(2);}
static unsigned char *readfile(const char *p,size_t *n){FILE*f=fopen(p,"rb");if(!f)die("open");if(fseek(f,0,SEEK_END))die("seek");long z=ftell(f);if(z<0||z>16777216)die("size");*n=(size_t)z;rewind(f);unsigned char*b=malloc(*n+1);if(!b)die("malloc");if(fread(b,1,*n,f)!=*n)die("read");fclose(f);return b;}
static uint64_t now(void){struct timespec t;if(clock_gettime(CLOCK_MONOTONIC_RAW,&t))die("clock");return (uint64_t)t.tv_sec*1000000000+t.tv_nsec;}
static unsigned long number(const char*s){char*e;errno=0;unsigned long n=strtoul(s,&e,10);if(errno||*e)die("number");return n;}
int main(int argc,char**argv){
 if(argc<4)return 2;size_t n;unsigned char*input=readfile(argv[2],&n);int level=(int)number(argv[3]);
 uLongf capacity=compressBound(n),packedsize=capacity,outsize=n;unsigned char*packed=malloc(capacity),*out=malloc(n+1);if(!packed||!out)die("malloc");
 if(compress2(packed,&packedsize,input,n,level)!=Z_OK)return 3;
 if(!strcmp(argv[1],"check")){
  if(argc!=5)return 2;outsize=n;if(uncompress(out,&outsize,packed,packedsize)!=Z_OK||outsize!=n||memcmp(out,input,n))return 4;
  FILE*f=fopen(argv[4],"wb");if(!f)die("output");if(fwrite(packed,1,packedsize,f)!=packedsize||fclose(f))die("write");
  unsigned long crc=crc32(0,input,n);
#ifdef CORRUPT_CRC
  crc^=1;
#endif
  printf("{\"crc32\":%lu,\"input_bytes\":%zu,\"compressed_bytes\":%lu}\n",crc,n,(unsigned long)packedsize);return 0;
 }
 if(!strcmp(argv[1],"verify")){
  if(argc!=5)return 2;size_t pn;unsigned char*p=readfile(argv[4],&pn);outsize=n;if(uncompress(out,&outsize,p,pn)!=Z_OK||outsize!=n||memcmp(out,input,n))return 5;return 0;
 }
 if(strcmp(argv[1],"bench")||argc!=9)return 2;
 unsigned long loops[3]={number(argv[4]),number(argv[5]),number(argv[6])};int cpu=(int)number(argv[7]);unsigned long warm=number(argv[8]);
 if(cpu<0||cpu>=CPU_SETSIZE)return 6;cpu_set_t affinity;CPU_ZERO(&affinity);CPU_SET(cpu,&affinity);if(sched_setaffinity(0,sizeof affinity,&affinity))die("affinity");if(sched_getcpu()!=cpu)return 6;
 for(int k=0;k<3;k++)if(!loops[k]||loops[k]>100000000)return 2;
 for(unsigned long i=0;i<warm;i++){uLongf z=capacity,o=n;if(compress2(packed,&z,input,n,level)!=Z_OK||uncompress(out,&o,packed,z)!=Z_OK)return 7;sink^=crc32(0,input,n);}
 uint64_t start=now();for(unsigned long i=0;i<loops[0];i++){uLongf z=capacity;if(compress2(packed,&z,input,n,level)!=Z_OK)return 7;sink^=z;}uint64_t c=now()-start;
 start=now();for(unsigned long i=0;i<loops[1];i++){uLongf z=n;if(uncompress(out,&z,packed,packedsize)!=Z_OK)return 8;sink^=z;}uint64_t d=now()-start;
 start=now();for(unsigned long i=0;i<loops[2];i++){sink^=crc32(0,input,n);}uint64_t crc=now()-start;
 if(sched_getcpu()!=cpu||memcmp(out,input,n))return 9;
 printf("{\"compress_ns\":%llu,\"uncompress_ns\":%llu,\"crc32_ns\":%llu,\"loops\":[%lu,%lu,%lu],\"cpu\":%d,\"sink\":%lu}\n",(unsigned long long)c,(unsigned long long)d,(unsigned long long)crc,loops[0],loops[1],loops[2],cpu,sink);return 0;
}
