#ifndef	_UTILS_H
#define	_UTILS_H

// the kernel's HAL

#include "printf.h"

#ifdef PLAT_VIRT
#include "plat-virt.h"
#endif

extern void delay ( unsigned long);
extern void put32 ( unsigned long, unsigned int );
extern unsigned int get32 ( unsigned long );
extern int get_el ( void );

#define __REG32(x)      (*((volatile uint32_t *)(x)))

// ------------------- uart ----------------------------- //
void uart_init (unsigned long base);
char uart_recv ( void );
void uart_send ( char c );
void putc ( void* p, char c );

// ------------------- timer ----------------------------- //
// TODO: clean up
/* These are for "System Timer". See timer.c for details */
void timer_init ( void );
void handle_timer_irq ( void );

/* below are for Arm generic timers */
void generic_timer_init ( void );
void handle_generic_timer_irq ( void );

extern void gen_timer_init();
/* set timer to be fired after @interval System ticks */
extern void gen_timer_reset(int interval); 

// ------------------- irq ---------------------------- //
void enable_interrupt_controller( void ); // irq.c 

/* functions below defined in irq.S */
void irq_vector_init( void );    
void enable_irq( void );         
void disable_irq( void );

// ---------------- kernel mm ---------------------- //
unsigned long get_free_page();
void free_page(unsigned long p);
void memzero(unsigned long src, unsigned long n);   // boot.S
void memcpy(unsigned long src, unsigned long dst, unsigned long n); /*NB: arg1-src; arg2-dest; XXX swap*/

#include "sched.h"
void map_page(struct task_struct *task, unsigned long va, unsigned long page);
int copy_virt_memory(struct task_struct *dst); 
unsigned long allocate_kernel_page(); 
unsigned long allocate_user_page(struct task_struct *task, unsigned long va); 

// the virtual base address of the pgtables. Its actual value is set by the linker. 
//  cf the linker script (e.g. linker-qemu.ld)
extern unsigned long pg_dir;  

extern void set_pgd(unsigned long pgd);
extern unsigned long get_pgd();

#endif  /*_UTILS_H */
