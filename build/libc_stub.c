/* Link-time stub only: it gives the linker the symbol names and the SONAME libc.so.3.
 * Nothing here ends up in the program: in the car the functions come from the head unit's real libc.so.3. */
void _init_libc(void){} void exit(int c){for(;;);} int printf(const char*f,...){return 0;}
int fflush(void*f){return 0;} void* dlopen(const char*p,int m){return 0;} void* dlsym(void*h,const char*s){return 0;}
char* dlerror(void){return 0;} int usleep(unsigned u){return 0;}
void* memset(void*d,int c,unsigned n){return d;} void* memcpy(void*d,const void*s,unsigned n){return d;}
unsigned strlen(const char*s){return 0;} int strcmp(const char*a,const char*b){return 0;}
int strncmp(const char*a,const char*b,unsigned n){return 0;}
void* calloc(unsigned a,unsigned b){return 0;} unsigned long strtoul(const char*s,char**e,int b){return 0;}
int open(const char*p,int f,...){return 0;} int read(int f,void*b,unsigned n){return 0;} int close(int f){return 0;}
void* signal(int s,void* h){return 0;} int pthread_create(void*a,const void*b,void*(*c)(void*),void*d){return 0;}
int write(int f,const void*b,unsigned n){return 0;} void _exit(int c){for(;;);}
