#ifndef	_BOOT_H
#define	_BOOT_H

extern void delay ( unsigned long);
extern void put32 ( unsigned long, unsigned int );
extern unsigned int get32 ( unsigned long );

#define __REG32(x)      (*((volatile uint32_t *)(x)))

#endif  /*_BOOT_H */
