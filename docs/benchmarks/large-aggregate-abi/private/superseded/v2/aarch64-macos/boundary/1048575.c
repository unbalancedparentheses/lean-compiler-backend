#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
static unsigned char pattern(size_t i){return (unsigned char)((i*17+31)%251);}
static uint64_t bits(double d){uint64_t u;memcpy(&u,&d,8);return u;}
static double floating(uint64_t u){double d;memcpy(&d,&u,8);return d;}
static int guard_copy(size_t n,void (*into)(void*,void*),uint64_t (*out)(void*),uint64_t expected){
 size_t page=(size_t)sysconf(_SC_PAGESIZE),payload=(n+page-1)/page*page,total=payload+2*page;
 unsigned char *a=mmap(0,total,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0),*b=mmap(0,total,PROT_NONE,MAP_PRIVATE|MAP_ANON,-1,0);
 if(a==MAP_FAILED||b==MAP_FAILED)return 91;
 if(mprotect(a+page,payload,PROT_READ|PROT_WRITE)||mprotect(b+page,payload,PROT_READ|PROT_WRITE))return 92;
 for(unsigned side=0;side<2;side++){
  unsigned char *src=a+page+(side?0:payload-n),*dst=b+page+(side?0:payload-n);
  for(size_t i=0;i<n;i++){src[i]=pattern(i);dst[i]=0xcc;}
  into(dst,src);for(size_t i=0;i<n;i++)if(dst[i]!=pattern(i)||src[i]!=pattern(i))return 93;
  into(src,src);for(size_t i=0;i<n;i++)if(src[i]!=pattern(i))return 94;
  if(out&&out(src)!=expected)return 95;
  for(size_t i=0;i<n;i++)if(src[i]!=pattern(i))return 96;
 }
 munmap(a,total);munmap(b,total);return 0;
}

extern void into1048575(void*,void*);int main(void){return guard_copy(1048575,into1048575,0,0);}
