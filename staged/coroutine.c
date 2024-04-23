#include "coroutine.h"
// #include <linux/printk.h>

// xzl: circle implements its "linux emu" layer using cpp (e.g. kthread, bh, etc). 
// so the ampi redo here w/ coroutine mech. intended to be a simple replacement
// 
// code is elegant. it's a good ex of user-level threading
// changes: 
//  although ampi claimed to support aarch64, the asm here is aarch32.
//  naked attribute never supported by gcc for aarch64? https://gcc.gnu.org/legacy-ml/gcc-bugs/2016-10/msg00510.html
//  some comments added (to myself
// Apr 2024

void (*callback)(int8_t) = 0;

#define MAX_STACK   65536

static uint32_t used = 0;       // a bitmap showing which coroutines are "in use"
static void (*fn_ptr[MAX_CO])(void *);
static void *args[MAX_CO];
static int8_t stack_space[MAX_CO][MAX_STACK];  // need force alignment??

// xzl: main thr 0, worker thr [1..MAX_CO] inclusive. 
static int8_t current = 0;      

// modeld after sched.h
// x0-x7 func call arguments; x9-x15 caller saved; x19-x29 callee saved
// d8-d15: 32bit FP/SIMD registers. callee saved. 
// "The AArch64 SIMD register size supports 32 floating-point/SIMD registers, 
// numbered from 0 to 31. Each register can be accessed as a full 128 bit 
// value, 64-bit value, 32-bit value, 16-bit value, or as an 8-bit value.
// cf: https://learn.microsoft.com/en-us/cpp/build/arm64-windows-abi-conventions?view=msvc-170
// ref: https://github.com/kurocha/coroutine-arm64/blob/master/source/Coroutine/Context.s
struct reg_set {	
    uint64_t d8;        // simd
    uint64_t d9; 
    uint64_t d10; 
    uint64_t d11; 
    uint64_t d12; 
    uint64_t d13; 
    uint64_t d14; 
    uint64_t d15;
	uint64_t x19;       // general purpose
	uint64_t x20;
	uint64_t x21;
	uint64_t x22;
	uint64_t x23;
	uint64_t x24;
	uint64_t x25;
	uint64_t x26;
	uint64_t x27;
	uint64_t x28;
	uint64_t x29;   // i.e. fp
	uint64_t sp;
	uint64_t pc;    // to save x30 (lr)
};

// xzl: why separate them?
static struct reg_set main_regs;    // thr 0
static struct reg_set regs[MAX_CO] = {{ 0 }};  // xzl: worker thr [1..MAXCO]

void ampi_co_jump(struct reg_set *restore_regs, struct reg_set *branch_regs);
void ampi_co_jump_arg(struct reg_set *restore_regs, struct reg_set *branch_regs, void *arg);

// Re: naked below: "the specified function does not need prologue/epilogue sequences"
// xzl: with arg, save arg (r2) as (r0) calling arg
// __attribute__ ((noinline, naked))
// void ampi_co_jump_arg(struct reg_set *restore_regs, struct reg_set *branch_regs, void *arg)
// {       
//     __asm__ __volatile__ (
//         "mov x9, sp \n"  // cannot ldr/str with sp. ok to use x9 (caller saved
//         "stp d8, d9, [x0, 0x00] \n"
//         "stp d10, d11, [x0, 0x10] \n"
//         "stp d12, d13, [x0, 0x20] \n"
//         "stp d14, d15, [x0, 0x30] \n"
//         "stp x19, x20, [x0, 0x40] \n"
//         "stp x21, x22, [x0, 0x50] \n"
//         "stp x23, x24, [x0, 0x60] \n"
//         "stp x25, x26, [x0, 0x70] \n"
//         "stp x27, x28, [x0, 0x80] \n"
//         "stp x29, x9,  [x0, 0x90] \n"       // x9==old sp
//         "str lr,       [x0, 0xa0] \n"
//         "mov x0, x2 \n"
//         "ldp d8, d9,   [x1, 0x00] \n"
//         "ldp d10, d11, [x1, 0x10] \n"
//         "ldp d12, d13, [x1, 0x20] \n"
//         "ldp d14, d15, [x1, 0x30] \n"
//         "ldp x19, x20, [x1, 0x40] \n"
//         "ldp x21, x22, [x1, 0x50] \n"
//         "ldp x23, x24, [x1, 0x60] \n"
//         "ldp x25, x26, [x1, 0x70] \n"
//         "ldp x27, x28, [x1, 0x80] \n"
//         "ldp x29, x9,  [x1, 0x90] \n"       //x9==new sp
//         "ldr lr,       [x1, 0xa0] \n"        // (aarch64 cannot ldr to pc)
//         "mov sp, x9"
//         "ret \n"        // jump to where lr points to 
//     ); 
// }

// __attribute__ ((noinline, naked))
// void ampi_co_jump(struct reg_set *restore_regs, struct reg_set *branch_regs)
// {
//     __asm__ __volatile__ (
//         "mov x9, sp \n"  // cannot ldr/str with sp. ok to use x9 (caller saved
//         "stp d8, d9, [x0, 0x00] \n"
//         "stp d10, d11, [x0, 0x10] \n"
//         "stp d12, d13, [x0, 0x20] \n"
//         "stp d14, d15, [x0, 0x30] \n"
//         "stp x19, x20, [x0, 0x40] \n"
//         "stp x21, x22, [x0, 0x50] \n"
//         "stp x23, x24, [x0, 0x60] \n"
//         "stp x25, x26, [x0, 0x70] \n"
//         "stp x27, x28, [x0, 0x80] \n"
//         "stp x29, x9,  [x0, 0x90] \n" // x9==old sp
//         "str lr,       [x0, 0xa0] \n"

//         "ldp d8, d9,   [x1, 0x00] \n"
//         "ldp d10, d11, [x1, 0x10] \n"
//         "ldp d12, d13, [x1, 0x20] \n"
//         "ldp d14, d15, [x1, 0x30] \n"
//         "ldp x19, x20, [x1, 0x40] \n"
//         "ldp x21, x22, [x1, 0x50] \n"
//         "ldp x23, x24, [x1, 0x60] \n"
//         "ldp x25, x26, [x1, 0x70] \n"
//         "ldp x27, x28, [x1, 0x80] \n"
//         "ldp x29, x9,  [x1, 0x90] \n"   //x9==new sp
//         "ldr lr,       [x1, 0xa0] \n"        // (aarch64 cannot ldr to pc)
//         "mov sp, x9"
//         "ret \n"        // jump to where lr points to 
//     );    
// }

int8_t ampi_co_create(void (*fn)(void *), void *arg)
{
    // printk("Creating: %x %x", fn, arg);
    for (int i = 0; i < MAX_CO; i++)
        if (!(used & (1 << i))) {
            used |= (1 << i);
            fn_ptr[i] = fn;
            args[i] = arg;
            return i + 1;
        }
    return 0;
}

void ampi_co_yield()
{
    if (current > 0) {      // xzl: not main thr. switch back to main thr
        int8_t id = current - 1;
        current = 0;
        if (callback) callback(current);
        ampi_co_jump(&regs[id], &main_regs);
    } else {        // main thr, switch to each worker thr
        for (int i = 1; i <= MAX_CO; i++) ampi_co_next(i);
    }
}

// only called on main thr. switch to worker thr
void ampi_co_next(int8_t id)
{
    id--;
    if (!(used & (1 << id))) return;
    current = id + 1;
    if (callback) callback(current);
    if (regs[id].pc == 0) {
        // Initialization
        regs[id].pc = (uint64_t)fn_ptr[id];
        regs[id].sp = (uint64_t)&stack_space[id + 1];
        ampi_co_jump_arg(&main_regs, &regs[id], args[id]);
    } else {
        ampi_co_jump(&main_regs, &regs[id]);
    }
}

void ampi_co_callback(void (*cb)(int8_t))
{
    callback = cb;
}
