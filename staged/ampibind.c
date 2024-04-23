// glue to the ampi sound driver
// implements OS functions declared in ampienv.h 

#include <ampienv.h>
#include "utils.h"
#include "debug.h"

// xzl: TODO fix ... to use kernel header. 
#define VA_START 			0xffff000000000000
#define PA2VA(x) ((void *)((unsigned long)x + VA_START))  // pa to kernel va
#define VA2PA(x) ((unsigned long)x - VA_START)          // kernel va to pa

void *ampi_malloc (size_t size) {
    return malloc((unsigned)size); 
}

void ampi_free (void *ptr) {
    free(ptr); 
}

void ampi_assertion_failed (const char *pExpr, const char *pFile, unsigned nLine) {
    assertion_failed (pExpr, pFile, nLine);
}

// called at 100Hz
static TPeriodicTimerHandler *periodic = 0; 
// only fire one time
static void onetime(TKernelTimerHandle hTimer, void *pParam, void *pContext) {
    if (periodic)
        (*periodic)(); 
    int t = ktimer_start(10 /*ms*/, onetime, 0, 0); BUG_ON(t < 0); //do it again
}

void RegisterPeriodicHandler (TPeriodicTimerHandler *pHandler) {
    periodic = pHandler; 
    // kickoff
    int t = ktimer_start(10 /*ms*/, onetime, 0, 0); BUG_ON(t < 0);
}

extern int enable_vchiq(unsigned buf /*arg*/, unsigned *resp); // mbox.c

uint32_t EnableVCHIQ (uint32_t p) {
    uint32_t resp = (uint32_t)-1; 

    if (enable_vchiq(p, &resp) != 0) {
        BUG(); 
    } 
    return resp; 
}    

// must be strongly ordered...
void *GetCoherentRegion512K () { 
    unsigned long pa = 0x20000000; // /*guess*
    if (reserve_phys_region(pa, 512 * 1024) == 0)
        return PA2VA(pa); 
    else 
        {BUG(); return 0;}
}
