#include "plat.h"
#include "utils.h"
#include "debug.h"

static void handler(TKernelTimerHandle hTimer, void *param, void *context) {
	unsigned sec, msec; 
	current_time(&sec, &msec);
	I("%u.%03u: fired. htimer %d, param %lx, contex %lx", sec, msec,
		hTimer, (unsigned long)param, (unsigned long)context); 
}

// to be called in a kernel process
void test_ktimer() {
	unsigned sec, msec; 

	current_time(&sec, &msec); 
	I("%u.%03u start delaying 500ms...", sec, msec); 
	ms_delay(500); 
	current_time(&sec, &msec);
	I("%u.%03u ended delaying 500ms", sec, msec); 

	// start, fire 
	int t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t); 
	ms_delay(1000);
	I("timer %d should have fired", t); 

	// start two, fire
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t); 
	t = ktimer_start(1000, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t); 
	ms_delay(2000); 
	I("both timers should have fired", t); 

	// start, cancel 
	t = ktimer_start(500, handler, (void *)0xdeadbeef, (void*)0xdeaddeed);
	I("timer start. timer id %u", t);
	ms_delay(100); 
	int c = ktimer_cancel(t); 
	I("timer cancel return val = %d", c);
	BUG_ON(c < 0);

	I("there shouldn't be more callback"); 
}

void test_malloc() {
#define MIN_SIZE 32  
#define ALLOC_COUNT 4096 
    // try different sizes, small to large
    unsigned size, maxsize; 
    void *p; 
    int i; 

    // find a max allowable size
    for (size = MIN_SIZE; ; size *= 2) {
        p = malloc(size); 
        if (!p)
            break; 
        free(p); 
    }
    maxsize = size/2; 
    I("max alloc size %u", maxsize); 
    
    char ** allocs = malloc(ALLOC_COUNT * sizeof(char *));
    BUG_ON(!allocs); 

    I("BEFORE"); 
    dump_mem_info();    
    I("------------------------------");

    for (int k = 0; k < 2; k++) {
        I("---- pass %d ----- ", k); 
        for (size = MIN_SIZE; size < maxsize; size *= 2) {
            // for each size, keep allocating until fail
            for (i = 0; i < ALLOC_COUNT; i++) {
                allocs[i] = malloc(size); 
                if (!allocs[i])
                    break; 
            }
            I("size %u, count %d", size, i);
            i --; 
            // free all 
            for (; i>=0; i--) {
                free(allocs[i]); 
            }        
        }
    }
    I("should show the same as before"); 
    dump_mem_info();    
    I("------------------------------");

    // mix size alloc 
    for (int k = 0; k < 2; k++) {
        I("---- pass %d ----- ", k);     
        unsigned count = 0; 
        for (i = 0; i < ALLOC_COUNT; i++) {
            size = (i % (maxsize/2)); 
            allocs[i] = malloc(size); 
            if (!allocs[i])
                break; 
            count += size; 
        }
        I("total alloc %u bytes %d allocs", count, i); 
        i --; 
        // free all 
        for (; i>=0; i--) {
            free(allocs[i]); 
        }
    }
    I("should show the same as before"); 
    dump_mem_info();    
    I("------------------------------");

    free(allocs);
}

void test_mbox() {
    unsigned char buf[MAC_SIZE] = {0}; 
    int ret = get_mac_addr(buf);
    printf("return %d. mac is: ", ret);
    for (int i = 0; i < MAC_SIZE; i++)
        printf("%02x ", buf[i]);
    printf("\n"); 

    unsigned long s = 0; 
    get_board_serial(&s); 
    printf("serial 0x%lx\n", s); 
}
