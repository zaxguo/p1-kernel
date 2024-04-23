// some comments below are xzl

#ifndef __coroutine_h
#define __coroutine_h

#ifdef __cplusplus
extern "C" {
#endif

// Implementation of a simple co-operative scheduler.

// ampi_co_next() may only be called on the main thread and
// executes a thread until it calls ampi_co_yield().

// ampi_co_callback() sets a callback called whenever a task
// switch happens, with the argument being the ID of the
// thread being switched to, or 0 if yielding from a thread.

// If yield() is called on the main thread, ampi_co_next()
// will be called for each active thread instead.

// xzl:what's main thread??
#include <stdint.h>

#define MAX_CO      8

// xzl: return 0 on success
int8_t ampi_co_create(void (*fn)(void *), void *arg);
void ampi_co_yield();       // xzl: switch to whatever thr?
void ampi_co_next(int8_t id);  // xzl: switch to a desiginated thr?
void ampi_co_callback(void (*cb)(int8_t)); // xzl: why callback useful

#ifdef __cplusplus
}
#endif

#endif
