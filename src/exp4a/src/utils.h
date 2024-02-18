#ifndef	_UTILS_H
#define	_UTILS_H

#ifdef PLAT_VIRT
#include "plat-virt.h"
#endif

extern void delay ( unsigned long);
extern void put32 ( unsigned long, unsigned int );
extern unsigned int get32 ( unsigned long );
extern int get_el ( void );

#define __REG32(x)      (*((volatile uint32_t *)(x)))

#endif  /*_UTILS_H */
