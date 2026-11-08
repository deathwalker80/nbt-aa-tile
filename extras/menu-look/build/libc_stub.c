/* Link-time stub only: symbol names + SONAME libc.so.3. In the car the functions come from the head unit's libc. */
void _init_libc(void){} void exit(int c){for(;;);} int printf(const char*f,...){return 0;} int fflush(void*f){return 0;}
void* malloc(unsigned n){return 0;} void* realloc(void*p,unsigned n){return 0;} void free(void*p){}
void* memset(void*d,int c,unsigned n){return d;} void* memcpy(void*d,const void*s,unsigned n){return d;}
int memcmp(const void*a,const void*b,unsigned n){return 0;} unsigned strlen(const char*s){return 0;}
int strcmp(const char*a,const char*b){return 0;}
int open(const char*p,int f,...){return 0;} int read(int f,void*b,unsigned n){return 0;}
int write(int f,const void*b,unsigned n){return 0;} int close(int f){return 0;}
